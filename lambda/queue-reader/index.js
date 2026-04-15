const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");
const { SQSClient, DeleteMessageCommand } = require("@aws-sdk/client-sqs");

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION });
const sqsClient = new SQSClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('Received SQS event:', JSON.stringify(event, null, 2));
    
    // Retrieve secret from Secrets Manager
    const secretName = process.env.SECRET_NAME;
    let secret;
    
    try {
        const command = new GetSecretValueCommand({ SecretId: secretName });
        const response = await secretsClient.send(command);
        secret = JSON.parse(response.SecretString);
        console.log('Retrieved secret successfully');
    } catch (error) {
        console.error('Error retrieving secret:', error);
        throw error;
    }
    
    // Process each SQS message
    for (const record of event.Records) {
        try {
            // Parse SNS message wrapper
            const snsMessage = JSON.parse(record.body);
            const actualMessage = snsMessage.Message;
            
            console.log('Processing message:', actualMessage);
            console.log('Using API key from Secrets Manager:', secret.apiKey.substring(0, 10) + '...');
            
            // In production, you would call external API here using secret.apiKey and secret.serviceUrl
            // For now, just log that we would make the call
            console.log(`Would call ${secret.serviceUrl} with the retrieved API key`);
            
        } catch (error) {
            console.error('Error processing message:', error);
            throw error;
        }
    }
    
    return { statusCode: 200, body: 'Messages processed successfully' };
};
