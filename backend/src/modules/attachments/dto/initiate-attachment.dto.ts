import { IsInt, Matches, Max, Min } from 'class-validator';

export class InitiateAttachmentDto {
  @IsInt()
  @Min(1)
  membershipEpoch!: number;

  @IsInt()
  @Min(1)
  @Max(104_857_600)
  ciphertextSize!: number;

  @Matches(/^[a-f0-9]{64}$/i)
  ciphertextSha256!: string;
}
