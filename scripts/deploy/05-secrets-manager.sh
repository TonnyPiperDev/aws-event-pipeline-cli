#!/bin/bash
# Deploy Secrets Manager and Queue Reader Lambda

SECRET_NAME="event-pipeline/api-key"
FUNCTION_NAME="queue-reader"
ROLE_NAME="queue-reader-lambda-role"
QUEUE_ARN="<QUEUE_ARN>"
REGION="eu-central-1"

echo "Creating secret in Secrets Manager..."
aws secretsmanager create-secret \
  --name "$SECRET_NAME" \
  --description "Sample API key for external service integration" \
  --secret-string '{"apiKey":"dummy-key-12345","serviceUrl":"https://api.example.com"}' \
  --region "$REGION"

echo "Creating IAM role for Queue Reader Lambda..."
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://iam/lambda-trust-policy.json

echo "Attaching execution policy..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name QueueReaderExecutionPolicy \
  --policy-document file://iam/queue-reader-policy.json

ROLE_ARN="arn:aws:iam::<ACCOUNT_ID>:role/$ROLE_NAME"

echo "Waiting for role to propagate..."
sleep 10

echo "Installing dependencies..."
cd lambda/queue-reader
npm install
zip -r function.zip index.js package.json node_modules/
cd ../../

echo "Creating Queue Reader Lambda..."
aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime nodejs20.x \
  --role "$ROLE_ARN" \
  --handler index.handler \
  --zip-file fileb://lambda/queue-reader/function.zip \
  --timeout 30 \
  --environment Variables="{SECRET_NAME=$SECRET_NAME}" \
  --region "$REGION"

echo "Connecting SQS to Lambda..."
aws lambda create-event-source-mapping \
  --function-name "$FUNCTION_NAME" \
  --event-source-arn "$QUEUE_ARN" \
  --batch-size 5 \
  --region "$REGION"

echo "Queue Reader Lambda deployed with Secrets Manager integration"
