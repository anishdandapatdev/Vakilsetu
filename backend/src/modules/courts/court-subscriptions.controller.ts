import { Controller, Delete, Get, NotFoundException, Param, ParseUUIDPipe, Put, UseGuards } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';

@Controller('court-subscriptions')
@UseGuards(AccessSessionGuard)
export class CourtSubscriptionsController {
  constructor(private readonly database: DatabaseService) {}

  @Get()
  async list(@CurrentIdentity() identity: RequestIdentity) {
    const result = await this.database.query<{ courtId: string }>(
      `SELECT court_id AS "courtId" FROM court_subscriptions
       WHERE account_id = $1 ORDER BY created_at`,
      [identity.accountId],
    );
    return { courtIds: result.rows.map((row) => row.courtId) };
  }

  @Put(':courtId')
  async join(
    @CurrentIdentity() identity: RequestIdentity,
    @Param('courtId', new ParseUUIDPipe()) courtId: string,
  ) {
    const court = await this.database.query('SELECT 1 FROM courts WHERE id = $1 AND active', [courtId]);
    if (!court.rowCount) throw new NotFoundException('court_not_found');
    const result = await this.database.query(
      `INSERT INTO court_subscriptions(account_id, court_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [identity.accountId, courtId],
    );
    return { joined: true, changed: (result.rowCount ?? 0) > 0 };
  }

  @Delete(':courtId')
  async leave(
    @CurrentIdentity() identity: RequestIdentity,
    @Param('courtId', new ParseUUIDPipe()) courtId: string,
  ) {
    const result = await this.database.query(
      'DELETE FROM court_subscriptions WHERE account_id = $1 AND court_id = $2',
      [identity.accountId, courtId],
    );
    return { joined: false, changed: (result.rowCount ?? 0) > 0 };
  }
}
