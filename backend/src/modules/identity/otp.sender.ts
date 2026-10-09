import { ServiceUnavailableException } from '@nestjs/common';
import { loadEnvironment } from '../../platform/config/environment';

export const OTP_SENDER = Symbol('OTP_SENDER');

export interface OtpSender {
  send(phoneE164: string, code: string): Promise<void>;
}

export class DisabledOtpSender implements OtpSender {
  async send(_phoneE164: string, _code: string): Promise<void> {
    throw new ServiceUnavailableException('otp_provider_not_configured');
  }
}

/** Local-only sender. The code is fixed by AuthService and never leaves this process. */
export class DevelopmentOtpSender implements OtpSender {
  async send(phoneE164: string, code: string): Promise<void> {
    // Deliberately avoid logging any real provider credentials or session tokens.
    console.info(`[development-otp] ${phoneE164} -> ${code}`);
  }
}

export class Msg91OtpSender implements OtpSender {
  private readonly env = loadEnvironment(process.env);

  async send(phoneE164: string, code: string): Promise<void> {
    const url = new URL('https://control.msg91.com/api/v5/otp');
    url.searchParams.set('template_id', this.env.msg91TemplateId!);
    url.searchParams.set('mobile', phoneE164.slice(1));
    url.searchParams.set('otp', code);
    const response = await fetch(url, {
      method: 'POST',
      headers: { accept: 'application/json', authkey: this.env.msg91AuthKey! },
      signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) {
      throw new ServiceUnavailableException('otp_delivery_failed');
    }
    const body = (await response.json()) as { type?: string };
    if (body.type && body.type !== 'success') {
      throw new ServiceUnavailableException('otp_delivery_failed');
    }
  }
}
