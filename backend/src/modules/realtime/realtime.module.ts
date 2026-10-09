import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/identity.module';
import { InboxController } from './inbox.controller';
import { InboxService } from './inbox.service';
import { PushRegistrationController } from './push-registration.controller';
import { PushRegistrationService } from './push-registration.service';
import { RealtimeGateway } from './realtime.gateway';

@Module({
  imports: [IdentityModule],
  controllers: [InboxController, PushRegistrationController],
  providers: [InboxService, PushRegistrationService, RealtimeGateway],
  exports: [RealtimeGateway],
})
export class RealtimeModule {}
