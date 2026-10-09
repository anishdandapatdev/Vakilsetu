import { IsBase64, IsInt, IsString, IsUUID, Length, Max, MaxLength, Min } from 'class-validator';

export class DeliverEnvelopeDto {
  @IsUUID()
  conversationId!: string;

  @IsUUID()
  clientMessageId!: string;

  @IsUUID()
  recipientDeviceId!: string;

  @IsInt()
  @Min(1)
  @Max(2_147_483_647)
  membershipEpoch!: number;

  @IsString()
  @Length(1, 80)
  protocol!: string;

  @IsBase64()
  @MaxLength(700_000)
  ciphertext!: string;
}
