import { Body, Controller, Param, ParseUUIDPipe, Patch, Req, UseGuards } from '@nestjs/common';
import { IsIn, IsOptional, IsString, Length } from 'class-validator';
import { DatabaseService } from '../../platform/database/database.service';
import { AdminRequest, AdminSessionGuard } from './admin-session.guard';

class VerificationDecisionDto {
  @IsIn(['verified', 'rejected', 'suspended'])
  decision!: 'verified' | 'rejected' | 'suspended';

  @IsOptional()
  @IsString()
  @Length(3, 500)
  reason?: string;
}

@Controller('admin/advocates')
@UseGuards(AdminSessionGuard)
export class VerificationController {
  constructor(private readonly database: DatabaseService) {}

  @Patch(':accountId/verification')
  async decide(
    @Param('accountId', new ParseUUIDPipe()) accountId: string,
    @Body() input: VerificationDecisionDto,
    @Req() request: AdminRequest,
  ) {
    return this.database.transaction(async (client) => {
      const profile = await client.query('SELECT 1 FROM advocate_profiles WHERE account_id = $1 FOR UPDATE', [accountId]);
      if (!profile.rowCount) return { updated: false };
      await client.query('UPDATE accounts SET status = $1, updated_at = now() WHERE id = $2', [input.decision, accountId]);
      if (input.decision === 'verified') {
        // Bootstrap only the first device during the reviewed advocate approval.
        // Further devices remain pending until a separate trust flow approves them.
        const trusted = await client.query(
          "SELECT 1 FROM devices WHERE account_id = $1 AND status = 'trusted' LIMIT 1",
          [accountId],
        );
        if (!trusted.rowCount) {
          const first = await client.query<{ id: string }>(
            "SELECT id FROM devices WHERE account_id = $1 AND status = 'pending' ORDER BY created_at, id LIMIT 1 FOR UPDATE",
            [accountId],
          );
          if (first.rows[0]) {
            await client.query("UPDATE devices SET status = 'trusted' WHERE id = $1", [first.rows[0].id]);
            await client.query(
              `INSERT INTO audit_events(actor_account_id, action, target_type, target_id, metadata)
               VALUES (NULL, 'device.trusted', 'device', $1,
                       jsonb_build_object('adminId', $2::text, 'reason', 'first_verified_device'))`,
              [first.rows[0].id, request.adminIdentity.adminId],
            );
          }
        }
      }
      await client.query(
        `INSERT INTO advocate_verification_reviews(account_id, reviewer_admin_id, decision, reason)
         VALUES ($1, $2, $3, $4)`,
        [accountId, request.adminIdentity.adminId, input.decision, input.reason ?? null],
      );
      await client.query(
        `INSERT INTO audit_events(actor_account_id, action, target_type, target_id, metadata)
         VALUES (NULL, 'advocate.verification_changed', 'account', $1,
                 jsonb_build_object('adminId', $2::text, 'decision', $3::text))`,
        [accountId, request.adminIdentity.adminId, input.decision],
      );
      return { updated: true, verificationStatus: input.decision };
    });
  }
}
