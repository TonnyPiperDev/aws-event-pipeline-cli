#!/bin/bash
# Teardown all Event Pipeline resources

REGION="eu-central-1"

echo "WARNING: This will delete ALL Event Pipeline resources!"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled"
    exit 0
fi

echo ""
echo "Starting teardown..."

# 1. Remove EventBridge targets and rule
echo "Removing EventBridge targets..."
aws events remove-targets \
  --rule event-notification-rule \
  --ids 1 2 \
  --region "$REGION" 2>/dev/null

echo "Deleting EventBridge rule..."
aws events delete-rule \
  --name event-notification-rule \
  --region "$REGION" 2>/dev/null

# 2. Delete Lambda event source mapping
echo "Removing SQS event source mapping..."
MAPPING_UUID=$(aws lambda list-event-source-mappings \
  --function-name queue-reader \
  --region "$REGION" \
  --query 'EventSourceMappings[0].UUID' \
  --output text 2>/dev/null)

if [ "$MAPPING_UUID" != "None" ] && [ -n "$MAPPING_UUID" ]; then
    aws lambda delete-event-source-mapping \
      --uuid "$MAPPING_UUID" \
      --region "$REGION" 2>/dev/null
fi

# 3. Delete Lambda functions
echo "Deleting Lambda functions..."
aws lambda delete-function --function-name event-processor --region "$REGION" 2>/dev/null
aws lambda delete-function --function-name queue-reader --region "$REGION" 2>/dev/null

# 4. Delete SNS subscriptions and topic
echo "Deleting SNS subscriptions..."
SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --region "$REGION" \
  --query 'Subscriptions[*].SubscriptionArn' \
  --output text 2>/dev/null)

for SUB in $SUBSCRIPTIONS; do
    aws sns unsubscribe --subscription-arn "$SUB" --region "$REGION" 2>/dev/null
done

echo "Deleting SNS topic..."
aws sns delete-topic --topic-arn "$SNS_TOPIC_ARN" --region "$REGION" 2>/dev/null

# 5. Delete SQS queue
echo "Deleting SQS queue..."
aws sqs delete-queue --queue-url "$QUEUE_URL" --region "$REGION" 2>/dev/null

# 6. Delete Secrets Manager secret
echo "Deleting secret..."
aws secretsmanager delete-secret \
  --secret-id event-pipeline/api-key \
  --force-delete-without-recovery \
  --region "$REGION" 2>/dev/null

# 7. Detach policies and delete IAM roles
echo "Detaching IAM policies..."
aws iam detach-role-policy \
  --role-name event-processor-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null

aws iam delete-role-policy \
  --role-name queue-reader-lambda-role \
  --policy-name QueueReaderExecutionPolicy 2>/dev/null

echo "Deleting IAM roles..."
aws iam delete-role --role-name event-processor-lambda-role 2>/dev/null
aws iam delete-role --role-name queue-reader-lambda-role 2>/dev/null

# 8. Delete CloudWatch log groups
echo "Deleting CloudWatch log groups..."
aws logs delete-log-group --log-group-name /aws/lambda/event-processor --region "$REGION" 2>/dev/null
aws logs delete-log-group --log-group-name /aws/lambda/queue-reader --region "$REGION" 2>/dev/null

echo ""
echo "✅ Teardown complete!"
echo "All Event Pipeline resources have been deleted."
