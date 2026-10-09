import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/identity.module';
import { AdvocatesController } from './advocates.controller';
import { AdvocatesService } from './advocates.service';

@Module({ imports: [IdentityModule], controllers: [AdvocatesController], providers: [AdvocatesService] })
export class AdvocatesModule {}
