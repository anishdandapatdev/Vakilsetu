import { Module } from '@nestjs/common';
import { AdminSessionGuard } from './admin-session.guard';
import { VerificationController } from './verification.controller';

@Module({
  controllers: [VerificationController],
  providers: [AdminSessionGuard],
  exports: [AdminSessionGuard],
})
export class AdminModule {}
