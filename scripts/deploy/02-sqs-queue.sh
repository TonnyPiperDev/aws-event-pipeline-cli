#!/bin/bash
# Deploy SQS Queue and subscribe to SNS

QUEUE_NAME="event-processing-queue"
TOPIC_ARN="<SNS_TOPIC_ARN>"
REGION="eu-central-1"
ACCOUNT_ID="<ACCOUNT_ID>"

echo "Creating SQS queue: $QUEUE_NAME"
QUEUE_URL=$(aws sqs create-queue \
  --queue-name "$QUEUE_NAME" \
  --region "$REGION" \
  --query 'QueueUrl' \
  --output text)

echo "Queue created: $QUEUE_URL"

QUEUE_ARN="arn:aws:sqs:$REGION:$ACCOUNT_ID:$QUEUE_NAME"

echo "Applying queue policy to allow SNS to send messages..."
aws sqs set-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attributes '{
    "Policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"sns.amazonaws.com\"},\"Action\":\"SQS:SendMessage\",\"Resource\":\"'$QUEUE_ARN'\",\"Condition\":{\"ArnEquals\":{\"aws:SourceArn\":\"'$TOPIC_ARN'\"}}}]}"
  }' \
  --region "$REGION"

echo "Subscribing queue to SNS topic..."
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol sqs \
  --notification-endpoint "$QUEUE_ARN" \
  --region "$REGION"

echo "SQS queue deployed and subscribed to SNS"
