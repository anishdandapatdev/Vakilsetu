import { IsUUID } from 'class-validator';

export class ReadMessagesDto {
  @IsUUID()
  throughMessageId!: string;
}
