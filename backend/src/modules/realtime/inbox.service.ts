import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';
import { RequestIdentity, SessionPolicy } from '../identity/session.policy';

@Injectable()
export class InboxService {
  constructor(private readonly database: DatabaseService, private readonly policy: SessionPolicy) {}

  async page(identity: RequestIdentity, after: string | null, limit: number) {
    this.policy.assertPrivateMessagingAllowed(identity);
    return this.database.transaction(async (client) => {
      const result = await client.query(
        `SELECT id, conversation_id AS "conversationId", sender_device_id AS "senderDeviceId",
                membership_epoch AS "membershipEpoch", protocol,
                encode(ciphertext, 'base64') AS ciphertext, created_at AS "createdAt"
         FROM encrypted_envelopes e WHERE recipient_device_id = $1
           AND ($2::uuid IS NULL OR (e.created_at, e.id) >
             (SELECT x.created_at, x.id FROM encrypted_envelopes x
              WHERE x.id = $2 AND x.recipient_device_id = $1))
         ORDER BY e.created_at, e.id LIMIT $3 FOR UPDATE`,
        [identity.deviceId, after, limit],
      );
      if (result.rows.length) {
        await client.query(
          `UPDATE encrypted_envelopes SET received_at = COALESCE(received_at, now())
           WHERE recipient_device_id = $1 AND id = ANY($2::uuid[])`,
          [identity.deviceId, result.rows.map((row) => row.id)],
        );
      }
      return { items: result.rows, nextCursor: result.rows.at(-1)?.id ?? after };
    });
  }

  async acknowledge(identity: RequestIdentity, envelopeIds: string[]): Promise<{ acknowledged: number }> {
    this.policy.assertPrivateMessagingAllowed(identity);
    const result = await this.database.query(
      `UPDATE encrypted_envelopes SET acknowledged_at = COALESCE(acknowledged_at, now())
       WHERE recipient_device_id = $1 AND id = ANY($2::uuid[])`,
      [identity.deviceId, [...new Set(envelopeIds)]],
    );
    return { acknowledged: result.rowCount ?? 0 };
  }
}
