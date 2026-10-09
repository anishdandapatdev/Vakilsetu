import { ConflictException, ForbiddenException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { DatabaseService } from '../../platform/database/database.service';
import { RequestIdentity, SessionPolicy } from '../identity/session.policy';
import { DeliverEnvelopeDto } from './dto/deliver-envelope.dto';
import { loadEnvironment } from '../../platform/config/environment';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class DeliveryService {
  private readonly protocol = loadEnvironment(process.env).e2eeProtocol;
  constructor(
    private readonly database: DatabaseService,
    private readonly policy: SessionPolicy,
    private readonly realtime: RealtimeGateway,
  ) {}

  async deliver(identity: RequestIdentity, input: DeliverEnvelopeDto) {
    this.policy.assertPrivateMessagingAllowed(identity);
    if (this.protocol === 'disabled' || input.protocol !== this.protocol) {
      throw new ServiceUnavailableException('approved_e2ee_protocol_not_configured');
    }
    const ciphertext = Buffer.from(input.ciphertext, 'base64');
    if (!ciphertext.length || ciphertext.length > 512 * 1024) {
      throw new ConflictException('ciphertext_size_invalid');
    }
    const hash = createHash('sha256').update(ciphertext).digest();
    const delivered = await this.database.transaction(async (client) => {
      const access = await client.query<{ kind: 'direct' | 'private_group' }>(
        `SELECT c.kind FROM conversations c JOIN conversation_members sender ON sender.conversation_id = c.id
         JOIN devices recipient ON recipient.id = $4
         JOIN conversation_members receiver ON receiver.conversation_id = c.id AND receiver.account_id = recipient.account_id
         WHERE c.id = $1 AND c.membership_epoch = $2 AND sender.account_id = $3
           AND sender.status = 'active' AND receiver.status = 'active' AND recipient.status = 'trusted'`,
        [input.conversationId, input.membershipEpoch, identity.accountId, input.recipientDeviceId],
      );
      if (!access.rows[0]) throw new ForbiddenException('stale_epoch_or_recipient_not_allowed');
      if (access.rows[0].kind === 'direct') {
        const blocked = await client.query(
          `SELECT 1 FROM blocked_accounts b JOIN devices d ON d.id = $2
           WHERE (b.blocker_account_id = $1 AND b.blocked_account_id = d.account_id)
              OR (b.blocker_account_id = d.account_id AND b.blocked_account_id = $1)`,
          [identity.accountId, input.recipientDeviceId],
        );
        if (blocked.rowCount) throw new ForbiddenException('conversation_blocked');
      }
      const existing = await client.query<{ id: string; ciphertext_hash: Buffer; event_id: string }>(
        `SELECT e.id, e.ciphertext_hash, o.id AS event_id FROM encrypted_envelopes e
         JOIN opaque_delivery_events o ON o.envelope_id = e.id
         WHERE e.sender_device_id = $1 AND e.recipient_device_id = $2 AND e.client_message_id = $3`,
        [identity.deviceId, input.recipientDeviceId, input.clientMessageId],
      );
      if (existing.rows[0]) {
        if (!existing.rows[0].ciphertext_hash.equals(hash)) throw new ConflictException('idempotency_key_reused');
        return { envelopeId: existing.rows[0].id, eventId: existing.rows[0].event_id, duplicate: true };
      }
      const inserted = await client.query<{ id: string }>(
        `INSERT INTO encrypted_envelopes(
           conversation_id, sender_account_id, sender_device_id, recipient_device_id,
           client_message_id, membership_epoch, protocol, ciphertext, ciphertext_size, ciphertext_hash)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id`,
        [input.conversationId, identity.accountId, identity.deviceId, input.recipientDeviceId,
         input.clientMessageId, input.membershipEpoch, input.protocol, ciphertext, ciphertext.length, hash],
      );
      const event = await client.query<{ id: string }>(
        `INSERT INTO opaque_delivery_events(recipient_device_id, envelope_id)
         VALUES ($1, $2) RETURNING id`,
        [input.recipientDeviceId, inserted.rows[0].id],
      );
      return { envelopeId: inserted.rows[0].id, eventId: event.rows[0].id, duplicate: false };
    });
    await this.realtime.notifyDevice(input.recipientDeviceId, delivered.eventId);
    return { envelopeId: delivered.envelopeId, duplicate: delivered.duplicate };
  }
}
