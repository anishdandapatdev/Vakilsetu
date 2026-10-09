import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';
import { ChangeMemberDto } from './dto/change-member.dto';
import { CreateDirectDto } from './dto/create-direct.dto';
import { CreateGroupDto } from './dto/create-group.dto';
import { ConversationsService } from './conversations.service';

@Controller('conversations')
@UseGuards(AccessSessionGuard)
export class ConversationsController {
  constructor(private readonly conversations: ConversationsService) {}
  @Get() list(@CurrentIdentity() identity: RequestIdentity) { return this.conversations.list(identity); }
  @Get(':conversationId')
  detail(
    @CurrentIdentity() identity: RequestIdentity,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
  ) { return this.conversations.detail(identity, conversationId); }
  @Post('direct') direct(@CurrentIdentity() identity: RequestIdentity, @Body() input: CreateDirectDto) {
    return this.conversations.direct(identity, input.peerAccountId);
  }
  @Post('groups') group(@CurrentIdentity() identity: RequestIdentity, @Body() input: CreateGroupDto) {
    return this.conversations.createGroup(identity, input);
  }
  @Patch(':conversationId/members')
  member(
    @CurrentIdentity() identity: RequestIdentity,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
    @Body() input: ChangeMemberDto,
  ) { return this.conversations.changeMember(identity, conversationId, input.accountId, input.action); }
}
