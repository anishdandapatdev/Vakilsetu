import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';
import { ServerMessageDto } from './dto/server-message.dto';
import { ServerMessagesService } from './server-messages.service';
import { MessageHistoryQueryDto } from './dto/message-history-query.dto';
import { ReadMessagesDto } from './dto/read-messages.dto';
import { EditMessageDto } from './dto/edit-message.dto';

@Controller('conversations/:conversationId/messages')
@UseGuards(AccessSessionGuard)
export class ServerMessagesController {
  constructor(private readonly messages: ServerMessagesService) {}

  @Get()
  history(@CurrentIdentity() identity: RequestIdentity,
    @Param('conversationId', new ParseUUIDPipe()) id: string,
    @Query() query: MessageHistoryQueryDto) {
    return this.messages.history(identity, id, query.before, query.limit);
  }

  @Post()
  send(@CurrentIdentity() identity: RequestIdentity, @Param('conversationId', new ParseUUIDPipe()) id: string,
    @Body() input: ServerMessageDto) {
    return this.messages.send(identity, id, input);
  }

  @Post('read')
  read(@CurrentIdentity() identity: RequestIdentity,
    @Param('conversationId', new ParseUUIDPipe()) id: string,
    @Body() input: ReadMessagesDto) {
    return this.messages.markRead(identity, id, input.throughMessageId);
  }

  @Patch(':messageId')
  edit(@CurrentIdentity() identity: RequestIdentity,
    @Param('conversationId', new ParseUUIDPipe()) id: string,
    @Param('messageId', new ParseUUIDPipe()) messageId: string,
    @Body() input: EditMessageDto) {
    return this.messages.edit(identity, id, messageId, input.body);
  }

  @Delete(':messageId')
  @HttpCode(204)
  async delete(@CurrentIdentity() identity: RequestIdentity,
    @Param('conversationId', new ParseUUIDPipe()) id: string,
    @Param('messageId', new ParseUUIDPipe()) messageId: string): Promise<void> {
    await this.messages.delete(identity, id, messageId);
  }
}
