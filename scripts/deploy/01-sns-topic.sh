#!/bin/bash
# Deploy SNS Topic for event notifications

TOPIC_NAME="event-notifications"
REGION="eu-central-1"

echo "Creating SNS topic: $TOPIC_NAME"
aws sns create-topic \
  --name "$TOPIC_NAME" \
  --region "$REGION"

echo ""
echo "Topic created. To subscribe an email:"
echo "aws sns subscribe --topic-arn <TOPIC_ARN> --protocol email --notification-endpoint YOUR_EMAIL --region $REGION"
