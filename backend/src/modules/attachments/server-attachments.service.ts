import { ForbiddenException, Inject, Injectable, Logger, NotFoundException, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { DatabaseService } from '../../platform/database/database.service';
import { ObjectStorage, OBJECT_STORAGE } from '../../platform/storage/object-storage';
import { RequestIdentity, SessionPolicy } from '../identity/session.policy';
import { ServerAttachmentDto } from './dto/server-attachment.dto';
import { MalwareScanner, MALWARE_SCANNER } from '../../platform/security/malware-scanner';

@Injectable()
export class ServerAttachmentsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ServerAttachmentsService.name);
  private cleanupTimer?: NodeJS.Timeout;
  constructor(private readonly database: DatabaseService, private readonly policy: SessionPolicy,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(MALWARE_SCANNER) private readonly scanner: MalwareScanner) {}

  onModuleInit(): void {
    this.cleanupTimer = setInterval(
      () => void this.cleanupAbandoned().catch(error =>
        this.logger.error('Attachment cleanup failed', error)),
      60 * 60 * 1000,
    );
    this.cleanupTimer.unref();
  }

  onModuleDestroy(): void {
    if (this.cleanupTimer) clearInterval(this.cleanupTimer);
  }

  async listShared(identity: RequestIdentity, before: string | undefined, limit: number,
    search = '', kind: 'all' | 'pdf' | 'images' = 'all') {
    this.policy.assertPrivateMessagingAllowed(identity);
    const result = await this.database.query<{
      id: string; messageId: string; conversationId: string; conversationTitle: string;
      filename: string; contentType: string; byteSize: number; createdAt: Date;
    }>(
      `SELECT a.id, msg.id AS "messageId", msg.conversation_id AS "conversationId",
              COALESCE(c.title, (
                SELECT p.full_name FROM conversation_members peer
                JOIN advocate_profiles p ON p.account_id=peer.account_id
                WHERE peer.conversation_id=c.id AND peer.account_id <> $1
                  AND peer.status='active' LIMIT 1
              ), 'Private conversation') AS "conversationTitle",
              a.filename, a.content_type AS "contentType",
              a.byte_size::int AS "byteSize", msg.created_at AS "createdAt"
       FROM server_messages msg
       JOIN server_attachments a ON a.id=msg.attachment_id
       JOIN conversations c ON c.id=msg.conversation_id
       JOIN conversation_members self ON self.conversation_id=msg.conversation_id
       WHERE self.account_id=$1 AND self.status='active'
         AND msg.deleted_at IS NULL AND a.status='available' AND a.scan_status='clean'
         AND ($4::text='' OR strpos(lower(a.filename), lower($4::text)) > 0)
         AND ($5::text='all' OR ($5::text='pdf' AND a.content_type='application/pdf')
              OR ($5::text='images' AND a.content_type IN ('image/jpeg','image/png')))
         AND ($2::uuid IS NULL OR (msg.created_at,msg.id) < (
           SELECT cursor.created_at,cursor.id FROM server_messages cursor
           JOIN conversation_members cursor_member
             ON cursor_member.conversation_id=cursor.conversation_id
           WHERE cursor.id=$2 AND cursor_member.account_id=$1
             AND cursor_member.status='active' AND cursor.attachment_id IS NOT NULL
         ))
       ORDER BY msg.created_at DESC,msg.id DESC LIMIT $3`,
      [identity.accountId, before ?? null, limit, search.trim(), kind],
    );
    return {
      items: result.rows,
      nextCursor: result.rows.length === limit ? result.rows[result.rows.length - 1].messageId : null,
    };
  }

  async cleanupAbandoned(): Promise<number> {
    const claimed = await this.database.transaction(async client => {
      const result = await client.query<{ id: string; objectKey: string; previousStatus: 'pending' | 'available' | 'deleted' }>(
        `WITH candidates AS (
           SELECT a.id,a.status FROM server_attachments a
           WHERE a.created_at < now() - interval '24 hours'
             AND (a.status IN ('pending','available') OR
                  (a.status='deleted' AND a.cleanup_error IS NOT NULL))
             AND NOT EXISTS (SELECT 1 FROM server_messages m WHERE m.attachment_id=a.id)
           ORDER BY a.created_at LIMIT 100 FOR UPDATE OF a SKIP LOCKED
         )
         UPDATE server_attachments a SET status='deleted',cleanup_attempted_at=now(),cleanup_error=NULL
         FROM candidates c WHERE a.id=c.id
         RETURNING a.id,a.object_key AS "objectKey",c.status AS "previousStatus"`,
      );
      return result.rows;
    });
    let removed = 0;
    for (const item of claimed) {
      try {
        await this.storage.deleteObject(item.objectKey);
        await this.database.query(
          `UPDATE server_attachments SET cleanup_error=NULL
           WHERE id=$1 AND status='deleted'`, [item.id]);
        removed += 1;
      } catch (error) {
        await this.database.query(
          `UPDATE server_attachments SET status=$2::attachment_status,
             cleanup_error=$3 WHERE id=$1 AND status='deleted'`,
          [item.id, item.previousStatus, String(error).slice(0, 500)],
        );
      }
    }
    return removed;
  }

  async initiate(identity: RequestIdentity, conversationId: string, input: ServerAttachmentDto) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const id = randomUUID();
    const key = `server-readable/${conversationId}/${id}`;
    await this.database.transaction(async client => {
      const access = await client.query(
        `SELECT 1 FROM conversation_members WHERE conversation_id=$1 AND account_id=$2 AND status='active'`,
        [conversationId, identity.accountId]);
      if (!access.rowCount) throw new ForbiddenException('conversation_access_denied');
      await client.query(
        `INSERT INTO server_attachments(id,conversation_id,uploader_account_id,object_key,filename,content_type,byte_size,sha256)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8)`,
        [id, conversationId, identity.accountId, key, input.filename, input.contentType,
         input.byteSize, Buffer.from(input.sha256, 'hex')]);
    });
    return { attachmentId: id, upload: await this.storage.createUpload(
      key, input.byteSize, input.sha256.toLowerCase(), input.contentType) };
  }

  async complete(identity: RequestIdentity, id: string) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const result = await this.database.query<{ object_key: string; byte_size: string; sha256: Buffer }>(
      `SELECT object_key,byte_size,sha256 FROM server_attachments
       WHERE id=$1 AND uploader_account_id=$2 AND status='pending'`, [id, identity.accountId]);
    const item = result.rows[0];
    if (!item) throw new NotFoundException('pending_attachment_not_found');
    if (!await this.storage.verifyObject(item.object_key, Number(item.byte_size), item.sha256.toString('hex'))) {
      throw new ForbiddenException('uploaded_attachment_does_not_match');
    }
    try {
      const bytes = await this.storage.readObject(item.object_key);
      if (bytes.length !== Number(item.byte_size)) throw new Error('malware_scan_size_mismatch');
      const result = await this.scanner.scan(bytes);
      if (result === 'infected') {
        await this.database.query(
          `UPDATE server_attachments SET status='deleted',scan_status='infected',
             scan_completed_at=now(),scan_error=NULL WHERE id=$1`, [id]);
        try {
          await this.storage.deleteObject(item.object_key);
        } catch (deleteError) {
          await this.database.query(
            `UPDATE server_attachments SET cleanup_error=$2,
               cleanup_attempted_at=now() WHERE id=$1`,
            [id, String(deleteError).slice(0, 500)],
          );
        }
        throw new ForbiddenException('attachment_malware_detected');
      }
      await this.database.query(
        `UPDATE server_attachments SET status='available',available_at=now(),
           scan_status='clean',scan_completed_at=now(),scan_error=NULL WHERE id=$1`, [id]);
    } catch (error) {
      if (error instanceof ForbiddenException) throw error;
      await this.database.query(
        `UPDATE server_attachments SET scan_status='error',scan_error=$2
         WHERE id=$1 AND status='pending'`, [id, String(error).slice(0, 500)]);
      throw error;
    }
    return { attachmentId: id, status: 'available' };
  }

  async download(identity: RequestIdentity, id: string) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const result = await this.database.query<{ object_key: string; filename: string; content_type: string }>(
      `SELECT a.object_key,a.filename,a.content_type FROM server_attachments a
       JOIN conversation_members m ON m.conversation_id=a.conversation_id
       WHERE a.id=$1 AND a.status='available' AND a.scan_status='clean'
         AND m.account_id=$2 AND m.status='active'
         AND EXISTS (
           SELECT 1 FROM server_messages msg
           WHERE msg.attachment_id=a.id AND msg.deleted_at IS NULL
         )`,
      [id, identity.accountId]);
    const item = result.rows[0];
    if (!item) throw new NotFoundException('attachment_not_found');
    return this.storage.createDownload(item.object_key, item.filename, item.content_type);
  }
}
