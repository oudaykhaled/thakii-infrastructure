#!/bin/bash

# Check ECS Task Health and Logs
echo "🔍 Checking ECS Task Health and Logs..."

CLUSTER_NAME="Thakii"
SERVICE_NAME="thakii-lecture2pdf-s3-service"
REGION="us-east-2"

# Get task details
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $REGION --output text --query 'taskArns[0]')

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    echo "📋 Task ARN: $TASK_ARN"
    
    # Get task status
    TASK_STATUS=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $REGION --output text --query 'tasks[0].[lastStatus,healthStatus,containers[0].lastStatus,containers[0].healthStatus]')
    echo "📊 Task Status: $TASK_STATUS"
    
    # Get detailed task info
    echo ""
    echo "🔍 Detailed Task Information:"
    aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --region $REGION --output table --query 'tasks[0].containers[0].[name,lastStatus,healthStatus,exitCode,reason]'
    
    # Get CloudWatch logs
    echo ""
    echo "📝 CloudWatch Logs:"
    LOG_STREAMS=$(aws logs describe-log-streams --log-group-name "/ecs/thakii-lecture2pdf" --region $REGION --output text --query 'logStreams[*].logStreamName' 2>/dev/null | head -3)
    
    if [ -n "$LOG_STREAMS" ]; then
        for stream in $LOG_STREAMS; do
            echo "--- Log Stream: $stream ---"
            aws logs get-log-events --log-group-name "/ecs/thakii-lecture2pdf" --log-stream-name "$stream" --region $REGION --output text --query 'events[-10:].message' 2>/dev/null | tail -5
            echo ""
        done
    else
        echo "❌ No CloudWatch logs found"
    fi
    
else
    echo "❌ No running tasks found"
fi

echo ""
echo "🌐 Service Summary:"
aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION --output table --query 'services[0].[serviceName,status,runningCount,desiredCount,pendingCount]' 2>/dev/null || echo "Service info unavailable" 