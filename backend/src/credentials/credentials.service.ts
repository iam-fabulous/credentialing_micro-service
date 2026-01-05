import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { Transaction } from '@mysten/sui/transactions';
import { decodeSuiPrivateKey } from '@mysten/sui/cryptography';

import axios from 'axios';
import { IssueCredentialDto } from './dto/issue-credential.dto';

@Injectable()
export class CredentialsService {
    private readonly publisherUrl: string;
    private readonly suiNetwork: 'testnet' | 'mainnet' | 'devnet';
    private readonly packageId: string;
    private readonly adminCapId: string;
    private readonly adminPrivateKey: string;
    private readonly versionObjectId: string;

    constructor(private configService: ConfigService) {
        const url = this.configService.get<string>('PUBLISHER_URL');
        if (!url) {
            throw new InternalServerErrorException('PUBLISHER_URL not configured');
        }
        this.publisherUrl = url;

        const suiNetworkValue = this.configService.get<string>('SUI_NETWORK') || 'testnet';
        if (!suiNetworkValue || !['mainnet', 'testnet', 'devnet', 'localnet'].includes(suiNetworkValue)) {
            throw new InternalServerErrorException('SUI_NETWORK not configured or invalid');
        }
        this.suiNetwork = suiNetworkValue as 'testnet' | 'mainnet' | 'devnet';

        this.packageId = this.configService.get<string>('SUI_PACKAGE_ID') || '';
        if (!this.packageId) throw new InternalServerErrorException('PACKAGE_ID not configured');

        this.adminCapId = this.configService.get<string>('SUI_ADMIN_CAP_ID') || '';
        if (!this.adminCapId) throw new InternalServerErrorException('ADMIN_CAP_ID not configured');

        this.adminPrivateKey = this.configService.get<string>('ADMIN_PRIVATE_KEY') || '';
        if (!this.adminPrivateKey) throw new InternalServerErrorException('ADMIN_PRIVATE_KEY not configured');

        this.versionObjectId = this.configService.get<string>('VERSION_OBJECT_ID') || '';
    }

    private readonly logger = new Logger(CredentialsService.name);

    async processIssuance(file: Express.Multer.File, issueCredentialDto: IssueCredentialDto) {
        this.logger.log(`Processing credential issuance for ${issueCredentialDto.recipientEmail}...`);

        const blobId = await this.uploadToWalrus(file.buffer, file.mimetype);

        if(!blobId) {
            throw new InternalServerErrorException('Failed to upload file to Walrus.');
        }

        this.logger.log(`Storage Successful! Blob ID: ${blobId}`);

        const txDigest = await this.mintCredential(blobId, issueCredentialDto);
        return {
            status: 'success',
            message: 'Credential Stored Successfully',
            data: {
                blobId,
                txDigest,
                walrusUrl: `https://aggregator.walrus-testnet.walrus.space/v1/blobs/${blobId}`,
                explorerUrl: `https://suiscan.xyz/${this.suiNetwork}/tx/${txDigest}`
            }
        }
    }

    private async uploadToWalrus(fileBuffer: Buffer, mimeType: string): Promise<string> {
        try {
            const url = `${this.publisherUrl}/v1/blobs?epochs=5`;
            const response = await axios.put(url, fileBuffer, {
                headers: { 'Content-Type': mimeType },
                maxBodyLength: Infinity,
                maxContentLength: Infinity,
            });

            const data = response.data;
            let blobId: string;

            if (data.newlyCreated){
                blobId = data.newlyCreated.blobObject.blobId;
            } else if (data.alreadyCertified){
                blobId = data.alreadyCertified.blobId;
            } else {
                throw new Error('Unexpected response structure from Walrus.');
            }
            return blobId;
        } catch (error) {
            this.logger.error('Error uploading to Walrus:', error.message);
            if (error.response) {
                this.logger.error(`Server response: ${JSON.stringify(error.response.data)}`);
            }
            throw new InternalServerErrorException('Failed to upload file to Walrus.');
        }
    }

    private async mintCredential(blobId: string, issueCredentialDto: IssueCredentialDto): Promise<string> {
        try{
            this.logger.log('Initiating mintCredential transaction...');

            const client = new SuiClient({ url: getFullnodeUrl(this.suiNetwork) });

            // 1. Decode the Bech32 string (suiprivkey1...) into raw bytes
            // This strips the prefix and converts the text into the actual secret numbers.
            const { secretKey } = decodeSuiPrivateKey(this.adminPrivateKey);
            const keyPair = Ed25519Keypair.fromSecretKey(secretKey);
            const adminAddress = keyPair.toSuiAddress();
            this.logger.log(`Admin Address: ${adminAddress}`);

            // Construct the transaction payload
            const tx = new Transaction();
            // Add transaction details here using blobId and issueCredentialDto
            tx.moveCall({
                target: `${this.packageId}::cert::mint_credential_v2`,
                arguments: [
                    tx.object(this.adminCapId),
                    tx.object(this.versionObjectId),
                    tx.pure.address(adminAddress),
                    tx.pure.string(issueCredentialDto.recipientName),
                    tx.pure.string(issueCredentialDto.courseName),
                    tx.pure.string(issueCredentialDto.issueDate),
                    tx.pure.string("EnumVerse Academy Inc."),
                    tx.pure.string(blobId),
                ],
                typeArguments: [],
            });

            const result = await client.signAndExecuteTransaction({
                signer: keyPair,
                transaction: tx,
                options: {
                    showEffects: true,
                },
            });
            if (result.effects?.status.status === 'success') {
                this.logger.log(`🎉 Mint Success! Digest: ${result.digest}`);
                return result.digest;
            } else {
                throw new Error(`Sui Transaction Failed: ${result.effects?.status.error}`);
            }

        } catch (error) {
            
            this.logger.error(`Sui Mint Error: ${error.message}`);
            throw new InternalServerErrorException('Blockchain minting failed.');
        }
    }
}
