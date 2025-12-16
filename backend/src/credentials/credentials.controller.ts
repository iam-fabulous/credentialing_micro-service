import {
    Controller,
    Post,
    UseInterceptors,
    UploadedFile,
    Body,
    BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CredentialsService } from './credentials.service';
import { IssueCredentialDto } from './dto/issue-credential.dto';

@Controller('credentials')
export class CredentialsController {
    constructor(private readonly credentialsService: CredentialsService) {}

    @Post('issue')
    @UseInterceptors(FileInterceptor('file'))
    async issueCredential(
        @UploadedFile() file: Express.Multer.File,
        @Body() issueCredentialDto: IssueCredentialDto,
    ) {
        if (!file) {
            throw new BadRequestException('File is required');
        }

        console.log(`Received file: ${file.originalname}, size: ${file.size} bytes`);
        console.log(`Recipient Email: ${issueCredentialDto.recipientEmail}`);

        return this.credentialsService.processIssuance(file, issueCredentialDto);
    }
}