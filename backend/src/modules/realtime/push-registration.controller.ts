import { Body, Controller, Delete, HttpCode, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from '../identity/access-session.guard';
import { CurrentIdentity } from '../identity/request-identity';
import { RequestIdentity } from '../identity/session.policy';
import { RegisterPushDto } from './dto/register-push.dto';
import { PushRegistrationService } from './push-registration.service';

@Controller('push-registrations')
@UseGuards(AccessSessionGuard)
export class PushRegistrationController {
  constructor(private readonly registrations: PushRegistrationService) {}
  @Post()
  register(@CurrentIdentity() identity: RequestIdentity, @Body() input: RegisterPushDto) {
    return this.registrations.register(identity, input);
  }
  @Delete(':registrationId')
  @HttpCode(204)
  remove(@CurrentIdentity() identity: RequestIdentity,
    @Param('registrationId', new ParseUUIDPipe()) registrationId: string) {
    return this.registrations.remove(identity, registrationId);
  }
}
