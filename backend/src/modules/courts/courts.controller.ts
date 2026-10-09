import { Controller, Get } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';

@Controller('courts')
export class CourtsController {
  constructor(private readonly database: DatabaseService) {}

  @Get()
  async list() {
    const result = await this.database.query(
      `SELECT c.id, c.slug, c.name, c.city, c.image_object_key AS "imageKey",
              pc.id AS "channelId"
       FROM courts c LEFT JOIN public_channels pc ON pc.court_id = c.id AND pc.active
       WHERE c.active ORDER BY c.name`,
    );
    return { items: result.rows };
  }
}
