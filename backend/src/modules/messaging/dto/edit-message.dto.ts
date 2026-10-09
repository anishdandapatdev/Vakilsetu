import { IsString, Length, Matches } from 'class-validator';

export class EditMessageDto {
  @IsString()
  @Length(1, 4000)
  @Matches(/\S/)
  body!: string;
}
