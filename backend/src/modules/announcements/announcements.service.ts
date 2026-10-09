import { Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';
import { AdminIdentity } from '../admin/admin-session.guard';
import { AnnouncementDto } from './dto/announcement.dto';

@Injectable()
export class AnnouncementsService {
  constructor(private readonly database: DatabaseService) {}

  async list(channelId: string, limit: number, offset: number) {
    const result = await this.database.query(
      `SELECT id, body, attachment_object_key AS "attachmentKey", revision,
              created_at AS "createdAt", updated_at AS "updatedAt"
       FROM public_announcements WHERE channel_id = $1 AND published AND deleted_at IS NULL
       ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
      [channelId, limit, offset],
    );
    return { items: result.rows, limit, offset };
  }

  async create(admin: AdminIdentity, channelId: string, input: AnnouncementDto) {
    return this.database.transaction(async (client) => {
      const channel = await client.query('SELECT 1 FROM public_channels WHERE id = $1 AND active', [channelId]);
      if (!channel.rowCount) throw new NotFoundException('channel_not_found');
      const result = await client.query<{ id: string }>(
        `INSERT INTO public_announcements(channel_id, author_admin_id, body, attachment_object_key)
         VALUES ($1,$2,$3,$4) RETURNING id`,
        [channelId, admin.adminId, input.body.trim(), input.attachmentObjectKey ?? null],
      );
      await client.query(
        `INSERT INTO public_announcement_revisions(
          announcement_id, revision, body, attachment_object_key, editor_admin_id)
         VALUES ($1,1,$2,$3,$4)`,
        [result.rows[0].id, input.body.trim(), input.attachmentObjectKey ?? null, admin.adminId],
      );
      return { announcementId: result.rows[0].id, revision: 1 };
    });
  }

  async update(admin: AdminIdentity, announcementId: string, input: AnnouncementDto) {
    return this.database.transaction(async (client) => {
      const updated = await client.query<{ revision: number }>(
        `UPDATE public_announcements SET body = $2, attachment_object_key = $3,
           revision = revision + 1, updated_at = now()
         WHERE id = $1 AND deleted_at IS NULL RETURNING revision`,
        [announcementId, input.body.trim(), input.attachmentObjectKey ?? null],
      );
      if (!updated.rows[0]) throw new NotFoundException('announcement_not_found');
      await client.query(
        `INSERT INTO public_announcement_revisions(
          announcement_id, revision, body, attachment_object_key, editor_admin_id)
         VALUES ($1,$2,$3,$4,$5)`,
        [announcementId, updated.rows[0].revision, input.body.trim(),
         input.attachmentObjectKey ?? null, admin.adminId],
      );
      return { announcementId, revision: updated.rows[0].revision };
    });
  }
}
