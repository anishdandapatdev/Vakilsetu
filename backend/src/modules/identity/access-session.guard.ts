import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthenticatedRequest } from './request-identity';
import { SessionResolver } from './session-resolver.service';

@Injectable()
export class AccessSessionGuard implements CanActivate {
  constructor(private readonly sessions: SessionResolver) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = request.get('authorization');
    const match = authorization?.match(/^Bearer ([A-Za-z0-9_-]{40,})$/);
    if (!match) throw new UnauthorizedException('invalid_session');

    request.identity = await this.sessions.resolve(match[1]);
    return true;
  }
}
