import { IsEmail, IsString, IsNotEmpty } from "class-validator";

export class IssueCredentialDto {
    @IsEmail({}, { message: 'Recipient must be a valid email address' })
    recipientEmail: string;

    @IsString({ message: 'Credential type must be a string' })
    @IsNotEmpty({ message: 'Credential type should not be empty' })
    recipientName: string;

    @IsString()
    @IsNotEmpty()
    courseName: string;

    @IsString()
    @IsNotEmpty()
    issueDate: string;
}