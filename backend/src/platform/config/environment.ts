export type RuntimeEnvironment = Readonly<{
  nodeEnv: 'development' | 'test' | 'production';
  port: number;
  apiBindHost: '127.0.0.1' | '0.0.0.0';
  databaseUrl: string;
  databaseSsl: boolean;
  redisUrl: string;
  publicAppOrigins: string[];
  sessionSigningKey: string;
  otpHashPepper: string;
  adminSessionSigningKey: string;
  otpProvider: 'disabled' | 'development' | 'configured';
  developmentOtpCode?: string;
  objectStorageProvider: 'disabled' | 'configured';
  e2eeProtocol: string;
  msg91AuthKey?: string;
  msg91TemplateId?: string;
  objectStorageEndpoint?: string;
  objectStoragePublicEndpoint?: string;
  objectStorageRegion?: string;
  objectStorageBucket?: string;
  objectStorageAccessKeyId?: string;
  objectStorageSecretAccessKey?: string;
  pushTokenEncryptionKey: string;
  pushProvider: 'disabled' | 'configured';
  malwareScannerProvider: 'disabled' | 'development' | 'clamav';
  clamavHost?: string;
  clamavPort?: number;
  messageRetentionDays?: number;
  requireHttps: boolean;
  trustProxyHops: number;
}>;

