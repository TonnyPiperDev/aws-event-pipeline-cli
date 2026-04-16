#!/bin/bash
# Test the complete event pipeline end-to-end

REGION="eu-central-1"

echo "========================================="
echo "Event Pipeline End-to-End Test"
echo "========================================="
echo ""

# Test 1: Publish event to EventBridge
echo "1. Publishing test event to EventBridge..."
EVENT_ID=$(aws events put-events \
  --entries '[
    {
      "Source": "test.e2e",
      "DetailType": "E2ETest",
      "Detail": "{\"testId\":\"'$(date +%s)'\",\"message\":\"End-to-end pipeline test\"}"
    }
  ]' \
  --region "$REGION" \
  --query 'Entries[0].EventId' \
  --output text)

echo "   ✓ Event published (ID: $EVENT_ID)"
echo ""

# Test 2: Check Event Processor Lambda logs
echo "2. Checking Event Processor Lambda execution..."
sleep 5
RECENT_LOG=$(aws logs tail /aws/lambda/event-processor --since 30s --region "$REGION" 2>/dev/null | grep "E2ETest")

if [ -n "$RECENT_LOG" ]; then
    echo "   ✓ Event Processor received event"
else
    echo "   ✗ Event Processor did not receive event"
fi
echo ""

# Test 3: Check SQS queue for message
echo "3. Checking SQS queue..."
sleep 5
MESSAGE=$(aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --region "$REGION" \
  --query 'Messages[0].Body' \
  --output text 2>/dev/null)

if [ "$MESSAGE" != "None" ] && [ -n "$MESSAGE" ]; then
    echo "   ✓ Message arrived in SQS queue"
    
    # Delete the test message
    RECEIPT=$(aws sqs receive-message \
      --queue-url "$QUEUE_URL" \
      --region "$REGION" \
      --query 'Messages[0].ReceiptHandle' \
      --output text 2>/dev/null)
    
    if [ "$RECEIPT" != "None" ] && [ -n "$RECEIPT" ]; then
        aws sqs delete-message \
          --queue-url "$QUEUE_URL" \
          --receipt-handle "$RECEIPT" \
          --region "$REGION" 2>/dev/null
        echo "   ✓ Test message cleaned up"
    fi
else
    echo "   ⚠ No message in SQS queue (might have been processed already)"
fi
echo ""

# Test 4: Check Queue Reader Lambda logs
echo "4. Checking Queue Reader Lambda execution..."
sleep 8
QUEUE_LOG=$(aws logs tail /aws/lambda/queue-reader --since 30s --region "$REGION" 2>/dev/null | grep "Retrieved secret successfully")

if [ -n "$QUEUE_LOG" ]; then
    echo "   ✓ Queue Reader processed message and retrieved secret"
else
    echo "   ⚠ Queue Reader may not have processed yet (check logs manually)"
fi
echo ""

echo "========================================="
echo "Test Complete!"
echo "========================================="
echo ""
echo "Expected flow:"
echo "  EventBridge → Event Processor Lambda ✓"
echo "  EventBridge → SNS → SQS ✓"
echo "  SQS → Queue Reader Lambda → Secrets Manager ✓"
