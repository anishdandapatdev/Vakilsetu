import { loadEnvironment } from '../src/platform/config/environment';

const valid = {
  NODE_ENV: 'test',
  PORT: '8080',
  DATABASE_URL: 'postgresql://local/test',
  REDIS_URL: 'redis://local',
  PUBLIC_APP_ORIGINS: 'http://localhost:3000',
  SESSION_SIGNING_KEY: '12345678901234567890123456789012',
  OTP_HASH_PEPPER: 'abcdefghijklmnopqrstuvwxyz123456',
  ADMIN_SESSION_SIGNING_KEY: '654321zyxwvutsrqponmlkjihgfedcba',
  PUSH_TOKEN_ENCRYPTION_KEY: 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
};

describe('loadEnvironment', () => {
  it('binds locally by default and permits the container listener explicitly', () => {
    expect(loadEnvironment(valid).apiBindHost).toBe('127.0.0.1');
    expect(loadEnvironment({ ...valid, API_BIND_HOST: '0.0.0.0' }).apiBindHost).toBe('0.0.0.0');
    expect(() => loadEnvironment({ ...valid, API_BIND_HOST: 'example.com' }))
      .toThrow('API_BIND_HOST must be 127.0.0.1 or 0.0.0.0');
  });

  it('rejects wildcard CORS', () => {
    expect(() => loadEnvironment({ ...valid, PUBLIC_APP_ORIGINS: '*' })).toThrow(
      'Wildcard CORS origins are forbidden',
    );
  });

  it('rejects short session signing keys', () => {
    expect(() => loadEnvironment({ ...valid, SESSION_SIGNING_KEY: 'short' })).toThrow(
      'SESSION_SIGNING_KEY must be at least 32 characters',
    );
  });

  it('allows the fixed OTP sender only outside production', () => {
    expect(loadEnvironment({
      ...valid,
      NODE_ENV: 'development',
      OTP_PROVIDER: 'development',
      DEVELOPMENT_OTP_CODE: '123456',
    }).developmentOtpCode).toBe('123456');

    expect(() => loadEnvironment({
      ...valid,
      NODE_ENV: 'production',
      OTP_PROVIDER: 'development',
    })).toThrow('OTP_PROVIDER=development is forbidden in production');
  });

  it('rejects an invalid development OTP code', () => {
    expect(() => loadEnvironment({
      ...valid,
      OTP_PROVIDER: 'development',
      DEVELOPMENT_OTP_CODE: '1234',
    })).toThrow('DEVELOPMENT_OTP_CODE must contain exactly 6 digits');
  });

  it('allows the development malware scanner only outside production', () => {
    expect(loadEnvironment({
      ...valid,
      NODE_ENV: 'development',
      MALWARE_SCANNER_PROVIDER: 'development',
    }).malwareScannerProvider).toBe('development');

    expect(() => loadEnvironment({
      ...valid,
      NODE_ENV: 'production',
      MALWARE_SCANNER_PROVIDER: 'development',
    })).toThrow('MALWARE_SCANNER_PROVIDER=development is forbidden in production');
  });

  it('requires a valid ClamAV endpoint', () => {
    expect(() => loadEnvironment({
      ...valid,
      MALWARE_SCANNER_PROVIDER: 'clamav',
    })).toThrow('CLAMAV_HOST is required');

    expect(() => loadEnvironment({
      ...valid,
      MALWARE_SCANNER_PROVIDER: 'clamav',
      CLAMAV_HOST: '127.0.0.1',
      CLAMAV_PORT: 'invalid',
    })).toThrow('CLAMAV_PORT must be a valid TCP port');

    const environment = loadEnvironment({
      ...valid,
      MALWARE_SCANNER_PROVIDER: 'clamav',
      CLAMAV_HOST: '127.0.0.1',
      CLAMAV_PORT: '3310',
    });
    expect(environment.clamavHost).toBe('127.0.0.1');
    expect(environment.clamavPort).toBe(3310);
  });

  it('keeps message retention opt-in and validates its range', () => {
    expect(loadEnvironment(valid).messageRetentionDays).toBeUndefined();
    expect(loadEnvironment({
      ...valid,
      MESSAGE_RETENTION_DAYS: '365',
    }).messageRetentionDays).toBe(365);
    for (const invalid of ['0', '29', '3651', '30.5', 'forever']) {
      expect(() => loadEnvironment({
        ...valid,
        MESSAGE_RETENTION_DAYS: invalid,
      })).toThrow('MESSAGE_RETENTION_DAYS must be an integer from 30 to 3650');
    }
  });

  it('requires HTTPS in production and validates trusted proxy depth', () => {
    const production = loadEnvironment({ ...valid, NODE_ENV: 'production' });
    expect(production.requireHttps).toBe(true);
    expect(production.trustProxyHops).toBe(1);

    expect(() => loadEnvironment({
      ...valid,
      NODE_ENV: 'production',
      REQUIRE_HTTPS: 'false',
    })).toThrow('REQUIRE_HTTPS cannot be disabled in production');
    expect(() => loadEnvironment({
      ...valid,
      REQUIRE_HTTPS: 'true',
      TRUST_PROXY_HOPS: '0',
    })).toThrow('TRUST_PROXY_HOPS must be at least 1');
    expect(() => loadEnvironment({
      ...valid,
      TRUST_PROXY_HOPS: '4',
    })).toThrow('TRUST_PROXY_HOPS must be an integer from 0 to 3');
  });
});
