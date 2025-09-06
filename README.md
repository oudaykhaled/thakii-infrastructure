# Thakii Infrastructure

Infrastructure as Code (IaC) and deployment automation for the complete Thakii Lecture2PDF Service ecosystem. Manages AWS resources, CI/CD pipelines, monitoring, and environment provisioning using Terraform and GitHub Actions.

## 🚀 Features

- **Infrastructure as Code**: Terraform modules for all AWS resources
- **Multi-Environment Support**: Development, staging, and production environments
- **CI/CD Pipelines**: GitHub Actions workflows for automated deployment
- **Monitoring & Alerting**: CloudWatch dashboards and alarms
- **Security Management**: IAM roles, policies, and security groups
- **Cost Optimization**: Resource tagging and cost monitoring
- **Disaster Recovery**: Backup strategies and recovery procedures

## 🛠️ Technology Stack

- **Terraform**: Infrastructure provisioning and management
- **GitHub Actions**: CI/CD pipeline automation
- **AWS CLI**: Command-line AWS operations
- **Docker**: Container image building and deployment
- **Helm**: Kubernetes package management (if using EKS)
- **Ansible**: Configuration management (optional)

## 📁 Project Structure

```
thakii-infrastructure/
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── production/
│   ├── modules/
│   │   ├── api-gateway/
│   │   ├── lambda/
│   │   ├── ecs/
│   │   ├── s3/
│   │   ├── cloudfront/
│   │   └── monitoring/
│   ├── shared/
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── providers.tf
│   └── scripts/
├── github-actions/
│   ├── workflows/
│   │   ├── deploy-frontend.yml
│   │   ├── deploy-backend.yml
│   │   ├── deploy-worker.yml
│   │   └── deploy-lambda.yml
│   └── templates/
├── docker/
│   ├── backend-api/
│   ├── worker-service/
│   └── monitoring/
├── monitoring/
│   ├── dashboards/
│   ├── alerts/
│   └── grafana/
├── scripts/
│   ├── setup-environment.sh
│   ├── deploy-all.sh
│   └── backup-restore.sh
└── docs/
    ├── deployment-guide.md
    ├── monitoring-guide.md
    └── troubleshooting.md
```

## 🏗️ Infrastructure Components

### AWS Services Managed
- **API Gateway**: HTTP API management and routing
- **Lambda**: Serverless functions (router)
- **ECS**: Container orchestration (backend API, worker)
- **S3**: Object storage (videos, PDFs, static assets)
- **CloudFront**: CDN for frontend distribution
- **RDS**: Database (if needed for caching)
- **ElastiCache**: Redis caching layer
- **CloudWatch**: Monitoring and logging
- **IAM**: Identity and access management
- **VPC**: Network isolation and security

### Terraform Modules

#### API Gateway Module
```hcl
module "api_gateway" {
  source = "./modules/api-gateway"
  
  environment = var.environment
  lambda_function_arn = module.lambda_router.function_arn
  domain_name = var.api_domain_name
  certificate_arn = var.ssl_certificate_arn
  
  cors_configuration = {
    allow_origins = ["https://${var.frontend_domain}"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
  }
}
```

#### ECS Module
```hcl
module "ecs_cluster" {
  source = "./modules/ecs"
  
  environment = var.environment
  cluster_name = "thakii-${var.environment}"
  
  services = {
    backend_api = {
      image = var.backend_api_image
      port = 5001
      cpu = 1024
      memory = 2048
      desired_count = 2
    }
    worker_service = {
      image = var.worker_service_image
      cpu = 2048
      memory = 4096
      desired_count = 3
    }
  }
}
```

#### S3 Module
```hcl
module "s3_storage" {
  source = "./modules/s3"
  
  environment = var.environment
  
  buckets = {
    videos = {
      name = "thakii-videos-${var.environment}"
      versioning = true
      lifecycle_rules = [
        {
          id = "delete_old_videos"
          days = 90
          status = "Enabled"
        }
      ]
    }
    frontend = {
      name = "thakii-frontend-${var.environment}"
      website = true
      cloudfront = true
    }
  }
}
```

## 🚀 Deployment

### Prerequisites
```bash
# Install required tools
brew install terraform awscli
npm install -g @aws-cdk/cli

# Configure AWS credentials
aws configure
```

### Environment Setup
```bash
# Clone infrastructure repository
git clone https://github.com/oudaykhaled/thakii-infrastructure.git
cd thakii-infrastructure

# Setup environment
./scripts/setup-environment.sh dev
```

