import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { loadEnvironment } from '../../platform/config/environment';
import { DatabaseService } from '../../platform/database/database.service';

@Injectable()
export class MessageRetentionService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MessageRetentionService.name);
  private readonly retentionDays = loadEnvironment(process.env).messageRetentionDays;
  private timer?: NodeJS.Timeout;

  constructor(private readonly database: DatabaseService) {}

  onModuleInit(): void {
    if (this.retentionDays === undefined) return;
    this.timer = setInterval(
      () => void this.deleteExpired().catch(error =>
        this.logger.error('Message retention cleanup failed', error)),
      60 * 60 * 1000,
    );
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async deleteExpired(): Promise<number> {
    if (this.retentionDays === undefined) return 0;
    let total = 0;
    for (let batch = 0; batch < 20; batch += 1) {
      const result = await this.database.query<{ id: string }>(
        `WITH candidates AS (
           SELECT id FROM server_messages
           WHERE created_at < now() - ($1::int * interval '1 day')
           ORDER BY created_at, id LIMIT 500 FOR UPDATE SKIP LOCKED
         )
         DELETE FROM server_messages m USING candidates c
         WHERE m.id=c.id RETURNING m.id`,
        [this.retentionDays],
      );
      const deleted = result.rowCount ?? result.rows.length;
      total += deleted;
      if (deleted < 500) break;
    }
    return total;
  }
}
