import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Request } from 'express';
import { createHmac } from 'node:crypto';
import { DatabaseService } from '../../platform/database/database.service';
import { loadEnvironment } from '../../platform/config/environment';

export type AdminIdentity = { adminId: string; role: 'reviewer' | 'super_admin' };
export type AdminRequest = Request & { adminIdentity: AdminIdentity };

@Injectable()
export class AdminSessionGuard implements CanActivate {
  private readonly key = loadEnvironment(process.env).adminSessionSigningKey;
  constructor(private readonly database: DatabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AdminRequest>();
    const match = request.get('authorization')?.match(/^Bearer ([A-Za-z0-9_-]{40,})$/);
    if (!match) throw new UnauthorizedException('invalid_admin_session');
    const hash = createHmac('sha256', this.key).update(match[1]).digest();
    const result = await this.database.query<AdminIdentity>(
      `SELECT p.id AS "adminId", p.role FROM admin_sessions s
       JOIN admin_principals p ON p.id = s.admin_id
       WHERE s.token_hash = $1 AND s.revoked_at IS NULL AND s.expires_at > now()
         AND p.active AND s.mfa_verified_at > now() - interval '12 hours'`,
      [hash],
    );
    if (!result.rows[0]) throw new UnauthorizedException('invalid_admin_session');
    request.adminIdentity = result.rows[0];
    return true;
  }
}
