#!/bin/bash
# Deploy EventBridge Rule and Targets

RULE_NAME="event-notification-rule"
LAMBDA_ARN="<LAMBDA_FUNCTION_ARN>"
SNS_ARN="<SNS_TOPIC_ARN>"
REGION="eu-central-1"

echo "Creating EventBridge rule..."
aws events put-rule \
  --name "$RULE_NAME" \
  --description "Route events to Lambda processor and SNS topic" \
  --event-pattern '{"source":[{"prefix":""}]}' \
  --state ENABLED \
  --region "$REGION"

RULE_ARN="arn:aws:events:$REGION:<ACCOUNT_ID>:rule/$RULE_NAME"

echo "Adding Lambda as target..."
aws events put-targets \
  --rule "$RULE_NAME" \
  --targets "Id"="1","Arn"="$LAMBDA_ARN" \
  --region "$REGION"

echo "Granting EventBridge permission to invoke Lambda..."
aws lambda add-permission \
  --function-name event-processor \
  --statement-id AllowEventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "$RULE_ARN" \
  --region "$REGION"

echo "Adding SNS as target..."
aws events put-targets \
  --rule "$RULE_NAME" \
  --targets "Id"="2","Arn"="$SNS_ARN" \
  --region "$REGION"

echo "Applying SNS topic policy..."
aws sns set-topic-attributes \
  --topic-arn "$SNS_ARN" \
  --attribute-name Policy \
  --attribute-value file://iam/sns-topic-policy.json \
  --region "$REGION"

echo "EventBridge rule deployed with Lambda and SNS targets"
