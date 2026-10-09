import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';
import { RequestIdentity, SessionPolicy } from '../identity/session.policy';
import { CreateGroupDto } from './dto/create-group.dto';

@Injectable()
export class ConversationsService {
  constructor(private readonly database: DatabaseService, private readonly policy: SessionPolicy) {}

  async list(identity: RequestIdentity) {
    const result = await this.database.query(
      `SELECT c.id, c.kind,
              COALESCE(c.title, (
                SELECT p.full_name FROM conversation_members peer
                JOIN advocate_profiles p ON p.account_id = peer.account_id
                WHERE peer.conversation_id = c.id AND peer.account_id <> $1
                  AND peer.status = 'active' LIMIT 1
              ), 'Private conversation') AS title,
              c.membership_epoch AS "membershipEpoch", c.created_at AS "createdAt",
              latest.created_at AS "lastMessageAt",
              CASE WHEN latest.deleted_at IS NOT NULL THEN 'This message was deleted'
                   WHEN NULLIF(latest.body, '') IS NOT NULL THEN latest.body
                   WHEN latest.attachment_id IS NOT NULL THEN 'Attachment'
                   ELSE NULL END AS "lastMessagePreview",
              (SELECT count(*)::int FROM server_message_receipts r
               JOIN server_messages unread ON unread.id = r.message_id
               WHERE unread.conversation_id = c.id AND r.account_id = $1
                 AND r.read_at IS NULL) AS "unreadCount"
       FROM conversations c JOIN conversation_members m ON m.conversation_id = c.id
       LEFT JOIN LATERAL (
         SELECT body, attachment_id, deleted_at, created_at
         FROM server_messages WHERE conversation_id = c.id
         ORDER BY created_at DESC, id DESC LIMIT 1
       ) latest ON true
       WHERE m.account_id = $1 AND m.status = 'active'
       ORDER BY COALESCE(latest.created_at, c.created_at) DESC, c.id DESC LIMIT 100`,
      [identity.accountId],
    );
    return { items: result.rows };
  }

