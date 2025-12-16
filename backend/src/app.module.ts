import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import  { ConfigModule } from '@nestjs/config';
import { CredentialsModule } from './credentials/credentials.module';

@Module({
  imports: [ConfigModule.forRoot({
    isGlobal: true,
  }),
  CredentialsModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
