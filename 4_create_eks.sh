#!/bin/bash

# --------------------------------------------------------
# 0. 사용자 설정 (은비나 팀원들이 수정할 부분) [cite: 2026-02-14]
# --------------------------------------------------------
export SERVICE_NAME="lostark"
export TEAM_NUMBER="1"

# 1번 네트워크 스택 이름 자동 생성 규칙
export NET_STACK_NAME="${SERVICE_NAME}-team-${TEAM_NUMBER}-network"

echo "--------------------------------------------------------"
echo "🚀 Starting EKS Automation for ${SERVICE_NAME} Team ${TEAM_NUMBER}"
echo "--------------------------------------------------------"

# --------------------------------------------------------
# 1. 정보 자동 추출 (CloudFormation & Metadata)
# --------------------------------------------------------
export AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
export MY_VPC_ID=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='VPCID'].OutputValue" --output text)

# 정확히 'App' 용도의 프라이빗 서브넷만 추출
export APP_PRI_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='AppSubnetA'].OutputValue" --output text)
export APP_PRI_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='AppSubnetB'].OutputValue" --output text)

# 퍼블릭 서브넷 추출 (ALB 배치용)
export PUB_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PubSubnetA'].OutputValue" --output text)
export PUB_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PubSubnetB'].OutputValue" --output text)

# 데이터 추출 검증 [cite: 2026-01-23]
if [ "$MY_VPC_ID" == "None" ] || [ -z "$MY_VPC_ID" ]; then
    echo "❌ Error: Could not find Network Stack: $NET_STACK_NAME"
    echo "Please check if Stack 1 is deployed with the correct name."
    exit 1
fi

echo "✅ Network Data Captured: VPC($MY_VPC_ID) in $AWS_REGION"
echo "✅ App Subnets: $APP_PRI_SUBNET_A, $APP_PRI_SUBNET_B"

# --------------------------------------------------------
# 2. YAML 변수 치환 및 EKS 생성
# --------------------------------------------------------
echo "🛠️  Generating finalized-cluster.yaml..."
envsubst < cluster.yaml > finalized-cluster.yaml

echo "🏗️  Executing eksctl create cluster..."
eksctl create cluster -f finalized-cluster.yaml

# chmod +x create-eks.sh  # 실행 권한 부여
# ./create-eks.sh         # 스크립트 실행!
