#!/bin/bash

echo "🔍 Diagnosing ECS Service Connection Issues..."

SG_ID="sg-00003f2239a46a678"
REGION="us-east-2"
SERVICE_IP="18.216.7.92"

# Check Security Group Rules
echo "🔒 Checking Security Group Rules..."
aws ec2 describe-security-groups --group-ids $SG_ID --region $REGION --output table --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]'

echo ""
echo "📋 Current Security Group Rules:"
aws ec2 describe-security-groups --group-ids $SG_ID --region $REGION --output text --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort]'

echo ""
echo "🔧 Adding port 5002 rule if missing..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 5002 \
    --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null && echo "✅ Port 5002 rule added" || echo "⚠️  Port 5002 rule already exists or failed to add"

echo ""
echo "🌐 Testing connectivity..."
echo "Testing port 5002..."
nc -zv $SERVICE_IP 5002 2>&1 | head -1

echo ""
echo "📊 ECS Task Status:"
TASK_ARN=$(aws ecs list-tasks --cluster Thakii --service-name thakii-lecture2pdf-s3-service --region $REGION --output text --query 'taskArns[0]')
aws ecs describe-tasks --cluster Thakii --tasks $TASK_ARN --region $REGION --output text --query 'tasks[0].[lastStatus,healthStatus,containers[0].lastStatus]'

echo ""
echo "📝 CloudWatch Logs (if available):"
LOG_STREAM=$(aws logs describe-log-streams --log-group-name "/ecs/thakii-lecture2pdf" --region $REGION --output text --query 'logStreams[0].logStreamName' 2>/dev/null)
if [ -n "$LOG_STREAM" ]; then
    echo "Latest logs:"
    aws logs get-log-events --log-group-name "/ecs/thakii-lecture2pdf" --log-stream-name "$LOG_STREAM" --region $REGION --output text --query 'events[-5:].message' 2>/dev/null
else
    echo "No logs available yet"
fi 