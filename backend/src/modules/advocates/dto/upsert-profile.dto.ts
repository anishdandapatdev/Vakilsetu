import { IsString, IsUUID, Length, Matches } from 'class-validator';

export class UpsertProfileDto {
  @IsString()
  @Length(2, 120)
  fullName!: string;

  @Matches(/^[A-Z]{1,5}\/\d{1,8}\/\d{4}$/i)
  enrollmentNumber!: string;

  @IsUUID()
  primaryCourtId!: string;
}
