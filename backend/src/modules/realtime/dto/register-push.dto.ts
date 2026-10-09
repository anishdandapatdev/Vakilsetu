import { IsIn, IsString, Length } from 'class-validator';

export class RegisterPushDto {
  @IsIn(['fcm', 'apns', 'webpush'])
  provider!: 'fcm' | 'apns' | 'webpush';

  @IsString()
  @Length(20, 4096)
  token!: string;
}
