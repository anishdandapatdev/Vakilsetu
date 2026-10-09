import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { DatabaseService } from '../../platform/database/database.service';

@Controller('health')
export class HealthController {
  constructor(private readonly database: DatabaseService) {}

  @Get()
  health(): { status: 'ok'; service: string } {
    return { status: 'ok', service: 'vakilsetu-api' };
  }

  @Get('ready')
  async ready(): Promise<{ status: 'ready'; dependencies: { postgres: 'up' } }> {
    try {
      await this.database.ping();
      return { status: 'ready', dependencies: { postgres: 'up' } };
    } catch {
      throw new ServiceUnavailableException({
        status: 'not_ready',
        dependencies: { postgres: 'down' },
      });
    }
  }
}
