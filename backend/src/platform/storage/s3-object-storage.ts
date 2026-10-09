import { DeleteObjectCommand, GetObjectCommand, HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { createHash } from 'node:crypto';
import { loadEnvironment } from '../config/environment';
import { ObjectStorage } from './object-storage';

export class S3ObjectStorage implements ObjectStorage {
  private readonly bucket: string;
  private readonly client: S3Client;
  private readonly publicClient: S3Client;

  constructor() {
    const env = loadEnvironment(process.env);
    this.bucket = env.objectStorageBucket!;
    const credentials = {
      accessKeyId: env.objectStorageAccessKeyId!,
      secretAccessKey: env.objectStorageSecretAccessKey!,
    };
    this.client = new S3Client({
      region: env.objectStorageRegion!,
      endpoint: env.objectStorageEndpoint || undefined,
      forcePathStyle: Boolean(env.objectStorageEndpoint),
      credentials,
    });
    this.publicClient = env.objectStoragePublicEndpoint
      ? new S3Client({
          region: env.objectStorageRegion!,
          endpoint: env.objectStoragePublicEndpoint,
          forcePathStyle: true,
          credentials,
        })
      : this.client;
  }

  async createCiphertextUpload(key: string, size: number, sha256Hex: string) {
    return this.createUpload(key, size, sha256Hex, 'application/octet-stream');
  }

  async createCiphertextDownload(key: string) {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ResponseContentType: 'application/octet-stream',
      ResponseContentDisposition: 'attachment; filename="encrypted-file.bin"',
    });
    return { url: await getSignedUrl(this.publicClient, command, { expiresIn: 60 }), expiresInSeconds: 60 };
  }

  async verifyCiphertextObject(key: string, size: number, sha256Hex: string): Promise<boolean> {
    return this.verifyObject(key, size, sha256Hex);
  }

  async deleteCiphertextObject(key: string): Promise<void> {
    await this.deleteObject(key);
  }

  async createUpload(key: string, size: number, sha256Hex: string, contentType: string) {
    const checksum = Buffer.from(sha256Hex, 'hex').toString('base64');
    const command = new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType,
      ContentLength: size, ChecksumSHA256: checksum, Metadata: { sha256: sha256Hex } });
    return { url: await getSignedUrl(this.publicClient, command, { expiresIn: 300 }), expiresInSeconds: 300 };
  }
  async createDownload(key: string, filename: string, contentType: string) {
    const safe = filename.replace(/["\r\n]/g, '_');
    const command = new GetObjectCommand({ Bucket: this.bucket, Key: key,
      ResponseContentType: contentType, ResponseContentDisposition: `attachment; filename="${safe}"` });
    return { url: await getSignedUrl(this.publicClient, command, { expiresIn: 60 }), expiresInSeconds: 60 };
  }
  async verifyObject(key: string, size: number, sha256Hex: string): Promise<boolean> {
    const head = await this.client.send(new HeadObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ChecksumMode: 'ENABLED',
    }));
    const expected = Buffer.from(sha256Hex, 'hex').toString('base64');
    if (head.ContentLength !== size) return false;
    if (head.ChecksumSHA256) return head.ChecksumSHA256 === expected;
    // Some S3-compatible stores (including local MinIO versions) omit the
    // checksum from HEAD. Verify the actual object bytes, never client metadata.
    const bytes = await this.readObject(key);
    return bytes.length === size &&
      createHash('sha256').update(bytes).digest('hex') === sha256Hex.toLowerCase();
  }
  async readObject(key: string): Promise<Uint8Array> {
    const object = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    if (!object.Body) throw new Error('object_body_missing');
    return object.Body.transformToByteArray();
  }
  async deleteObject(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }
}
