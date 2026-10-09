import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/identity.module';
import { DisabledObjectStorage, OBJECT_STORAGE } from '../../platform/storage/object-storage';
import { AttachmentsController } from './attachments.controller';
import { AttachmentsService } from './attachments.service';
import { loadEnvironment } from '../../platform/config/environment';
import { S3ObjectStorage } from '../../platform/storage/s3-object-storage';
import { ServerAttachmentsService } from './server-attachments.service';
import { MALWARE_SCANNER, DisabledMalwareScanner, DevelopmentCleanScanner } from '../../platform/security/malware-scanner';
import { ClamAvMalwareScanner } from '../../platform/security/clamav-malware-scanner';

@Module({
  imports: [IdentityModule],
  controllers: [AttachmentsController],
  providers: [
    AttachmentsService,
    ServerAttachmentsService,
    {
      provide: MALWARE_SCANNER,
      useFactory: () => {
        const environment = loadEnvironment(process.env);
        if (environment.malwareScannerProvider === 'development') return new DevelopmentCleanScanner();
        if (environment.malwareScannerProvider === 'clamav') {
          return new ClamAvMalwareScanner(environment.clamavHost!, environment.clamavPort!);
        }
        return new DisabledMalwareScanner();
      },
    },
    {
      provide: OBJECT_STORAGE,
      useFactory: () => loadEnvironment(process.env).objectStorageProvider === 'configured'
        ? new S3ObjectStorage()
        : new DisabledObjectStorage(),
    },
  ],
})
export class AttachmentsModule {}
