#!/bin/bash

# Setup script for Thakii ECS Infrastructure
echo "🚀 Setting up Thakii ECS Infrastructure..."

# Variables
ACCOUNT_ID="222156782817"
REGION="us-east-2"
CLUSTER_NAME="Thakii"
REPOSITORY_NAME="thakii-lecture2pdf-service"

echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"

# 1. Create ECS Cluster
echo "📦 Creating ECS Cluster..."
aws ecs create-cluster --cluster-name $CLUSTER_NAME --region $REGION

# 2. Create ECR Repository
echo "🐳 Creating ECR Repository..."
aws ecr create-repository --repository-name $REPOSITORY_NAME --region $REGION

# 3. Get default VPC and subnets
echo "🌐 Getting VPC information..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region $REGION --output text --query 'Vpcs[0].VpcId')
echo "Default VPC: $VPC_ID"

SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --output text --query 'Subnets[*].SubnetId' | tr '\t' ',')
echo "Subnets: $SUBNET_IDS"

# 4. Create Security Group
echo "🔒 Creating Security Group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name thakii-ecs-sg \
    --description "Security group for Thakii ECS service" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --output text --query 'GroupId')

echo "Security Group: $SG_ID"

# Allow inbound traffic on port 5002
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 5002 \
    --cidr 0.0.0.0/0 \
    --region $REGION

echo "✅ Infrastructure setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Build and push Docker image to ECR"
echo "2. Create ECS service"
echo ""
echo "ECR Repository URI: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME"
echo "Docker login command:"
echo "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com" 