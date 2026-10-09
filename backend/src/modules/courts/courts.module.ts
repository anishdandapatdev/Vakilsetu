import { Module } from '@nestjs/common';
import { CourtsController } from './courts.controller';
import { IdentityModule } from '../identity/identity.module';
import { CourtSubscriptionsController } from './court-subscriptions.controller';

@Module({
  imports: [IdentityModule],
  controllers: [CourtsController, CourtSubscriptionsController],
})
export class CourtsModule {}
