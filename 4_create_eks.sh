#!/bin/bash

# --------------------------------------------------------
# 0. 사용자 설정 (이 스택 이름만 정확하면 끝!) [cite: 2026-02-14]
# --------------------------------------------------------
export NET_STACK_NAME="${SERVICE_NAME}-team-${TEAM_NUMBER}-network"

echo "--------------------------------------------------------"
echo "🔍 Fetching Infrastructure Data from: $NET_STACK_NAME"
echo "--------------------------------------------------------"

# --------------------------------------------------------
# 1. 정보 자동 추출 (은비가 설계한 OutputKey 기준)
# --------------------------------------------------------

# 1-1. 서비스 정보 (Outputs에서 순수 값만 추출)
export SERVICE_NAME=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportServiceName'].OutputValue" --output text)
export TEAM_NUMBER=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportTeamNumber'].OutputValue" --output text)

# 1-2. 네트워크 정보 (Export 명칭 기준)
export MY_VPC_ID=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportVpcId'].OutputValue" --output text)
export PUB_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportPublicSubnetA'].OutputValue" --output text)
export PUB_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportPublicSubnetB'].OutputValue" --output text)
export APP_PRI_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportAppSubnetA'].OutputValue" --output text)
export APP_PRI_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportAppSubnetB'].OutputValue" --output text)

# 1-3. 리전 정보 자동 추출
export AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# 데이터 추출 검증 (VPC ID가 없으면 중단) [cite: 2026-01-23]
if [ "$MY_VPC_ID" == "None" ] || [ -z "$MY_VPC_ID" ]; then
    echo "❌ Error: Could not find Network Stack: $NET_STACK_NAME"
    exit 1
fi

echo "✅ Target Service: $SERVICE_NAME (Team $TEAM_NUMBER)"
echo "✅ Region: $AWS_REGION"
echo "✅ VPC: $MY_VPC_ID"
echo "✅ Subnets: Pub($PUB_SUBNET_A), App($APP_PRI_SUBNET_A)"

# --------------------------------------------------------
# 2. YAML 변수 치환 및 EKS 생성
# --------------------------------------------------------
echo "🛠️  Generating finalized-cluster.yaml..."
envsubst < cluster.yaml > finalized-cluster.yaml

echo "🏗️  Executing eksctl create cluster... (Takes 15-20 mins)"
eksctl create cluster -f finalized-cluster.yaml
