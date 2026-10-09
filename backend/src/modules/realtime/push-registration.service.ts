import { Injectable } from '@nestjs/common';
import { createCipheriv, createHmac, randomBytes } from 'node:crypto';
import { DatabaseService } from '../../platform/database/database.service';
import { loadEnvironment } from '../../platform/config/environment';
import { RequestIdentity } from '../identity/session.policy';
import { RegisterPushDto } from './dto/register-push.dto';

@Injectable()
export class PushRegistrationService {
  private readonly key = Buffer.from(loadEnvironment(process.env).pushTokenEncryptionKey, 'base64');
  constructor(private readonly database: DatabaseService) {}

  async register(identity: RequestIdentity, input: RegisterPushDto) {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const ciphertext = Buffer.concat([cipher.update(input.token, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    const fingerprint = createHmac('sha256', this.key).update(input.token).digest();
    const result = await this.database.query<{ id: string }>(
      `INSERT INTO push_registrations(
         device_id, provider, token_ciphertext, token_iv, token_tag, token_fingerprint)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT (device_id, provider, token_fingerprint) DO UPDATE SET
         token_ciphertext = EXCLUDED.token_ciphertext, token_iv = EXCLUDED.token_iv,
         token_tag = EXCLUDED.token_tag, active = true, updated_at = now()
       RETURNING id`,
      [identity.deviceId, input.provider, ciphertext, iv, tag, fingerprint],
    );
    return { registrationId: result.rows[0].id };
  }

  async remove(identity: RequestIdentity, registrationId: string): Promise<void> {
    await this.database.query(
      'UPDATE push_registrations SET active = false, updated_at = now() WHERE id = $1 AND device_id = $2',
      [registrationId, identity.deviceId],
    );
  }
}