function required(source: NodeJS.ProcessEnv, key: string): string {
  const value = source[key]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${key}`);
  return value;
}

export function loadEnvironment(source: NodeJS.ProcessEnv): RuntimeEnvironment {
  const nodeEnv = source.NODE_ENV ?? 'development';
  if (!['development', 'test', 'production'].includes(nodeEnv)) {
    throw new Error('NODE_ENV must be development, test, or production');
  }

  const port = Number(source.PORT ?? 8080);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be a valid TCP port');
  }
  const apiBindHost = source.API_BIND_HOST?.trim() || '127.0.0.1';
  if (apiBindHost !== '127.0.0.1' && apiBindHost !== '0.0.0.0') {
    throw new Error('API_BIND_HOST must be 127.0.0.1 or 0.0.0.0');
  }
  const trustProxyHops = Number(source.TRUST_PROXY_HOPS ?? (nodeEnv === 'production' ? 1 : 0));
  if (!Number.isInteger(trustProxyHops) || trustProxyHops < 0 || trustProxyHops > 3) {
    throw new Error('TRUST_PROXY_HOPS must be an integer from 0 to 3');
  }
  const requireHttps = source.REQUIRE_HTTPS === undefined
    ? nodeEnv === 'production'
    : source.REQUIRE_HTTPS === 'true';
  if (nodeEnv === 'production' && !requireHttps) {
    throw new Error('REQUIRE_HTTPS cannot be disabled in production');
  }
  if (requireHttps && trustProxyHops === 0) {
    throw new Error('TRUST_PROXY_HOPS must be at least 1 when HTTPS is required');
  }

  const sessionSigningKey = required(source, 'SESSION_SIGNING_KEY');
  if (sessionSigningKey.length < 32) {
    throw new Error('SESSION_SIGNING_KEY must be at least 32 characters');
  }
  const otpHashPepper = required(source, 'OTP_HASH_PEPPER');
  if (otpHashPepper.length < 32) {
    throw new Error('OTP_HASH_PEPPER must be at least 32 characters');
  }
  const adminSessionSigningKey = required(source, 'ADMIN_SESSION_SIGNING_KEY');
  if (adminSessionSigningKey.length < 32) {
    throw new Error('ADMIN_SESSION_SIGNING_KEY must be at least 32 characters');
  }

  const origins = required(source, 'PUBLIC_APP_ORIGINS')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  if (origins.some((origin) => origin === '*')) {
    throw new Error('Wildcard CORS origins are forbidden');
  }
  const otpProvider = source.OTP_PROVIDER === 'configured'
    ? 'configured'
    : source.OTP_PROVIDER === 'development'
      ? 'development'
      : 'disabled';
  if (nodeEnv === 'production' && otpProvider === 'development') {
    throw new Error('OTP_PROVIDER=development is forbidden in production');
  }
  const malwareScannerProvider = ['development', 'clamav'].includes(source.MALWARE_SCANNER_PROVIDER ?? '')
    ? source.MALWARE_SCANNER_PROVIDER as 'development' | 'clamav'
    : 'disabled';
  if (nodeEnv === 'production' && malwareScannerProvider === 'development') {
    throw new Error('MALWARE_SCANNER_PROVIDER=development is forbidden in production');
  }
  const clamavPort = Number(source.CLAMAV_PORT ?? 3310);
  if (malwareScannerProvider === 'clamav' && !source.CLAMAV_HOST?.trim()) {
    throw new Error('CLAMAV_HOST is required for the ClamAV scanner');
  }
  if (malwareScannerProvider === 'clamav' &&
      (!Number.isInteger(clamavPort) || clamavPort < 1 || clamavPort > 65535)) {
    throw new Error('CLAMAV_PORT must be a valid TCP port');
  }
  const retentionValue = source.MESSAGE_RETENTION_DAYS?.trim();
  const messageRetentionDays = retentionValue ? Number(retentionValue) : undefined;
  if (messageRetentionDays !== undefined &&
      (!Number.isInteger(messageRetentionDays) || messageRetentionDays < 30 || messageRetentionDays > 3650)) {
    throw new Error('MESSAGE_RETENTION_DAYS must be an integer from 30 to 3650');
  }
  if (otpProvider === 'configured' && (!source.MSG91_AUTH_KEY || !source.MSG91_TEMPLATE_ID)) {
    throw new Error('MSG91 credentials are required when OTP_PROVIDER=configured');
  }
  const developmentOtpCode = source.DEVELOPMENT_OTP_CODE?.trim() || '123456';
  if (otpProvider === 'development' && !/^\d{6}$/.test(developmentOtpCode)) {
    throw new Error('DEVELOPMENT_OTP_CODE must contain exactly 6 digits');
  }
  const objectStorageProvider =
    source.OBJECT_STORAGE_PROVIDER === 'configured' ? 'configured' : 'disabled';
  if (objectStorageProvider === 'configured') {
    for (const key of [
      'OBJECT_STORAGE_REGION', 'OBJECT_STORAGE_BUCKET',
      'OBJECT_STORAGE_ACCESS_KEY_ID', 'OBJECT_STORAGE_SECRET_ACCESS_KEY',
    ]) required(source, key);
  }
  const pushTokenEncryptionKey = required(source, 'PUSH_TOKEN_ENCRYPTION_KEY');
  let pushKeyBytes: Buffer;
  try {
    pushKeyBytes = Buffer.from(pushTokenEncryptionKey, 'base64');
  } catch {
    throw new Error('PUSH_TOKEN_ENCRYPTION_KEY must be valid base64');
  }
  if (pushKeyBytes.length !== 32) {
    throw new Error('PUSH_TOKEN_ENCRYPTION_KEY must decode to exactly 32 bytes');
  }

  return Object.freeze({
    nodeEnv: nodeEnv as RuntimeEnvironment['nodeEnv'],
    port,
    apiBindHost,
    databaseUrl: required(source, 'DATABASE_URL'),
    databaseSsl: source.DATABASE_SSL === 'true',
    redisUrl: required(source, 'REDIS_URL'),
    publicAppOrigins: origins,
    sessionSigningKey,
    otpHashPepper,
    adminSessionSigningKey,
    otpProvider,
    developmentOtpCode: otpProvider === 'development' ? developmentOtpCode : undefined,
    objectStorageProvider,
    e2eeProtocol: source.E2EE_PROTOCOL?.trim() || 'disabled',
    msg91AuthKey: source.MSG91_AUTH_KEY?.trim(),
    msg91TemplateId: source.MSG91_TEMPLATE_ID?.trim(),
    objectStorageEndpoint: source.OBJECT_STORAGE_ENDPOINT?.trim(),
    objectStoragePublicEndpoint: source.OBJECT_STORAGE_PUBLIC_ENDPOINT?.trim(),
    objectStorageRegion: source.OBJECT_STORAGE_REGION?.trim(),
    objectStorageBucket: source.OBJECT_STORAGE_BUCKET?.trim(),
    objectStorageAccessKeyId: source.OBJECT_STORAGE_ACCESS_KEY_ID?.trim(),
    objectStorageSecretAccessKey: source.OBJECT_STORAGE_SECRET_ACCESS_KEY?.trim(),
    pushTokenEncryptionKey,
    pushProvider: source.PUSH_PROVIDER === 'configured' ? 'configured' : 'disabled',
    malwareScannerProvider,
    clamavHost: source.CLAMAV_HOST?.trim(),
    clamavPort,
    messageRetentionDays,
    requireHttps,
    trustProxyHops,
  });
}