  async detail(identity: RequestIdentity, conversationId: string) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const conversation = await this.database.query(
      `SELECT c.id, c.kind, c.title, c.membership_epoch AS "membershipEpoch"
       FROM conversations c JOIN conversation_members self ON self.conversation_id = c.id
       WHERE c.id = $1 AND self.account_id = $2 AND self.status = 'active'`,
      [conversationId, identity.accountId],
    );
    if (!conversation.rows[0]) throw new NotFoundException('conversation_not_found');
    const members = await this.database.query(
      `SELECT m.account_id AS "accountId", p.full_name AS "fullName", m.member_role AS role,
              COALESCE(json_agg(json_build_object(
                'deviceId', d.id,
                'publicIdentityKey', encode(d.public_identity_key, 'base64'),
                'keyFingerprint', d.key_fingerprint
              )) FILTER (WHERE d.id IS NOT NULL), '[]') AS devices
       FROM conversation_members m
       LEFT JOIN advocate_profiles p ON p.account_id = m.account_id
       LEFT JOIN devices d ON d.account_id = m.account_id AND d.status = 'trusted'
       WHERE m.conversation_id = $1 AND m.status = 'active'
       GROUP BY m.account_id, p.full_name, m.member_role ORDER BY p.full_name NULLS LAST`,
      [conversationId],
    );
    return { ...conversation.rows[0], members: members.rows };
  }

  async direct(identity: RequestIdentity, peerAccountId: string) {
    this.policy.assertPrivateMessagingAllowed(identity);
    if (peerAccountId === identity.accountId) throw new BadRequestException('self_conversation_not_allowed');
    const pair = [identity.accountId, peerAccountId].sort();
    return this.database.transaction(async (client) => {
      await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [`${pair[0]}:${pair[1]}`]);
      const peer = await client.query("SELECT 1 FROM accounts WHERE id = $1 AND status = 'verified'", [peerAccountId]);
      if (!peer.rowCount) throw new NotFoundException('verified_advocate_not_found');
      const blocked = await client.query(
        `SELECT 1 FROM blocked_accounts WHERE
         (blocker_account_id = $1 AND blocked_account_id = $2)
         OR (blocker_account_id = $2 AND blocked_account_id = $1)`,
        [identity.accountId, peerAccountId],
      );
      if (blocked.rowCount) throw new ForbiddenException('conversation_blocked');
      const existing = await client.query<{ conversation_id: string }>(
        'SELECT conversation_id FROM direct_conversation_pairs WHERE lower_account_id = $1 AND upper_account_id = $2',
        pair,
      );
      if (existing.rows[0]) return { conversationId: existing.rows[0].conversation_id, created: false };
      const conversation = await client.query<{ id: string }>(
        "INSERT INTO conversations(kind, created_by) VALUES ('direct', $1) RETURNING id",
        [identity.accountId],
      );
      const id = conversation.rows[0].id;
      await client.query(
        `INSERT INTO conversation_members(conversation_id, account_id, joined_epoch)
         VALUES ($1, $2, 1), ($1, $3, 1)`,
        [id, pair[0], pair[1]],
      );
      await client.query(
        'INSERT INTO direct_conversation_pairs(lower_account_id, upper_account_id, conversation_id) VALUES ($1, $2, $3)',
        [pair[0], pair[1], id],
      );
      return { conversationId: id, created: true };
    });
  }

  async createGroup(identity: RequestIdentity, input: CreateGroupDto) {
    this.policy.assertPrivateMessagingAllowed(identity);
    const members = [...new Set(input.memberAccountIds.filter((id) => id !== identity.accountId))];
    return this.database.transaction(async (client) => {
      const valid = await client.query(
        "SELECT id FROM accounts WHERE id = ANY($1::uuid[]) AND status = 'verified'",
        [members],
      );
      if (valid.rowCount !== members.length) throw new BadRequestException('group_contains_unverified_member');
      const conversation = await client.query<{ id: string }>(
        "INSERT INTO conversations(kind, title, created_by) VALUES ('private_group', $1, $2) RETURNING id",
        [input.title.trim(), identity.accountId],
      );
      await client.query(
        `INSERT INTO conversation_members(conversation_id, account_id, joined_epoch, member_role)
         VALUES ($1, $2, 1, 'owner')`,
        [conversation.rows[0].id, identity.accountId],
      );
      for (const member of members) {
        await client.query(
          'INSERT INTO conversation_members(conversation_id, account_id, joined_epoch) VALUES ($1, $2, 1)',
          [conversation.rows[0].id, member],
        );
      }
      return { conversationId: conversation.rows[0].id, membershipEpoch: 1 };
    });
  }

  async changeMember(identity: RequestIdentity, conversationId: string, accountId: string, action: 'add' | 'remove') {
    this.policy.assertPrivateMessagingAllowed(identity);
    if (accountId === identity.accountId) throw new BadRequestException('owner_membership_cannot_change');
    return this.database.transaction(async (client) => {
      const group = await client.query<{ membership_epoch: number }>(
        `SELECT c.membership_epoch FROM conversations c JOIN conversation_members m ON m.conversation_id = c.id
         WHERE c.id = $1 AND c.kind = 'private_group' AND m.account_id = $2
           AND m.status = 'active' AND m.member_role = 'owner' FOR UPDATE OF c`,
        [conversationId, identity.accountId],
      );
      if (!group.rows[0]) throw new ForbiddenException('group_owner_required');
      const epoch = group.rows[0].membership_epoch + 1;
      if (action === 'add') {
        const valid = await client.query("SELECT 1 FROM accounts WHERE id = $1 AND status = 'verified'", [accountId]);
        if (!valid.rowCount) throw new BadRequestException('verified_advocate_required');
        await client.query(
          `INSERT INTO conversation_members(conversation_id, account_id, joined_epoch)
           VALUES ($1, $2, $3) ON CONFLICT (conversation_id, account_id) DO UPDATE
           SET status = 'active', joined_epoch = $3, removed_epoch = NULL, removed_at = NULL`,
          [conversationId, accountId, epoch],
        );
      } else {
        const removed = await client.query(
          `UPDATE conversation_members SET status = 'removed', removed_epoch = $3, removed_at = now()
           WHERE conversation_id = $1 AND account_id = $2 AND status = 'active'`,
          [conversationId, accountId, epoch],
        );
        if (!removed.rowCount) throw new NotFoundException('active_member_not_found');
      }
      await client.query('UPDATE conversations SET membership_epoch = $2 WHERE id = $1', [conversationId, epoch]);
      await client.query(
        `INSERT INTO audit_events(actor_account_id, action, target_type, target_id, metadata)
         VALUES ($1, 'group.membership_changed', 'account', $2,
                 jsonb_build_object('conversationId', $3::text, 'operation', $4::text, 'epoch', $5::int))`,
        [identity.accountId, accountId, conversationId, action, epoch],
      );
      return { conversationId, membershipEpoch: epoch };
    });
  }
}
