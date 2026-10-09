import { IsIn, IsUUID } from 'class-validator';

export class ChangeMemberDto {
  @IsUUID()
  accountId!: string;

  @IsIn(['add', 'remove'])
  action!: 'add' | 'remove';
}
