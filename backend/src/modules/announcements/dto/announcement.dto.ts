import { IsOptional, IsString, Length } from 'class-validator';

export class AnnouncementDto {
  @IsString()
  @Length(1, 10_000)
  body!: string;

  @IsOptional()
  @IsString()
  @Length(1, 500)
  attachmentObjectKey?: string;
}