### Terraform Deployment
```bash
# Initialize Terraform
cd terraform/environments/dev
terraform init

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply infrastructure
terraform apply -var-file="terraform.tfvars"
```

### Complete System Deployment
```bash
# Deploy all components
./scripts/deploy-all.sh --environment=production

# Deploy specific service
./scripts/deploy-service.sh --service=backend-api --environment=staging
```

## 🔄 CI/CD Pipelines

### GitHub Actions Workflows

#### Frontend Deployment
```yaml
name: Deploy Frontend
on:
  push:
    branches: [main]
    paths: ['frontend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Build Frontend
        run: |
          cd frontend
          npm ci
          npm run build
      
      - name: Deploy to S3
        run: |
          aws s3 sync frontend/dist/ s3://${{ secrets.FRONTEND_BUCKET }}
          aws cloudfront create-invalidation --distribution-id ${{ secrets.CLOUDFRONT_ID }} --paths "/*"
```

#### Backend API Deployment
```yaml
name: Deploy Backend API
on:
  push:
    branches: [main]
    paths: ['backend-api/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and Push Docker Image
        run: |
          docker build -t thakii-backend-api:${{ github.sha }} backend-api/
          docker tag thakii-backend-api:${{ github.sha }} ${{ secrets.ECR_REGISTRY }}/thakii-backend-api:${{ github.sha }}
          docker push ${{ secrets.ECR_REGISTRY }}/thakii-backend-api:${{ github.sha }}
      
      - name: Update ECS Service
        run: |
          aws ecs update-service \
            --cluster thakii-production \
            --service backend-api \
            --force-new-deployment
```

### Deployment Strategies
- **Blue-Green Deployment**: Zero-downtime deployments
- **Rolling Updates**: Gradual service updates
- **Canary Releases**: Test with subset of traffic
- **Feature Flags**: Toggle features without deployment

## 📊 Monitoring & Alerting

### CloudWatch Dashboards
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Duration", "FunctionName", "thakii-router"],
          ["AWS/Lambda", "Errors", "FunctionName", "thakii-router"],
          ["AWS/ECS", "CPUUtilization", "ServiceName", "backend-api"],
          ["AWS/ECS", "MemoryUtilization", "ServiceName", "worker-service"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-2",
        "title": "Thakii Service Metrics"
      }
    }
  ]
}
```

### Alert Configuration
```hcl
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "thakii-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = "thakii-router"
  }
}
```

## 🔒 Security Configuration

### IAM Roles and Policies
```hcl
# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "thakii-ecs-task-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# S3 Access Policy
resource "aws_iam_policy" "s3_access" {
  name        = "thakii-s3-access-${var.environment}"
  description = "Policy for S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.videos.arn}/*",
          "${aws_s3_bucket.pdfs.arn}/*"
        ]
      }
    ]
  })
}
```

### Network Security
```hcl
# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "thakii-ecs-tasks-${var.environment}"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## 💰 Cost Management

### Resource Tagging
```hcl
locals {
  common_tags = {
    Project     = "thakii"
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Terraform   = "true"
  }
}

resource "aws_s3_bucket" "videos" {
  bucket = "thakii-videos-${var.environment}"
  tags   = local.common_tags
}
```

### Cost Optimization
- **S3 Lifecycle Policies**: Automatic data archiving
- **ECS Auto Scaling**: Scale based on demand
- **Spot Instances**: Use for non-critical workloads
- **Reserved Instances**: For predictable workloads

## 🧪 Testing Infrastructure

### Terraform Testing
```bash
# Validate Terraform configuration
terraform validate

# Security scanning
tfsec .

# Cost estimation
terraform plan -out=plan.out
terraform show -json plan.out | jq > plan.json
infracost breakdown --path plan.json
```

### Environment Testing
```bash
# Test deployment
./scripts/test-deployment.sh --environment=staging

# Load testing
./scripts/load-test.sh --target=https://api-staging.thakii.com
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-infrastructure`
3. Make infrastructure changes
4. Test in development environment
5. Submit pull request with infrastructure plan

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Related Repositories

- [thakii-frontend](https://github.com/oudaykhaled/thakii-frontend) - React web application
- [thakii-backend-api](https://github.com/oudaykhaled/thakii-backend-api) - Backend REST API
- [thakii-worker-service](https://github.com/oudaykhaled/thakii-worker-service) - Background processing
- [thakii-lambda-router](https://github.com/oudaykhaled/thakii-lambda-router) - Load balancer
