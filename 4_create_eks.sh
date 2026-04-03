#!/bin/bash

# --------------------------------------------------------
# 0. 사용자 설정 (이 스택 이름만 정확하면 끝!) [cite: 2026-02-14]
# --------------------------------------------------------
export NET_STACK_NAME="${SERVICE_NAME}-team-${TEAM_NUMBER}-network"

echo "--------------------------------------------------------"
echo "🔍 Fetching Infrastructure Data from: $NET_STACK_NAME"
echo "--------------------------------------------------------"

# --------------------------------------------------------
# 1. 정보 자동 추출 (은비가 수정한 OutputKey 기준)
# --------------------------------------------------------

# 1-1. 서비스 및 팀 정보 추출
export SERVICE_NAME=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportServiceName'].OutputValue" --output text)
export TEAM_NUMBER=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportTeamNumber'].OutputValue" --output text)

# 1-2. VPC 및 서브넷 정보 추출 (OutputKey 매칭)
export MY_VPC_ID=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportVpcId'].OutputValue" --output text)

# Public Subnets (ALB용)
export PUB_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportPublicSubnetA'].OutputValue" --output text)
export PUB_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportPublicSubnetB'].OutputValue" --output text)

# App Private Subnets (EKS 노드용)
export APP_PRI_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportAppSubnetA'].OutputValue" --output text)
export APP_PRI_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportAppSubnetB'].OutputValue" --output text)

# 1-3. 리전 정보 추출
export AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# 데이터 추출 검증 [cite: 2026-01-23]
if [ "$MY_VPC_ID" == "None" ] || [ -z "$MY_VPC_ID" ]; then
    echo "❌ Error: 스택 정보를 가져오지 못했습니다. NET_STACK_NAME을 확인하세요."
    exit 1
fi

echo "✅ Target: $SERVICE_NAME Team $TEAM_NUMBER"
echo "✅ VPC ID: $MY_VPC_ID"
echo "✅ Subnets Loaded: Pub($PUB_SUBNET_A, $PUB_SUBNET_B), App($APP_PRI_SUBNET_A, $APP_PRI_SUBNET_B)"

# --------------------------------------------------------
# 2. YAML 변수 치환 및 EKS 생성
# --------------------------------------------------------
echo "🛠️  Generating finalized-cluster.yaml..."
envsubst < cluster.yaml > finalized-cluster.yaml

echo "🏗️  Executing eksctl create cluster... (약 15~20분 소요)"
eksctl create cluster -f finalized-cluster.yaml
