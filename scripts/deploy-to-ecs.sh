#!/bin/bash

# Deploy Thakii Lecture2PDF Service to ECS
echo "🚀 Deploying Thakii Lecture2PDF Service to ECS..."

# Variables
ACCOUNT_ID="222156782817"
REGION="us-east-2"
REPOSITORY_NAME="thakii-lecture2pdf-service"
CLUSTER_NAME="Thakii"
SERVICE_NAME="thakii-lecture2pdf-service"
TASK_DEFINITION="thakii-lecture2pdf-task"

# ECR Repository URI
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME"

echo "🔑 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

echo "🐳 Building Docker image..."
docker build -t $REPOSITORY_NAME .

echo "🏷️ Tagging image..."
docker tag $REPOSITORY_NAME:latest $ECR_URI:latest

echo "📦 Pushing to ECR..."
docker push $ECR_URI:latest

echo "📋 Registering task definition..."
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json --region $REGION

echo "🌐 Getting network configuration..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region $REGION --output text --query 'Vpcs[0].VpcId')
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --output text --query 'Subnets[*].SubnetId')
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=thakii-ecs-sg" --region $REGION --output text --query 'SecurityGroups[0].GroupId')

# Convert subnet IDs to comma-separated string
SUBNET_LIST=$(echo $SUBNET_IDS | tr ' ' ',')

echo "VPC: $VPC_ID"
echo "Subnets: $SUBNET_LIST"
echo "Security Group: $SG_ID"

echo "🚀 Creating ECS Service..."
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition $TASK_DEFINITION \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_LIST],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --region $REGION

echo "✅ Deployment complete!"
echo ""
echo "📊 Check service status:"
echo "aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION"
echo ""
echo "📋 View service in AWS Console:"
echo "https://$REGION.console.aws.amazon.com/ecs/home?region=$REGION#/clusters/$CLUSTER_NAME/services" 