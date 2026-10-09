import { ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { DatabaseService } from '../../platform/database/database.service';
import { ObjectStorage, OBJECT_STORAGE } from '../../platform/storage/object-storage';
import { RequestIdentity, SessionPolicy } from '../identity/session.policy';
import { InitiateAttachmentDto } from './dto/initiate-attachment.dto';

@Injectable()
export class AttachmentsService {
  constructor(
    private readonly database: DatabaseService,
    private readonly policy: SessionPolicy,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  async initiate(identity: RequestIdentity, conversationId: string, input: InitiateAttachmentDto) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const attachmentId = randomUUID();
    const objectKey = `private/${conversationId}/${attachmentId}.bin`;
    await this.database.transaction(async (client) => {
      const allowed = await client.query(
        `SELECT 1 FROM conversations c JOIN conversation_members m ON m.conversation_id = c.id
         WHERE c.id = $1 AND c.membership_epoch = $2 AND m.account_id = $3 AND m.status = 'active' FOR UPDATE OF c`,
        [conversationId, input.membershipEpoch, identity.accountId],
      );
      if (!allowed.rowCount) throw new ForbiddenException('stale_epoch_or_membership_denied');
      await client.query(
        `INSERT INTO encrypted_attachments(
          id, conversation_id, uploader_account_id, uploader_device_id, membership_epoch,
          object_key, ciphertext_size, ciphertext_sha256)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [attachmentId, conversationId, identity.accountId, identity.deviceId,
         input.membershipEpoch, objectKey, input.ciphertextSize,
         Buffer.from(input.ciphertextSha256, 'hex')],
      );
    });
    const upload = await this.storage.createCiphertextUpload(
      objectKey,
      input.ciphertextSize,
      input.ciphertextSha256.toLowerCase(),
    );
    return { attachmentId, upload };
  }

  async download(identity: RequestIdentity, attachmentId: string) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const result = await this.database.query<{ object_key: string }>(
      `SELECT a.object_key FROM encrypted_attachments a
       JOIN conversation_members m ON m.conversation_id = a.conversation_id
       WHERE a.id = $1 AND a.status = 'available' AND m.account_id = $2
         AND m.status = 'active' AND m.joined_epoch <= a.membership_epoch`,
      [attachmentId, identity.accountId],
    );
    if (!result.rows[0]) throw new NotFoundException('attachment_not_found');
    return this.storage.createCiphertextDownload(result.rows[0].object_key);
  }

  async complete(identity: RequestIdentity, attachmentId: string) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const result = await this.database.query<{
      object_key: string;
      ciphertext_size: string;
      ciphertext_sha256: Buffer;
    }>(
      `SELECT object_key, ciphertext_size, ciphertext_sha256 FROM encrypted_attachments
       WHERE id = $1 AND uploader_account_id = $2 AND uploader_device_id = $3 AND status = 'pending'`,
      [attachmentId, identity.accountId, identity.deviceId],
    );
    const attachment = result.rows[0];
    if (!attachment) throw new NotFoundException('pending_attachment_not_found');
    const valid = await this.storage.verifyCiphertextObject(
      attachment.object_key,
      Number(attachment.ciphertext_size),
      attachment.ciphertext_sha256.toString('hex'),
    );
    if (!valid) throw new ForbiddenException('uploaded_ciphertext_does_not_match');
    await this.database.query(
      `UPDATE encrypted_attachments SET status = 'available', available_at = now()
       WHERE id = $1 AND status = 'pending'`,
      [attachmentId],
    );
    return { attachmentId, status: 'available' as const };
  }

  async remove(identity: RequestIdentity, attachmentId: string): Promise<void> {
    this.policy.assertPrivateMessagingAllowed(identity);
    const result = await this.database.query<{ object_key: string }>(
      `SELECT object_key FROM encrypted_attachments
       WHERE id = $1 AND uploader_account_id = $2 AND uploader_device_id = $3
         AND status <> 'deleted'`,
      [attachmentId, identity.accountId, identity.deviceId],
    );
    const attachment = result.rows[0];
    if (!attachment) throw new NotFoundException('attachment_not_found');
    await this.storage.deleteCiphertextObject(attachment.object_key);
    await this.database.query(
      `UPDATE encrypted_attachments SET status = 'deleted'
       WHERE id = $1 AND uploader_account_id = $2 AND uploader_device_id = $3`,
      [attachmentId, identity.accountId, identity.deviceId],
    );
  }
}
