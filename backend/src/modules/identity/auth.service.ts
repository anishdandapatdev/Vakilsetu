import { BadRequestException, ForbiddenException, Inject, Injectable } from '@nestjs/common';
import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { DatabaseService } from '../../platform/database/database.service';
import { RateLimitService } from '../../platform/cache/rate-limit.service';
import { loadEnvironment } from '../../platform/config/environment';
import { OtpSender, OTP_SENDER } from './otp.sender';
import { VerifyOtpDto } from './dto/verify-otp.dto';

type ChallengeRow = {
  id: string;
  phone_e164: string;
  code_hash: Buffer;
  attempts: number;
  expires_at: Date;
  consumed_at: Date | null;
};

@Injectable()
export class AuthService {
  private readonly env = loadEnvironment(process.env);

  constructor(
    private readonly database: DatabaseService,
    private readonly limits: RateLimitService,
    @Inject(OTP_SENDER) private readonly sender: OtpSender,
  ) {}

  async requestOtp(phone: string, ip: string): Promise<{ challengeId: string; expiresInSeconds: number }> {
    await this.limits.assertOtpRequestAllowed(phone, ip);
    const code = this.env.otpProvider === 'development'
      ? this.env.developmentOtpCode!
      : randomInt(0, 1_000_000).toString().padStart(6, '0');
    const hash = this.otpHash(phone, code);
    const result = await this.database.query<{ id: string }>(
      `INSERT INTO otp_challenges(phone_e164, code_hash, expires_at)
       VALUES ($1, $2, now() + interval '5 minutes') RETURNING id`,
      [phone, hash],
    );
    try {
      await this.sender.send(phone, code);
    } catch (error) {
      await this.database.query('DELETE FROM otp_challenges WHERE id = $1', [result.rows[0].id]);
      throw error;
    }
    return { challengeId: result.rows[0].id, expiresInSeconds: 300 };
  }

  async verifyOtp(input: VerifyOtpDto): Promise<{
    accountId: string;
    deviceId: string;
    accessToken: string;
    refreshToken: string;
    accessExpiresInSeconds: number;
    deviceStatus: 'pending' | 'trusted';
  }> {
    const session = await this.database.transaction(async (client) => {
      const found = await client.query<ChallengeRow>(
        'SELECT * FROM otp_challenges WHERE id = $1 FOR UPDATE',
        [input.challengeId],
      );
      const challenge = found.rows[0];
      if (!challenge || challenge.consumed_at || challenge.expires_at <= new Date() || challenge.attempts >= 5) {
        throw new BadRequestException('invalid_or_expired_otp');
      }

      const expected = challenge.code_hash;
      const supplied = this.otpHash(challenge.phone_e164, input.code);
      if (expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) {
        await client.query('UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = $1', [challenge.id]);
        // Return normally so the increment commits before rejecting the request.
        return null;
      }

      await client.query('UPDATE otp_challenges SET consumed_at = now() WHERE id = $1', [challenge.id]);
      const account = await client.query<{ id: string }>(
        `INSERT INTO accounts(phone_e164) VALUES ($1)
         ON CONFLICT (phone_e164) DO UPDATE SET updated_at = now() RETURNING id`,
        [challenge.phone_e164],
      );
      const publicKey = Buffer.from(input.publicIdentityKey, 'base64');
      const fingerprint = createHash('sha256').update(publicKey).digest('hex');
      const device = await client.query<{ id: string; status: 'pending' | 'trusted' | 'revoked' }>(
        `INSERT INTO devices(account_id, public_identity_key, key_fingerprint, platform)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (account_id, key_fingerprint) DO UPDATE SET last_seen_at = now()
         WHERE devices.status <> 'revoked'
         RETURNING id, status`,
        [account.rows[0].id, publicKey, fingerprint, input.platform],
      );
      if (!device.rows[0]) throw new ForbiddenException('device_revoked');
      const accessToken = randomBytes(32).toString('base64url');
      const refreshToken = randomBytes(48).toString('base64url');
      await client.query(
        `INSERT INTO auth_sessions(
           account_id, device_id, access_token_hash, refresh_token_hash,
           access_expires_at, refresh_expires_at
         ) VALUES ($1, $2, $3, $4, now() + interval '15 minutes', now() + interval '30 days')`,
        [account.rows[0].id, device.rows[0].id, this.tokenHash(accessToken), this.tokenHash(refreshToken)],
      );
      await client.query(
        `INSERT INTO audit_events(actor_account_id, action, target_type, target_id, metadata)
         VALUES ($1, 'session.created', 'device', $2,
                 jsonb_build_object('platform', $3::text, 'deviceStatus', $4::text))`,
        [account.rows[0].id, device.rows[0].id, input.platform, device.rows[0].status],
      );
      return {
        accountId: account.rows[0].id,
        deviceId: device.rows[0].id,
        accessToken,
        refreshToken,
        accessExpiresInSeconds: 900,
        deviceStatus: device.rows[0].status as 'pending' | 'trusted',
      };
    });
    if (session === null) throw new BadRequestException('invalid_or_expired_otp');
    return session;
  }

