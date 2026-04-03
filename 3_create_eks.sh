#!/bin/bash

# --------------------------------------------------------
# 0. 임시 설정 (이름을 nat_stack으로 고정!) [cite: 2026-02-14]
# --------------------------------------------------------
export NET_STACK_NAME="nat-stack"

echo "--------------------------------------------------------"
echo "🔍 Fetching Infrastructure Data from: $NET_STACK_NAME"
echo "--------------------------------------------------------"

# --------------------------------------------------------
# 1. 정보 자동 추출 (1번 스택 Outputs 기준)
# --------------------------------------------------------
# 1-1. 서비스 및 팀 정보 추출
export SERVICE_NAME=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportServiceName'].OutputValue" --output text)
export TEAM_NUMBER=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportTeamNumber'].OutputValue" --output text)

# 1-2. VPC 및 서브넷 정보 추출
export MY_VPC_ID=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportVpcId'].OutputValue" --output text)
export PUB_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportPublicSubnetA'].OutputValue" --output text)
export PUB_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportPublicSubnetB'].OutputValue" --output text)
export APP_PRI_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportAppSubnetA'].OutputValue" --output text)
export APP_PRI_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportAppSubnetB'].OutputValue" --output text)

# 1-3. 리전 정보 추출
export AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# 데이터 추출 검증 [cite: 2026-01-23]
if [ "$MY_VPC_ID" == "None" ] || [ -z "$MY_VPC_ID" ]; then
    echo "❌ Error: 스택 정보를 가져오지 못했습니다. 1번 스택 이름이 'nat_stack'인지 확인하세요."
    exit 1
fi

echo "✅ Target: $SERVICE_NAME Team $TEAM_NUMBER"
echo "✅ VPC ID: $MY_VPC_ID"
echo "✅ Subnets Loaded: Pub($PUB_SUBNET_A, $PUB_SUBNET_B), App($APP_PRI_SUBNET_A, $APP_PRI_SUBNET_B)"

# --------------------------------------------------------
# 2. cluster.yaml 생성 (cat 실행 시점에 변수 값이 즉시 주입됨) [cite: 2026-04-03]
# --------------------------------------------------------
cat << EOF > cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${SERVICE_NAME}-team-${TEAM_NUMBER}-cluster
  region: ${AWS_REGION}
  version: "1.31"

vpc:
  id: ${MY_VPC_ID}
  subnets:
    public:
      - id: ${PUB_SUBNET_A}
      - id: ${PUB_SUBNET_B}
    private:
      - id: ${APP_PRI_SUBNET_A}
      - id: ${APP_PRI_SUBNET_B}

managedNodeGroups:
  - name: m7i-flex-large-nodes
    instanceType: m7i-flex.large
    desiredCapacity: 2
    volumeSize: 20
    privateNetworking: true
    iam:
      withAddonPolicies:
        imageBuilder: true
        albIngress: true
        cloudWatch: true
        autoScaler: true

cloudWatch:
  clusterLogging:
    enableTypes: ["*"]
EOF

# --------------------------------------------------------
# 3. EKS 생성 실행
# --------------------------------------------------------
echo "🏗️  Executing eksctl create cluster... (약 15~20분 소요)"
eksctl create cluster -f cluster.yaml
