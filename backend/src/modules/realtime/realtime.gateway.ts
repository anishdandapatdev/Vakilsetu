import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { loadEnvironment } from '../../platform/config/environment';
import { SessionResolver } from '../identity/session-resolver.service';

const environment = loadEnvironment(process.env);
const allowedOrigins = environment.publicAppOrigins;

@WebSocketGateway({ namespace: '/realtime', transports: ['websocket'], cors: { origin: allowedOrigins } })
export class RealtimeGateway {
  @WebSocketServer() private server!: Server;
  constructor(private readonly sessions: SessionResolver) {}

  async handleConnection(socket: Socket): Promise<void> {
    try {
      const forwardedProtocol = String(
        socket.handshake.headers['x-forwarded-proto'] ?? '',
      ).split(',')[0].trim().toLowerCase();
      if (environment.requireHttps && forwardedProtocol !== 'https') {
        throw new Error('https_required');
      }
      const token = typeof socket.handshake.auth?.accessToken === 'string'
        ? socket.handshake.auth.accessToken
        : '';
      const identity = await this.sessions.resolve(token);
      socket.data.identity = identity;
      socket.data.accessToken = token;
      await socket.join(`device:${identity.deviceId}`);
      await socket.join(`account:${identity.accountId}`);
    } catch {
      socket.disconnect(true);
    }
  }

  async notifyDevice(deviceId: string, eventId: string): Promise<void> {
    const sockets = await this.server.in(`device:${deviceId}`).fetchSockets();
    await Promise.all(sockets.map(async (socket) => {
      try {
        const identity = await this.sessions.resolve(String(socket.data.accessToken ?? ''));
        if (identity.deviceId !== deviceId) throw new Error('device_mismatch');
        socket.emit('sync:available', { eventId });
      } catch {
        socket.disconnect(true);
      }
    }));
  }

  async notifyAccount(accountId: string, eventId: string): Promise<void> {
    const sockets = await this.server.in(`account:${accountId}`).fetchSockets();
    await Promise.all(sockets.map(async socket => {
      try {
        const identity = await this.sessions.resolve(String(socket.data.accessToken ?? ''));
        if (identity.accountId !== accountId) throw new Error('account_mismatch');
        socket.emit('sync:available', { eventId });
      } catch {
        socket.disconnect(true);
      }
    }));
  }
}
