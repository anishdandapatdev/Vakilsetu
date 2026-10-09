import { Body, Controller, Get, Put, Query, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';
import { AdvocatesService } from './advocates.service';
import { DirectoryQueryDto } from './dto/directory-query.dto';
import { UpsertProfileDto } from './dto/upsert-profile.dto';

@Controller('advocates')
@UseGuards(AccessSessionGuard)
export class AdvocatesController {
  constructor(private readonly advocates: AdvocatesService) {}

  @Get('me')
  me(@CurrentIdentity() identity: RequestIdentity) { return this.advocates.me(identity); }

  @Put('me')
  upsert(@CurrentIdentity() identity: RequestIdentity, @Body() input: UpsertProfileDto) {
    return this.advocates.upsert(identity, input);
  }

  @Get()
  directory(@Query() input: DirectoryQueryDto) { return this.advocates.directory(input); }
}
