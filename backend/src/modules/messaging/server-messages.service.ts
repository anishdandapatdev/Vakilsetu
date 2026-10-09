import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../platform/database/database.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { RequestIdentity, SessionPolicy } from '../identity/session.policy';
import { ServerMessageDto } from './dto/server-message.dto';

@Injectable()
export class ServerMessagesService {
  constructor(
    private readonly database: DatabaseService,
    private readonly policy: SessionPolicy,
    private readonly realtime: RealtimeGateway,
  ) {}

  private async authorize(client: PoolClient, identity: RequestIdentity, id: string) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const access = await client.query<{ kind: 'direct' | 'private_group' }>(
      `SELECT c.kind FROM conversations c JOIN conversation_members m ON m.conversation_id=c.id
       WHERE c.id=$1 AND m.account_id=$2 AND m.status='active' FOR UPDATE OF c`,
      [id, identity.accountId],
    );
    if (!access.rows[0]) throw new ForbiddenException('conversation_access_denied');
    if (access.rows[0].kind === 'direct') {
      const blocked = await client.query(
        `SELECT 1 FROM blocked_accounts b JOIN conversation_members peer ON peer.conversation_id=$1
         AND peer.account_id<>$2 AND peer.status='active'
         WHERE (b.blocker_account_id=$2 AND b.blocked_account_id=peer.account_id)
            OR (b.blocked_account_id=$2 AND b.blocker_account_id=peer.account_id)`,
        [id, identity.accountId],
      );
      if (blocked.rowCount) throw new ForbiddenException('conversation_blocked');
    }
  }

  history(identity: RequestIdentity, id: string, before: string | undefined, limit: number) {
    return this.database.transaction(async client => {
      await this.authorize(client, identity, id);
      const result = await client.query(
        `SELECT m.id, m.sender_account_id AS "senderAccountId",
                COALESCE(p.full_name, 'Advocate') AS "senderName", m.body,
                m.created_at AS "createdAt",
                (SELECT count(*)::int FROM server_message_receipts r WHERE r.message_id=m.id) AS "recipientCount",
                (SELECT count(*)::int FROM server_message_receipts r WHERE r.message_id=m.id AND r.delivered_at IS NOT NULL) AS "deliveredCount",
                (SELECT count(*)::int FROM server_message_receipts r WHERE r.message_id=m.id AND r.read_at IS NOT NULL) AS "readCount",
                a.id AS "attachmentId", a.filename AS "attachmentName",
                a.content_type AS "attachmentContentType", a.byte_size::int AS "attachmentBytes",
                m.reply_to_message_id AS "replyToMessageId",
                replied.body AS "replyBody", replied.deleted_at IS NOT NULL AS "replyDeleted",
                COALESCE(reply_profile.full_name, 'Advocate') AS "replySenderName",
                m.edited_at AS "editedAt", m.deleted_at AS "deletedAt"
         FROM server_messages m
         LEFT JOIN advocate_profiles p ON p.account_id=m.sender_account_id
         LEFT JOIN server_attachments a ON a.id=m.attachment_id
         LEFT JOIN server_messages replied ON replied.id=m.reply_to_message_id
         LEFT JOIN advocate_profiles reply_profile ON reply_profile.account_id=replied.sender_account_id
         WHERE m.conversation_id=$1 AND (
           $2::uuid IS NULL OR (m.created_at, m.id) < (
             SELECT created_at, id FROM server_messages WHERE id=$2 AND conversation_id=$1
           )
         ) ORDER BY m.created_at DESC, m.id DESC LIMIT $3`,
        [id, before ?? null, limit],
      );
      if (result.rows.length) {
        await client.query(
          `UPDATE server_message_receipts SET delivered_at=COALESCE(delivered_at, now())
           WHERE account_id=$1 AND message_id=ANY($2::uuid[])`,
          [identity.accountId, result.rows.map(row => row.id)],
        );
      }
      const nextCursor = result.rows.length === limit
        ? result.rows[result.rows.length - 1].id as string
        : null;
      return { items: result.rows.reverse(), nextCursor, securityMode: 'server-readable' };
    });
  }

  async send(identity: RequestIdentity, id: string, input: ServerMessageDto) {
    const delivered = await this.database.transaction(async client => {
      await this.authorize(client, identity, id);
      if (input.replyToMessageId) {
        const replied = await client.query(
          'SELECT 1 FROM server_messages WHERE id=$1 AND conversation_id=$2',
          [input.replyToMessageId, id],
        );
        if (!replied.rowCount) throw new NotFoundException('reply_message_not_found');
      }
      const result = await client.query(
        `WITH attachment AS (
           SELECT id FROM server_attachments WHERE id=$5::uuid AND conversation_id=$1
             AND uploader_account_id=$2 AND status='available' FOR KEY SHARE
         )
         INSERT INTO server_messages(conversation_id,sender_account_id,client_message_id,body,attachment_id,reply_to_message_id)
         SELECT $1,$2,$3,$4,a.id,$6 FROM (SELECT 1) seed
         LEFT JOIN attachment a ON true
         WHERE $5::uuid IS NULL OR a.id IS NOT NULL ON CONFLICT DO NOTHING
         RETURNING id, sender_account_id AS "senderAccountId", body, created_at AS "createdAt"`,
        [id, identity.accountId, input.clientMessageId, input.body?.trim() ?? '',
         input.attachmentId ?? null, input.replyToMessageId ?? null],
      );
      if (!result.rows[0] && input.attachmentId) {
        const exists = await client.query(`SELECT 1 FROM server_messages WHERE conversation_id=$1
          AND sender_account_id=$2 AND client_message_id=$3`, [id, identity.accountId, input.clientMessageId]);
        if (!exists.rowCount) throw new ForbiddenException('attachment_not_available');
      }
      let message = result.rows[0];
      if (!message) {
        const previous = await client.query(
          `SELECT id, sender_account_id AS "senderAccountId", body,
                  attachment_id AS "attachmentId", reply_to_message_id AS "replyToMessageId",
                  created_at AS "createdAt"
           FROM server_messages WHERE conversation_id=$1 AND sender_account_id=$2 AND client_message_id=$3`,
          [id, identity.accountId, input.clientMessageId],
        );
        message = previous.rows[0];
        if (message?.body !== (input.body?.trim() ?? '') ||
            (message?.attachmentId ?? null) !== (input.attachmentId ?? null) ||
            (message?.replyToMessageId ?? null) !== (input.replyToMessageId ?? null)) {
          throw new ConflictException('idempotency_key_reused');
        }
      }
      const recipients = await client.query<{ accountId: string }>(
        `SELECT account_id AS "accountId" FROM conversation_members
         WHERE conversation_id=$1 AND status='active' AND account_id<>$2`,
        [id, identity.accountId],
      );
      if (result.rows[0] && recipients.rows.length) {
        await client.query(
          `INSERT INTO server_message_receipts(message_id, account_id)
           SELECT $1, unnest($2::uuid[]) ON CONFLICT DO NOTHING`,
          [result.rows[0].id, recipients.rows.map(row => row.accountId)],
        );
      }
      return { message, recipients: recipients.rows.map(row => row.accountId) };
    });
    await Promise.all(
      delivered.recipients.map(accountId =>
        this.realtime.notifyAccount(accountId, delivered.message.id)),
    );
    return delivered.message;
  }

  async edit(identity: RequestIdentity, conversationId: string, messageId: string, body: string) {
    const recipients = await this.database.transaction(async client => {
      await this.authorize(client, identity, conversationId);
      const updated = await client.query(
        `UPDATE server_messages SET body=$4,edited_at=now()
         WHERE id=$1 AND conversation_id=$2 AND sender_account_id=$3
           AND deleted_at IS NULL AND created_at > now() - interval '15 minutes'
         RETURNING id,edited_at AS "editedAt"`,
        [messageId, conversationId, identity.accountId, body.trim()],
      );
      if (!updated.rowCount) throw new ForbiddenException('message_edit_not_allowed');
      await client.query(
        `INSERT INTO audit_events(actor_account_id,action,target_type,target_id)
         VALUES($1,'message.edited','message',$2)`,
        [identity.accountId, messageId],
      );
      const members = await client.query<{ accountId: string }>(
        `SELECT account_id AS "accountId" FROM conversation_members
         WHERE conversation_id=$1 AND status='active' AND account_id<>$2`,
        [conversationId, identity.accountId],
      );
      return { message: updated.rows[0], accountIds: members.rows.map(row => row.accountId) };
    });
    await Promise.all(recipients.accountIds.map(accountId =>
      this.realtime.notifyAccount(accountId, messageId)));
    return recipients.message;
  }

  async delete(identity: RequestIdentity, conversationId: string, messageId: string): Promise<void> {
    const accountIds = await this.database.transaction(async client => {
      await this.authorize(client, identity, conversationId);
      const updated = await client.query(
        `UPDATE server_messages SET body=NULL,attachment_id=NULL,deleted_at=now()
         WHERE id=$1 AND conversation_id=$2 AND sender_account_id=$3
           AND deleted_at IS NULL AND created_at > now() - interval '2 days'
         RETURNING id`,
        [messageId, conversationId, identity.accountId],
      );
      if (!updated.rowCount) throw new ForbiddenException('message_delete_not_allowed');
      await client.query(
        `INSERT INTO audit_events(actor_account_id,action,target_type,target_id)
         VALUES($1,'message.deleted','message',$2)`,
        [identity.accountId, messageId],
      );
      const members = await client.query<{ accountId: string }>(
        `SELECT account_id AS "accountId" FROM conversation_members
         WHERE conversation_id=$1 AND status='active' AND account_id<>$2`,
        [conversationId, identity.accountId],
      );
      return members.rows.map(row => row.accountId);
    });
    await Promise.all(accountIds.map(accountId => this.realtime.notifyAccount(accountId, messageId)));
  }

  async markRead(identity: RequestIdentity, id: string, throughMessageId: string) {
    const senders = await this.database.transaction(async client => {
      await this.authorize(client, identity, id);
      const boundary = await client.query<{ id: string }>(
        `SELECT id FROM server_messages
         WHERE id=$1 AND conversation_id=$2`, [throughMessageId, id]);
      if (!boundary.rows[0]) throw new ForbiddenException('read_boundary_not_found');
      const updated = await client.query<{ senderAccountId: string }>(
        `UPDATE server_message_receipts r SET
           delivered_at=COALESCE(r.delivered_at, now()), read_at=COALESCE(r.read_at, now())
         FROM server_messages m, server_messages boundary
         WHERE r.message_id=m.id AND r.account_id=$1
           AND m.conversation_id=$2 AND boundary.id=$3 AND boundary.conversation_id=$2
           AND (m.created_at, m.id)<=(boundary.created_at, boundary.id)
         RETURNING m.sender_account_id AS "senderAccountId"`,
        [identity.accountId, id, boundary.rows[0].id],
      );
      return [...new Set(updated.rows.map(row => row.senderAccountId))];
    });
    await Promise.all(senders.map(accountId => this.realtime.notifyAccount(accountId, throughMessageId)));
    return { read: true };
  }
}
