import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class SharedAttachmentsQueryDto {
  @IsOptional()
  @IsUUID()
  before?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  search = '';

  @IsOptional()
  @IsIn(['all', 'pdf', 'images'])
  kind: 'all' | 'pdf' | 'images' = 'all';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 50;
}
