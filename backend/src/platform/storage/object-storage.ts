import { ServiceUnavailableException } from '@nestjs/common';

export const OBJECT_STORAGE = Symbol('OBJECT_STORAGE');

export interface ObjectStorage {
  createUpload(key: string, size: number, sha256Hex: string, contentType: string): Promise<{ url: string; expiresInSeconds: number }>;
  createDownload(key: string, filename: string, contentType: string): Promise<{ url: string; expiresInSeconds: number }>;
  verifyObject(key: string, size: number, sha256Hex: string): Promise<boolean>;
  readObject(key: string): Promise<Uint8Array>;
  deleteObject(key: string): Promise<void>;
  createCiphertextUpload(key: string, size: number, sha256Hex: string): Promise<{ url: string; expiresInSeconds: number }>;
  createCiphertextDownload(key: string): Promise<{ url: string; expiresInSeconds: number }>;
  verifyCiphertextObject(key: string, size: number, sha256Hex: string): Promise<boolean>;
  deleteCiphertextObject(key: string): Promise<void>;
}

export class DisabledObjectStorage implements ObjectStorage {
  async createUpload(): Promise<never> { throw new ServiceUnavailableException('object_storage_not_configured'); }
  async createDownload(): Promise<never> { throw new ServiceUnavailableException('object_storage_not_configured'); }
  async verifyObject(): Promise<never> { throw new ServiceUnavailableException('object_storage_not_configured'); }
  async readObject(): Promise<never> { throw new ServiceUnavailableException('object_storage_not_configured'); }
  async deleteObject(): Promise<never> { throw new ServiceUnavailableException('object_storage_not_configured'); }
  async createCiphertextUpload(): Promise<never> {
    throw new ServiceUnavailableException('object_storage_not_configured');
  }
  async createCiphertextDownload(): Promise<never> {
    throw new ServiceUnavailableException('object_storage_not_configured');
  }
  async verifyCiphertextObject(): Promise<never> {
    throw new ServiceUnavailableException('object_storage_not_configured');
  }
  async deleteCiphertextObject(): Promise<never> {
    throw new ServiceUnavailableException('object_storage_not_configured');
  }
}
