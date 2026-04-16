# Deployment Guide

Step-by-step instructions for deploying the Event-Driven Notification Pipeline via AWS CLI.

## Prerequisites

- AWS CLI installed and configured with credentials
- AWS account with administrator access (or appropriate IAM permissions)
- Node.js installed (v18 or later)
- Region: eu-central-1 (Frankfurt)

## Deployment Steps

### 1. SNS Topic

Create the SNS topic for message distribution:

```bash
aws sns create-topic \
  --name event-notifications \
  --region eu-central-1
```

Save the returned `TopicArn`.

Subscribe your email for notifications:

```bash
aws sns subscribe \
  --topic-arn <TOPIC_ARN> \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --region eu-central-1
```

Check your email and confirm the subscription.

---

### 2. SQS Queue

Create the SQS queue:

```bash
aws sqs create-queue \
  --queue-name event-processing-queue \
  --region eu-central-1
```

Save the returned `QueueUrl`.

Get the Queue ARN:

```bash
aws sqs get-queue-attributes \
  --queue-url <QUEUE_URL> \
  --attribute-names QueueArn \
  --region eu-central-1
```

Apply queue policy (allows SNS to send messages):

```bash
aws sqs set-queue-attributes \
  --queue-url <QUEUE_URL> \
  --attributes '{
    "Policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"sns.amazonaws.com\"},\"Action\":\"SQS:SendMessage\",\"Resource\":\"<QUEUE_ARN>\",\"Condition\":{\"ArnEquals\":{\"aws:SourceArn\":\"<SNS_TOPIC_ARN>\"}}}]}"
  }' \
  --region eu-central-1
```

Subscribe queue to SNS topic:

```bash
aws sns subscribe \
  --topic-arn <SNS_TOPIC_ARN> \
  --protocol sqs \
  --notification-endpoint <QUEUE_ARN> \
  --region eu-central-1
```

---

### 3. Lambda Event Processor

Create IAM role:

```bash
aws iam create-role \
  --role-name event-processor-lambda-role \
  --assume-role-policy-document file://iam/lambda-trust-policy.json \
  --region eu-central-1
```

Attach execution policy:

```bash
aws iam attach-role-policy \
  --role-name event-processor-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

Package Lambda function:

```bash
cd lambda/event-processor
zip -r function.zip index.js
cd ../../
```

Deploy Lambda:

```bash
aws lambda create-function \
  --function-name event-processor \
  --runtime nodejs20.x \
  --role <LAMBDA_ROLE_ARN> \
  --handler index.handler \
  --zip-file fileb://lambda/event-processor/function.zip \
  --region eu-central-1
```

---

### 4. EventBridge Rule

Create rule:

```bash
aws events put-rule \
  --name event-notification-rule \
  --description "Route events to Lambda processor and SNS topic" \
  --event-pattern '{"source":[{"prefix":""}]}' \
  --state ENABLED \
  --region eu-central-1
```

Add Lambda as target:

```bash
aws events put-targets \
  --rule event-notification-rule \
  --targets "Id"="1","Arn"="<LAMBDA_FUNCTION_ARN>" \
  --region eu-central-1
```

Grant EventBridge permission to invoke Lambda:

```bash
aws lambda add-permission \
  --function-name event-processor \
  --statement-id AllowEventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn <EVENTBRIDGE_RULE_ARN> \
  --region eu-central-1
```

Add SNS as target:

```bash
aws events put-targets \
  --rule event-notification-rule \
  --targets "Id"="2","Arn"="<SNS_TOPIC_ARN>" \
  --region eu-central-1
```

Apply SNS topic policy:

```bash
aws sns set-topic-attributes \
  --topic-arn <SNS_TOPIC_ARN> \
  --attribute-name Policy \
  --attribute-value file://iam/sns-topic-policy.json \
  --region eu-central-1
```

---

### 5. Secrets Manager & Queue Reader Lambda

Create secret:

```bash
aws secretsmanager create-secret \
  --name event-pipeline/api-key \
  --description "Sample API key for external service integration" \
  --secret-string '{"apiKey":"dummy-key-12345","serviceUrl":"https://api.example.com"}' \
  --region eu-central-1
```

Create IAM role for Queue Reader:

```bash
aws iam create-role \
  --role-name queue-reader-lambda-role \
  --assume-role-policy-document file://iam/lambda-trust-policy.json \
  --region eu-central-1
```

Attach custom policy:

```bash
aws iam put-role-policy \
  --role-name queue-reader-lambda-role \
  --policy-name QueueReaderExecutionPolicy \
  --policy-document file://iam/queue-reader-policy.json
```

Install dependencies and package Lambda:

```bash
cd lambda/queue-reader
npm install
zip -r function.zip index.js package.json node_modules/
cd ../../
```

Deploy Queue Reader Lambda:

```bash
aws lambda create-function \
  --function-name queue-reader \
  --runtime nodejs20.x \
  --role <QUEUE_READER_ROLE_ARN> \
  --handler index.handler \
  --zip-file fileb://lambda/queue-reader/function.zip \
  --timeout 30 \
  --environment Variables="{SECRET_NAME=event-pipeline/api-key}" \
  --region eu-central-1
```

Connect SQS to Lambda:

```bash
aws lambda create-event-source-mapping \
  --function-name queue-reader \
  --event-source-arn <QUEUE_ARN> \
  --batch-size 5 \
  --region eu-central-1
```

---

## Testing

Run the end-to-end test:

```bash
./scripts/test/test-end-to-end.sh
```

Or test manually:

```bash
aws events put-events \
  --entries '[{
    "Source": "test.app",
    "DetailType": "TestEvent",
    "Detail": "{\"message\":\"test\"}"
  }]' \
  --region eu-central-1
```

Check Lambda logs:

```bash
aws logs tail /aws/lambda/event-processor --follow --region eu-central-1
aws logs tail /aws/lambda/queue-reader --follow --region eu-central-1
```

---

## Cleanup

To delete all resources:

```bash
./scripts/cleanup/teardown.sh
```
