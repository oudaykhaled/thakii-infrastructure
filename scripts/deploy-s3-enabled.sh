#!/bin/bash

# Deploy S3-enabled Thakii Lecture2PDF Service to ECS
echo "🚀 Deploying S3-enabled Thakii Service to ECS..."

# Variables
ACCOUNT_ID="222156782817"
REGION="us-east-2"
REPOSITORY_NAME="thakii-lecture2pdf-service"
CLUSTER_NAME="Thakii"
SERVICE_NAME="thakii-lecture2pdf-s3-service"
TASK_DEFINITION="thakii-lecture2pdf-task"

# ECR Repository URI
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME"

echo "🔑 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Check if we have a built image
if docker images | grep -q "thakii-lecture2pdf-service"; then
    echo "✅ Using existing thakii-lecture2pdf-service image"
    IMAGE_NAME="thakii-lecture2pdf-service"
else
    echo "⚠️  Building minimal S3-enabled image..."
    docker build -t thakii-lecture2pdf-service-minimal -f Dockerfile.minimal .
    IMAGE_NAME="thakii-lecture2pdf-service-minimal"
fi

echo "🏷️ Tagging image for ECR..."
docker tag $IMAGE_NAME:latest $ECR_URI:latest

echo "📦 Pushing to ECR..."
docker push $ECR_URI:latest

echo "📋 Registering updated task definition with S3 support..."
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

# Delete existing service if it exists
echo "🗑️  Checking for existing service..."
aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION &>/dev/null
if [ $? -eq 0 ]; then
    echo "Updating existing service..."
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --task-definition $TASK_DEFINITION \
        --region $REGION
else
    echo "🚀 Creating new ECS Service with S3 integration..."
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --task-definition $TASK_DEFINITION \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_LIST],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
        --region $REGION
fi

echo "✅ S3-enabled deployment complete!"
echo ""
echo "📊 Check service status:"
echo "aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION"
echo ""
echo "🪣 S3 Bucket: thakii-video-storage-1753883631"
echo "📋 View service in AWS Console:"
echo "https://$REGION.console.aws.amazon.com/ecs/home?region=$REGION#/clusters/$CLUSTER_NAME/services" 