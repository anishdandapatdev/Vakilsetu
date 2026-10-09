import { ArrayMaxSize, ArrayMinSize, IsArray, IsString, IsUUID, Length } from 'class-validator';

export class CreateGroupDto {
  @IsString()
  @Length(2, 80)
  title!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(99)
  @IsUUID('4', { each: true })
  memberAccountIds!: string[];
}
