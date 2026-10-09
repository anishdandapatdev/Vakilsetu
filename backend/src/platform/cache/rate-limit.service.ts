import { HttpException, HttpStatus, Injectable, OnModuleDestroy } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { createClient, RedisClientType } from 'redis';
import { loadEnvironment } from '../config/environment';

@Injectable()
export class RateLimitService implements OnModuleDestroy {
  private readonly client: RedisClientType;

  constructor() {
    this.client = createClient({ url: loadEnvironment(process.env).redisUrl });
  }

  async assertOtpRequestAllowed(phone: string, ip: string): Promise<void> {
    await this.ensureConnected();
    const phoneKey = createHash('sha256').update(phone).digest('hex');
    await Promise.all([
      this.increment(`otp:phone:${phoneKey}`, 5, 600),
      this.increment(`otp:ip:${ip}`, 20, 600),
    ]);
  }

  private async increment(key: string, limit: number, seconds: number): Promise<void> {
    const count = await this.client.incr(key);
    if (count === 1) await this.client.expire(key, seconds);
    if (count > limit) {
      throw new HttpException('otp_rate_limit_exceeded', HttpStatus.TOO_MANY_REQUESTS);
    }
  }

  private async ensureConnected(): Promise<void> {
    if (!this.client.isOpen) await this.client.connect();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.client.isOpen) await this.client.quit();
  }
}
