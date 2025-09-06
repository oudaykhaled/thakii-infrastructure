#!/bin/bash

# Get ECS Task Public IP
echo "🔍 Getting ECS Task Details..."

CLUSTER_NAME="Thakii"
SERVICE_NAME="thakii-lecture2pdf-s3-service"
REGION="us-east-2"

# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $REGION --output text --query 'taskArns[0]')

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    echo "Task ARN: $TASK_ARN"
    
    # Get ENI ID
    ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $REGION --output text --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value')
    
    if [ -n "$ENI_ID" ]; then
        echo "ENI ID: $ENI_ID"
        
        # Get Public IP
        PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $REGION --output text --query 'NetworkInterfaces[0].Association.PublicIp')
        
        if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
            echo "✅ Public IP: $PUBLIC_IP"
            echo "🌐 Service URL: http://$PUBLIC_IP:5002"
            echo ""
            echo "📋 Test endpoints:"
            echo "  - Upload: POST http://$PUBLIC_IP:5002/upload"
            echo "  - List: GET http://$PUBLIC_IP:5002/list"
            echo "  - Download: GET http://$PUBLIC_IP:5002/download/{video_id}"
        else
            echo "❌ No public IP found"
        fi
    else
        echo "❌ No ENI found"
    fi
else
    echo "❌ No running tasks found"
    echo "Creating service..."
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --task-definition thakii-lecture2pdf-task \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[subnet-085a78f6d4b7ba2f7,subnet-0e9eb850bf1328b57,subnet-0b22463e89a9b4bf0],securityGroups=[sg-00003f2239a46a678],assignPublicIp=ENABLED}" \
        --region $REGION > /dev/null
    
    echo "⏳ Service created. Wait 2-3 minutes for task to start, then run this script again."
fi 