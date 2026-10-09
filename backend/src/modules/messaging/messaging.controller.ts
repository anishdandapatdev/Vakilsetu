import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';
import { DeliverEnvelopeDto } from './dto/deliver-envelope.dto';
import { DeliveryService } from './delivery.service';

@Controller('private-messages')
export class MessagingController {
  constructor(private readonly delivery: DeliveryService) {}

  @Post('envelopes')
  @UseGuards(AccessSessionGuard)
  deliver(@CurrentIdentity() identity: RequestIdentity, @Body() request: DeliverEnvelopeDto) {
    return this.delivery.deliver(identity, request);
  }
}
