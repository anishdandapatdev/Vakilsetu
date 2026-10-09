import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';
import { AttachmentsService } from './attachments.service';
import { InitiateAttachmentDto } from './dto/initiate-attachment.dto';
import { ServerAttachmentDto } from './dto/server-attachment.dto';
import { ServerAttachmentsService } from './server-attachments.service';
import { SharedAttachmentsQueryDto } from './dto/shared-attachments-query.dto';

@Controller()
@UseGuards(AccessSessionGuard)
export class AttachmentsController {
  constructor(private readonly attachments: AttachmentsService,
    private readonly serverAttachments: ServerAttachmentsService) {}
  @Get('server-attachments')
  listServer(@CurrentIdentity() identity: RequestIdentity,
    @Query() query: SharedAttachmentsQueryDto) {
    return this.serverAttachments.listShared(identity, query.before, query.limit,
      query.search, query.kind);
  }
  @Post('conversations/:conversationId/server-attachments')
  initiateServer(@CurrentIdentity() identity: RequestIdentity,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
    @Body() input: ServerAttachmentDto) {
    return this.serverAttachments.initiate(identity, conversationId, input);
  }
  @Post('server-attachments/:attachmentId/complete')
  completeServer(@CurrentIdentity() identity: RequestIdentity,
    @Param('attachmentId', new ParseUUIDPipe()) attachmentId: string) {
    return this.serverAttachments.complete(identity, attachmentId);
  }
  @Get('server-attachments/:attachmentId/download')
  downloadServer(@CurrentIdentity() identity: RequestIdentity,
    @Param('attachmentId', new ParseUUIDPipe()) attachmentId: string) {
    return this.serverAttachments.download(identity, attachmentId);
  }
  @Post('conversations/:conversationId/attachments')
  initiate(@CurrentIdentity() identity: RequestIdentity,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
    @Body() input: InitiateAttachmentDto) {
    return this.attachments.initiate(identity, conversationId, input);
  }
  @Get('attachments/:attachmentId/download')
  download(@CurrentIdentity() identity: RequestIdentity,
    @Param('attachmentId', new ParseUUIDPipe()) attachmentId: string) {
    return this.attachments.download(identity, attachmentId);
  }
  @Post('attachments/:attachmentId/complete')
  complete(@CurrentIdentity() identity: RequestIdentity,
    @Param('attachmentId', new ParseUUIDPipe()) attachmentId: string) {
    return this.attachments.complete(identity, attachmentId);
  }
  @Delete('attachments/:attachmentId')
  @HttpCode(204)
  remove(@CurrentIdentity() identity: RequestIdentity,
    @Param('attachmentId', new ParseUUIDPipe()) attachmentId: string) {
    return this.attachments.remove(identity, attachmentId);
  }
}
