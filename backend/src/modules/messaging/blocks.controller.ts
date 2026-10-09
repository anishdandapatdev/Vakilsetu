import { Controller, Delete, HttpCode, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';

@Controller('blocks')
@UseGuards(AccessSessionGuard)
export class BlocksController {
  constructor(private readonly database: DatabaseService) {}

  @Post(':accountId')
  block(
    @CurrentIdentity() identity: RequestIdentity,
    @Param('accountId', new ParseUUIDPipe()) accountId: string,
  ) {
    if (accountId === identity.accountId) return { blocked: false };
    const pair = [identity.accountId, accountId].sort();
    return this.database.transaction(async client => {
      // Match direct-conversation creation's lock, then lock the conversation.
      // Message authorization locks the same conversation row, making block/send
      // ordering deterministic instead of relying on a timing-sensitive recheck.
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        [`${pair[0]}:${pair[1]}`],
      );
      await client.query(
        `SELECT c.id FROM direct_conversation_pairs p
         JOIN conversations c ON c.id=p.conversation_id
         WHERE p.lower_account_id=$1 AND p.upper_account_id=$2
         FOR UPDATE OF c`,
        pair,
      );
      const inserted = await client.query(
        `INSERT INTO blocked_accounts(blocker_account_id, blocked_account_id) VALUES ($1, $2)
         ON CONFLICT DO NOTHING RETURNING blocked_account_id`,
        [identity.accountId, accountId],
      );
      if (inserted.rowCount) {
        await client.query(
          `INSERT INTO audit_events(actor_account_id, action, target_type, target_id)
           VALUES ($1, 'account.blocked', 'account', $2)`,
          [identity.accountId, accountId],
        );
      }
      return { blocked: true };
    });
  }

  @Delete(':accountId')
  @HttpCode(204)
  async unblock(
    @CurrentIdentity() identity: RequestIdentity,
    @Param('accountId', new ParseUUIDPipe()) accountId: string,
  ): Promise<void> {
    const pair = [identity.accountId, accountId].sort();
    await this.database.transaction(async client => {
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        [`${pair[0]}:${pair[1]}`],
      );
      await client.query(
        `SELECT c.id FROM direct_conversation_pairs p
         JOIN conversations c ON c.id=p.conversation_id
         WHERE p.lower_account_id=$1 AND p.upper_account_id=$2
         FOR UPDATE OF c`,
        pair,
      );
      const deleted = await client.query(
        `DELETE FROM blocked_accounts
         WHERE blocker_account_id = $1 AND blocked_account_id = $2
         RETURNING blocked_account_id`,
        [identity.accountId, accountId],
      );
      if (deleted.rowCount) {
        await client.query(
          `INSERT INTO audit_events(actor_account_id, action, target_type, target_id)
           VALUES ($1, 'account.unblocked', 'account', $2)`,
          [identity.accountId, accountId],
        );
      }
    });
  }
}
