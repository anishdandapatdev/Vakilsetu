import { IsOptional, IsString, IsUUID, Length, Matches, ValidateIf } from 'class-validator';

export class ServerMessageDto {
  @IsUUID()
  clientMessageId!: string;

  @ValidateIf(value => !value.attachmentId || value.body !== undefined)
  @IsString()
  @Length(1, 4000)
  @Matches(/\S/)
  body?: string;

  @IsOptional()
  @IsUUID()
  attachmentId?: string;

  @IsOptional()
  @IsUUID()
  replyToMessageId?: string;
}
