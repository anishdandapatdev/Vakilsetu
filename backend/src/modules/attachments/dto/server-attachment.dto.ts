import { IsIn, IsInt, IsString, Length, Matches, Max, Min } from 'class-validator';

export class ServerAttachmentDto {
  @IsString() @Length(1, 180) @Matches(/^[^\\/\r\n]+$/) filename!: string;
  @IsIn(['application/pdf', 'image/jpeg', 'image/png']) contentType!: string;
  @IsInt() @Min(1) @Max(25 * 1024 * 1024) byteSize!: number;
  @Matches(/^[a-fA-F0-9]{64}$/) sha256!: string;
}
