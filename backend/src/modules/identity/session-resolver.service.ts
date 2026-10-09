import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac } from 'node:crypto';
import { DatabaseService } from '../../platform/database/database.service';
import { loadEnvironment } from '../../platform/config/environment';
import { RequestIdentity } from './session.policy';

@Injectable()
export class SessionResolver {
  private readonly key = loadEnvironment(process.env).sessionSigningKey;
  constructor(private readonly database: DatabaseService) {}

  async resolve(accessToken: string): Promise<RequestIdentity> {
    if (!/^[A-Za-z0-9_-]{40,}$/.test(accessToken)) {
      throw new UnauthorizedException('invalid_session');
    }
    const hash = createHmac('sha256', this.key).update(accessToken).digest();
    const result = await this.database.query<RequestIdentity>(
      `SELECT s.account_id AS "accountId", s.device_id AS "deviceId",
              a.status AS "advocateStatus", d.status AS "deviceStatus"
       FROM auth_sessions s JOIN accounts a ON a.id = s.account_id
       JOIN devices d ON d.id = s.device_id
       WHERE s.access_token_hash = $1 AND s.revoked_at IS NULL
         AND s.access_expires_at > now() AND d.status <> 'revoked'`,
      [hash],
    );
    if (!result.rows[0]) throw new UnauthorizedException('invalid_session');
    return result.rows[0];
  }
}
