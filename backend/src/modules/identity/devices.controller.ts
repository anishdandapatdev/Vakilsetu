import { Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from './access-session.guard';
import { CurrentIdentity } from './request-identity';
import { RequestIdentity } from './session.policy';
import { DevicesService, DeviceView } from './devices.service';

@Controller('devices')
@UseGuards(AccessSessionGuard)
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  @Get()
  list(@CurrentIdentity() identity: RequestIdentity): Promise<DeviceView[]> {
    return this.devices.list(identity);
  }

  @Delete(':deviceId')
  @HttpCode(204)
  revoke(
    @CurrentIdentity() identity: RequestIdentity,
    @Param('deviceId', new ParseUUIDPipe()) deviceId: string,
  ): Promise<void> {
    return this.devices.revoke(identity, deviceId);
  }
}
