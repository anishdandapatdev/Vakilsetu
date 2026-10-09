import { Body, Controller, DefaultValuePipe, Get, Param, ParseIntPipe, ParseUUIDPipe, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AdminRequest, AdminSessionGuard } from '../admin/admin-session.guard';
import { AnnouncementsService } from './announcements.service';
import { AnnouncementDto } from './dto/announcement.dto';

@Controller()
export class AnnouncementsController {
  constructor(private readonly announcements: AnnouncementsService) {}

  @Get('channels/:channelId/announcements')
  list(
    @Param('channelId', new ParseUUIDPipe()) channelId: string,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) requestedLimit: number,
    @Query('offset', new DefaultValuePipe(0), ParseIntPipe) requestedOffset: number,
  ) {
    const limit = Math.min(50, Math.max(1, requestedLimit));
    const offset = Math.max(0, requestedOffset);
    return this.announcements.list(channelId, limit, offset);
  }

  @Post('admin/channels/:channelId/announcements')
  @UseGuards(AdminSessionGuard)
  create(
    @Req() request: AdminRequest,
    @Param('channelId', new ParseUUIDPipe()) channelId: string,
    @Body() input: AnnouncementDto,
  ) { return this.announcements.create(request.adminIdentity, channelId, input); }

  @Patch('admin/announcements/:announcementId')
  @UseGuards(AdminSessionGuard)
  update(
    @Req() request: AdminRequest,
    @Param('announcementId', new ParseUUIDPipe()) announcementId: string,
    @Body() input: AnnouncementDto,
  ) { return this.announcements.update(request.adminIdentity, announcementId, input); }
}
