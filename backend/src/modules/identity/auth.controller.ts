import { Body, Controller, Headers, Ip, Post, UseGuards } from '@nestjs/common';
import { AccessSessionGuard } from './access-session.guard';
import { AuthService } from './auth.service';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { RefreshSessionDto } from './dto/refresh-session.dto';

@Controller('auth/otp')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('request')
  request(@Body() input: RequestOtpDto, @Ip() ip: string) {
    return this.auth.requestOtp(input.phone, ip);
  }

  @Post('verify')
  verify(@Body() input: VerifyOtpDto) {
    return this.auth.verifyOtp(input);
  }

  @Post('refresh')
  refresh(@Body() input: RefreshSessionDto) {
    return this.auth.refresh(input.refreshToken);
  }

  @Post('logout')
  @UseGuards(AccessSessionGuard)
  async logout(@Headers('authorization') authorization: string): Promise<{ signedOut: true }> {
    await this.auth.logout(authorization.slice('Bearer '.length));
    return { signedOut: true };
  }
}
