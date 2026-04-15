#!/bin/bash
# Deploy Lambda Event Processor

FUNCTION_NAME="event-processor"
ROLE_NAME="event-processor-lambda-role"
REGION="eu-central-1"

echo "Creating IAM role for Lambda..."
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://iam/lambda-trust-policy.json

echo "Attaching execution policy..."
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

ROLE_ARN="arn:aws:iam::<ACCOUNT_ID>:role/$ROLE_NAME"

echo "Waiting for role to propagate..."
sleep 10

echo "Packaging Lambda function..."
cd lambda/event-processor
zip -r function.zip index.js
cd ../../

echo "Creating Lambda function..."
aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime nodejs20.x \
  --role "$ROLE_ARN" \
  --handler index.handler \
  --zip-file fileb://lambda/event-processor/function.zip \
  --region "$REGION"

echo "Lambda function deployed"
