import { Matches } from 'class-validator';

export class RequestOtpDto {
  @Matches(/^\+91[6-9]\d{9}$/, { message: 'phone must be an Indian E.164 number' })
  phone!: string;
}
