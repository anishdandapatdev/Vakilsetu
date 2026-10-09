import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Request } from 'express';
import { RequestIdentity } from './session.policy';

export type AuthenticatedRequest = Request & { identity: RequestIdentity };

export const CurrentIdentity = createParamDecorator(
  (_data: unknown, context: ExecutionContext): RequestIdentity =>
    context.switchToHttp().getRequest<AuthenticatedRequest>().identity,
);