  async refresh(refreshToken: string): Promise<{
    accessToken: string;
    refreshToken: string;
    accessExpiresInSeconds: number;
  }> {
    const refreshHash = this.tokenHash(refreshToken);
    const rotated = await this.database.transaction(async (client) => {
      const found = await client.query<{
        id: string;
        account_id: string;
        device_id: string;
        revoked_at: Date | null;
        refresh_expires_at: Date;
        device_status: 'pending' | 'trusted' | 'revoked';
      }>(
        `SELECT s.id, s.account_id, s.device_id, s.revoked_at,
                s.refresh_expires_at, d.status AS device_status
         FROM auth_sessions s JOIN devices d ON d.id = s.device_id
         WHERE s.refresh_token_hash = $1 FOR UPDATE`,
        [refreshHash],
      );
      const current = found.rows[0];
      if (!current || current.refresh_expires_at <= new Date() || current.device_status === 'revoked') {
        throw new BadRequestException('invalid_refresh_session');
      }
      if (current.revoked_at) {
        await client.query(
          'UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, now()) WHERE device_id = $1',
          [current.device_id],
        );
        // Commit device-wide revocation before reporting a replayed token.
        return null;
      }

      const nextAccess = randomBytes(32).toString('base64url');
      const nextRefresh = randomBytes(48).toString('base64url');
      await client.query('UPDATE auth_sessions SET revoked_at = now() WHERE id = $1', [current.id]);
      await client.query(
        `INSERT INTO auth_sessions(
           account_id, device_id, access_token_hash, refresh_token_hash,
           access_expires_at, refresh_expires_at, rotated_from
         ) VALUES ($1, $2, $3, $4, now() + interval '15 minutes',
                   now() + interval '30 days', $5)`,
        [
          current.account_id,
          current.device_id,
          this.tokenHash(nextAccess),
          this.tokenHash(nextRefresh),
          current.id,
        ],
      );
      return { accessToken: nextAccess, refreshToken: nextRefresh, accessExpiresInSeconds: 900 };
    });
    if (rotated === null) throw new ForbiddenException('refresh_token_reuse_detected');
    return rotated;
  }

  async logout(accessToken: string): Promise<void> {
    await this.database.query(
      'UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, now()) WHERE access_token_hash = $1',
      [this.tokenHash(accessToken)],
    );
  }

  private otpHash(phone: string, code: string): Buffer {
    return createHmac('sha256', this.env.otpHashPepper).update(`${phone}:${code}`).digest();
  }

  private tokenHash(token: string): Buffer {
    return createHmac('sha256', this.env.sessionSigningKey).update(token).digest();
  }
}
