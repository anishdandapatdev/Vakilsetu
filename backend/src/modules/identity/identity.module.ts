import { Module } from '@nestjs/common';
import { SessionPolicy } from './session.policy';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { DevelopmentOtpSender, DisabledOtpSender, Msg91OtpSender, OTP_SENDER } from './otp.sender';
import { loadEnvironment } from '../../platform/config/environment';
import { AccessSessionGuard } from './access-session.guard';
import { DevicesController } from './devices.controller';
import { DevicesService } from './devices.service';
import { SessionResolver } from './session-resolver.service';

@Module({
  controllers: [AuthController, DevicesController],
  providers: [
    SessionPolicy,
    AuthService,
    AccessSessionGuard,
    DevicesService,
    SessionResolver,
    {
      provide: OTP_SENDER,
      useFactory: () => {
        const provider = loadEnvironment(process.env).otpProvider;
        if (provider === 'configured') return new Msg91OtpSender();
        if (provider === 'development') return new DevelopmentOtpSender();
        return new DisabledOtpSender();
      },
    },
  ],
  exports: [SessionPolicy, AccessSessionGuard, SessionResolver],
})
export class IdentityModule {}
