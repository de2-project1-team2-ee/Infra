#!/bin/bash

# --------------------------------------------------------
# 0. Temporary Setup (Stack name fixed as nat-stack) [cite: 2026-04-03]
# --------------------------------------------------------
export NET_STACK_NAME="nat-stack"

echo "--------------------------------------------------------"
echo "🔍 Fetching Infrastructure Data from: $NET_STACK_NAME"
echo "--------------------------------------------------------"

# --------------------------------------------------------
# 1. Automatic Information Extraction
# --------------------------------------------------------
export SERVICE_NAME=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportServiceName'].OutputValue" --output text)
export TEAM_NUMBER=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportTeamNumber'].OutputValue" --output text)

export MY_VPC_ID=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportVpcId'].OutputValue" --output text)
export PUB_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportPublicSubnetA'].OutputValue" --output text)
export PUB_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportPublicSubnetB'].OutputValue" --output text)
export APP_PRI_SUBNET_A=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportAppSubnetA'].OutputValue" --output text)
export APP_PRI_SUBNET_B=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportAppSubnetB'].OutputValue" --output text)

export AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# Validation [cite: 2026-01-23]
if [ "$MY_VPC_ID" == "None" ] || [ -z "$MY_VPC_ID" ]; then
    echo "❌ Error: Failed to fetch stack data. Please check if '$NET_STACK_NAME' exists."
    exit 1
fi

echo "✅ Target: $SERVICE_NAME Team $TEAM_NUMBER"

# --------------------------------------------------------
# 2. cluster.yaml Generation (EKS Version 1.34) [cite: 2026-04-03]
# --------------------------------------------------------
cat << EOF > cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${SERVICE_NAME}-team-${TEAM_NUMBER}-cluster
  region: ${AWS_REGION}
  version: "1.34"

vpc:
  id: ${MY_VPC_ID}
  subnets:
    public:
      # 리전 변수 뒤에 a, b만 붙여서 동적으로 처리해 [cite: 2026-04-04]
      ${AWS_REGION}a:
        id: ${PUB_SUBNET_A}
      ${AWS_REGION}b:
        id: ${PUB_SUBNET_B}
    private:
      ${AWS_REGION}a:
        id: ${APP_PRI_SUBNET_A}
      ${AWS_REGION}b:
        id: ${APP_PRI_SUBNET_B}

managedNodeGroups:
  - name: m7i-flex-large-nodes-nodegroup
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
# 3. Execute EKS Creation
# --------------------------------------------------------
echo "🏗️  Executing eksctl create cluster... (Takes approx. 15-20 mins)"
eksctl create cluster -f cluster.yaml
