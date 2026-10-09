import { IsBase64, IsIn, IsUUID, Matches, MinLength } from 'class-validator';

export class VerifyOtpDto {
  @IsUUID()
  challengeId!: string;

  @Matches(/^\d{6}$/)
  code!: string;

  @IsIn(['android', 'ios', 'web'])
  platform!: 'android' | 'ios' | 'web';

  @IsBase64()
  @MinLength(40)
  publicIdentityKey!: string;
}
