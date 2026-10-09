import { ForbiddenException, Injectable } from '@nestjs/common';

export type RequestIdentity = Readonly<{
  accountId: string;
  deviceId: string;
  advocateStatus: 'pending' | 'verified' | 'rejected' | 'suspended';
  deviceStatus: 'pending' | 'trusted' | 'revoked';
}>;

@Injectable()
export class SessionPolicy {
  assertPrivateMessagingAllowed(identity: RequestIdentity): void {
    if (identity.advocateStatus !== 'verified') {
      throw new ForbiddenException('verified_advocate_required');
    }
    if (identity.deviceStatus !== 'trusted') {
      throw new ForbiddenException('trusted_device_required');
    }
  }
}
