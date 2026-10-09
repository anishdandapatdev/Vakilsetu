import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';
import { AcknowledgeDto } from './dto/acknowledge.dto';
import { InboxService } from './inbox.service';
import { InboxQueryDto } from './dto/inbox-query.dto';

@Controller('inbox')
@UseGuards(AccessSessionGuard)
export class InboxController {
  constructor(private readonly inbox: InboxService) {}
  @Get()
  page(@CurrentIdentity() identity: RequestIdentity,
    @Query() query: InboxQueryDto) {
    return this.inbox.page(identity, query.after || null, query.limit);
  }
  @Post('acknowledgements')
  acknowledge(@CurrentIdentity() identity: RequestIdentity, @Body() input: AcknowledgeDto) {
    return this.inbox.acknowledge(identity, input.envelopeIds);
  }
}
