import { BadRequestException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';
import { RequestIdentity } from '../identity/session.policy';
import { DirectoryQueryDto } from './dto/directory-query.dto';
import { UpsertProfileDto } from './dto/upsert-profile.dto';

@Injectable()
export class AdvocatesService {
  constructor(private readonly database: DatabaseService) {}

  async upsert(identity: RequestIdentity, input: UpsertProfileDto) {
    const court = await this.database.query('SELECT 1 FROM courts WHERE id = $1 AND active', [input.primaryCourtId]);
    if (!court.rowCount) throw new BadRequestException('invalid_primary_court');
    const result = await this.database.query(
      `INSERT INTO advocate_profiles(account_id, full_name, enrollment_number, primary_court_id)
       VALUES ($1, $2, upper($3), $4)
       ON CONFLICT (account_id) DO UPDATE SET full_name = EXCLUDED.full_name,
         enrollment_number = EXCLUDED.enrollment_number,
         primary_court_id = EXCLUDED.primary_court_id, updated_at = now()
       RETURNING account_id AS "accountId", full_name AS "fullName",
         enrollment_number AS "enrollmentNumber", primary_court_id AS "primaryCourtId"`,
      [identity.accountId, input.fullName.trim(), input.enrollmentNumber, input.primaryCourtId],
    );
    return { ...result.rows[0], verificationStatus: identity.advocateStatus };
  }

  async me(identity: RequestIdentity) {
    const result = await this.database.query(
      `SELECT p.account_id AS "accountId", p.full_name AS "fullName",
              p.enrollment_number AS "enrollmentNumber", p.primary_court_id AS "primaryCourtId",
              c.name AS "primaryCourt", a.status AS "verificationStatus", p.photo_object_key AS "photoKey"
       FROM advocate_profiles p JOIN accounts a ON a.id = p.account_id
       JOIN courts c ON c.id = p.primary_court_id WHERE p.account_id = $1`,
      [identity.accountId],
    );
    return result.rows[0] ?? null;
  }

  async directory(input: DirectoryQueryDto) {
    const query = input.query?.trim() || null;
    const result = await this.database.query(
      `SELECT p.account_id AS "accountId", p.full_name AS "fullName",
              p.enrollment_number AS "enrollmentNumber", c.id AS "courtId",
              c.name AS "primaryCourt", p.photo_object_key AS "photoKey", true AS verified
       FROM advocate_profiles p JOIN accounts a ON a.id = p.account_id
       JOIN courts c ON c.id = p.primary_court_id
       WHERE a.status = 'verified' AND ($1::uuid IS NULL OR c.id = $1)
         AND ($2::text IS NULL OR p.full_name ILIKE '%' || $2 || '%'
              OR p.enrollment_number ILIKE '%' || $2 || '%')
       ORDER BY p.full_name, p.account_id LIMIT $3 OFFSET $4`,
      [input.courtId ?? null, query, input.limit, input.offset],
    );
    return { items: result.rows, limit: input.limit, offset: input.offset };
  }
}
