import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/identity.module';
import { MessagingController } from './messaging.controller';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { DeliveryService } from './delivery.service';
import { BlocksController } from './blocks.controller';
import { RealtimeModule } from '../realtime/realtime.module';
import { ServerMessagesController } from './server-messages.controller';
import { ServerMessagesService } from './server-messages.service';
import { MessageRetentionService } from './message-retention.service';

@Module({
  imports: [IdentityModule, RealtimeModule],
  controllers: [MessagingController, ConversationsController, BlocksController, ServerMessagesController],
  providers: [ConversationsService, DeliveryService, ServerMessagesService, MessageRetentionService],
})
export class MessagingModule {}
