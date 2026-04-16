# AWS Event-Driven Notification Pipeline

## What it does

This project builds an event-driven notification system using AWS serverless services. Events published to EventBridge are automatically routed to multiple targets: Lambda functions for immediate processing, SNS topics for fan-out distribution to email/SMS/SQS subscribers, and SQS queues for durable async processing. Lambda functions retrieve credentials from Secrets Manager to call external APIs securely.

**Real-world use case:** Multi-tenant SaaS applications routing events (user signups, payment failures, system alerts) to different consumers (ops Slack, support emails, audit logs, billing systems) without tight coupling between components.

## Architecture
![Architecture Diagram](architecture-diagram.png)

## AWS Services Used

- EventBridge — Event routing and scheduling
- SNS — Pub/sub message distribution
- SQS — Message queuing and buffering
- Lambda — Event processing (event-processor, queue-reader)
- Secrets Manager — Credential storage
- IAM — Service roles and resource-based policies
- CloudWatch Logs — Centralized logging

## Prerequisites

- AWS CLI installed and configured
- AWS account with appropriate IAM permissions
- Node.js installed (for Lambda dependencies)
- Region: eu-central-1

## Infrastructure Setup

**EventBridge Rule:**
- Rule name: event-notification-rule
- Event pattern: Matches all events (any source)
- Targets: Lambda Event Processor (ID: 1), SNS Topic (ID: 2)
- State: Enabled

**SNS Topic:**
- Topic name: event-notifications
- Type: Standard (not FIFO)
- Subscriptions: Email, SQS queue
- Region: eu-central-1

**SQS Queue:**
- Queue name: event-processing-queue
- Type: Standard
- Visibility timeout: 30 seconds (default)
- Message retention: 4 days (default)

**Lambda Functions:**
- **event-processor:**
  - Runtime: Node.js 20.x
  - Memory: 128 MB
  - Timeout: 3 seconds (default)
  - Trigger: EventBridge rule
  - Role: event-processor-lambda-role (CloudWatch Logs write access)
  
- **queue-reader:**
  - Runtime: Node.js 20.x
  - Memory: 128 MB
  - Timeout: 30 seconds
  - Trigger: SQS event source mapping (batch size: 5)
  - Role: queue-reader-lambda-role (SQS read/delete, Secrets Manager read, CloudWatch Logs)

**Secrets Manager:**
- Secret name: event-pipeline/api-key
- Contains: JSON with apiKey and serviceUrl fields
- Encryption: AWS managed key

**IAM Roles:**
- **event-processor-lambda-role:**
  - Trust policy: Lambda service
  - Permissions: AWSLambdaBasicExecutionRole (managed policy)
  
- **queue-reader-lambda-role:**
  - Trust policy: Lambda service
  - Permissions: SQS (ReceiveMessage, DeleteMessage), Secrets Manager (GetSecretValue), CloudWatch Logs

## Deployment

See the deployment guide for step-by-step CLI instructions (to be created).

## Project Structure
```
aws-event-pipeline-cli/
├── iam/                       # IAM policy templates (placeholders)
├── lambda/
│   ├── event-processor/       # Immediate event processing
│   └── queue-reader/          # SQS consumer with Secrets Manager
└── scripts/
├── deploy/                # Deployment scripts (01-05)
├── test/                  # End-to-end test script
└── cleanup/               # Teardown script
```

## Author

Tonny Piper • [Portfolio](https://tonnypiper.dev) • [GitHub](https://github.com/TonnyPiperDev)
