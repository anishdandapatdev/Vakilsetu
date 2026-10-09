import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';
import { RequestIdentity } from './session.policy';

export type DeviceView = {
  id: string;
  platform: 'android' | 'ios' | 'web';
  status: 'pending' | 'trusted' | 'revoked';
  keyFingerprint: string;
  lastSeenAt: Date | null;
  createdAt: Date;
  current: boolean;
};

@Injectable()
export class DevicesService {
  constructor(private readonly database: DatabaseService) {}

  async list(identity: RequestIdentity): Promise<DeviceView[]> {
    const result = await this.database.query<Omit<DeviceView, 'current'>>(
      `SELECT id, platform, status, key_fingerprint AS "keyFingerprint",
              last_seen_at AS "lastSeenAt", created_at AS "createdAt"
       FROM devices WHERE account_id = $1 ORDER BY created_at DESC`,
      [identity.accountId],
    );
    return result.rows.map((device) => ({ ...device, current: device.id === identity.deviceId }));
  }

  async revoke(identity: RequestIdentity, deviceId: string): Promise<void> {
    if (identity.deviceStatus !== 'trusted') {
      throw new ForbiddenException('trusted_device_required');
    }
    const result = await this.database.transaction(async (client) => {
      const updated = await client.query(
        `UPDATE devices SET status = 'revoked', revoked_at = now()
         WHERE id = $1 AND account_id = $2 AND status <> 'revoked' RETURNING id`,
        [deviceId, identity.accountId],
      );
      if (!updated.rowCount) return false;
      await client.query(
        'UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, now()) WHERE device_id = $1',
        [deviceId],
      );
      await client.query(
        `INSERT INTO audit_events(actor_account_id, action, target_type, target_id)
         VALUES ($1, 'device.revoked', 'device', $2)`,
        [identity.accountId, deviceId],
      );
      return true;
    });
    if (!result) throw new NotFoundException('device_not_found');
  }
}
