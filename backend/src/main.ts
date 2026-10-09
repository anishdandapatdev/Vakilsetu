import 'dotenv/config';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { NextFunction, Request, Response } from 'express';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { loadEnvironment } from './platform/config/environment';

async function bootstrap(): Promise<void> {
  const env = loadEnvironment(process.env);
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: true });

  app.set('trust proxy', env.trustProxyHops);
  app.setGlobalPrefix('v1');
  app.use(helmet({ contentSecurityPolicy: false }));
  app.use((request: Request, response: Response, next: NextFunction) => {
    if (!env.requireHttps || request.secure) return next();
    response.status(426).json({
      statusCode: 426,
      error: 'Upgrade Required',
      message: 'https_required',
    });
  });
  app.enableCors({
    origin: env.publicAppOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'DELETE'],
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      stopAtFirstError: false,
    }),
  );

  await app.listen(env.port, env.apiBindHost);
}

void bootstrap();
