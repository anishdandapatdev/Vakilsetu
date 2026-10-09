import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthModule } from './modules/health/health.module';
import { IdentityModule } from './modules/identity/identity.module';
import { MessagingModule } from './modules/messaging/messaging.module';
import { DatabaseModule } from './platform/database/database.module';
import { CacheModule } from './platform/cache/cache.module';
import { AdvocatesModule } from './modules/advocates/advocates.module';
import { CourtsModule } from './modules/courts/courts.module';
import { AdminModule } from './modules/admin/admin.module';
import { AttachmentsModule } from './modules/attachments/attachments.module';
import { AnnouncementsModule } from './modules/announcements/announcements.module';
import { RealtimeModule } from './modules/realtime/realtime.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    CacheModule,
    HealthModule,
    IdentityModule,
    MessagingModule,
    AdvocatesModule,
    CourtsModule,
    AdminModule,
    AttachmentsModule,
    AnnouncementsModule,
    RealtimeModule,
  ],
})
export class AppModule {}
