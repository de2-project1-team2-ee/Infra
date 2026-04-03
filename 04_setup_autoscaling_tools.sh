#!/bin/bash

# 1. 환경 변수 자동 추출 (보내준 파일 2단계 로직) [cite: 2026-02-25-1]
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
export CLUSTER_NAME=$(eksctl get cluster --region $AWS_REGION -o json | jq -r '.[0].Name')
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export CLUSTER_ENDPOINT=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)

echo "--------------------------------------------------------"
echo "🌐 Cluster: $CLUSTER_NAME | Endpoint: $CLUSTER_ENDPOINT"
echo "--------------------------------------------------------"

# 2. [핵심] 기존 노드 그룹 역할에 Karpenter 권한 직접 주입 (3단계 로직) [cite: 2026-02-25-1]
# IRSA 대신 이 방식을 쓰면 'unrecognized name' 에러를 피하기 쉬워. [cite: 2026-02-25-1]
NODE_ROLE_NAME=$(aws iam list-roles --query "Roles[?contains(RoleName, 'nodegroup') && contains(RoleName, '${CLUSTER_NAME}')].RoleName" --output text)

echo "🔑 Injecting Karpenter Policy to Node Role: $NODE_ROLE_NAME"
aws iam put-role-policy --role-name ${NODE_ROLE_NAME} \
  --policy-name KarpenterControllerPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateFleet", "ec2:CreateLaunchTemplate", "ec2:CreateTags",
                "ec2:DescribeAvailabilityZones", "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeInstanceTypes", "ec2:DescribeInstances",
                "ec2:DescribeLaunchTemplates", "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets", "ec2:RunInstances", "ec2:TerminateInstances",
                "iam:PassRole", "iam:GetInstanceProfile", "iam:CreateInstanceProfile",
                "iam:TagInstanceProfile", "iam:AddRoleToInstanceProfile",
                "ssm:GetParameter", "pricing:GetProducts", "ec2:DescribeSpotPriceHistory"
            ],
            "Resource": "*"
        }
    ]
}'

# 3. 신규 노드용 IAM 역할 및 프로파일 생성 [cite: 2026-02-25-1]
aws iam create-role --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' 2>/dev/null

aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam create-instance-profile --instance-profile-name "KarpenterNodeInstanceProfile-${CLUSTER_NAME}" 2>/dev/null
aws iam add-role-to-instance-profile --instance-profile-name "KarpenterNodeInstanceProfile-${CLUSTER_NAME}" --role-name "KarpenterNodeRole-${CLUSTER_NAME}" 2>/dev/null

# 4. Discovery 태그 설정 (Karpenter가 자원을 찾기 위함) [cite: 2026-02-25-1]
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=tag:alpha.eksctl.io/cluster-name,Values=${CLUSTER_NAME}" --query 'Subnets[*].SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_IDS --tags Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}

SG_IDS=$(aws ec2 describe-security-groups --filters "Name=tag:alpha.eksctl.io/cluster-name,Values=${CLUSTER_NAME}" --query 'SecurityGroups[*].GroupId' --output text)
aws ec2 create-tags --resources $SG_IDS --tags Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}

# 5. Helm 설치 (v1.0.6) [cite: 2026-02-25-1]
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version 1.0.6 \
  --namespace karpenter --create-namespace \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.clusterEndpoint=${CLUSTER_ENDPOINT} \
  --set settings.interruptionQueueName=${CLUSTER_NAME} \
  --wait

# 6. EKS 노드 인증 등록 (Access Entry) [cite: 2026-02-25-1]
eksctl create iamidentitymapping \
  --cluster ${CLUSTER_NAME} \
  --region ${AWS_REGION} \
  --arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME} \
  --group system:bootstrappers \
  --group system:nodes \
  --username system:node:{{EC2PrivateDNSName}}

echo "✅ [Success] Karpenter 1.0.6 설치 완료!"
