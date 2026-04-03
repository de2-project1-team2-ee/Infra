# Helm을 이용한 Metrics Server + Karpenter 설치
#!/bin/bash

# 1. 기본 정보 설정 (1번 스택에서 추출)
export NET_STACK_NAME="nat-stack"
export CLUSTER_NAME=$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportServiceName'].OutputValue" --output text)-team-$(aws cloudformation describe-stacks --stack-name $NET_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ExportTeamNumber'].OutputValue" --output text)-cluster
export AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

echo "--------------------------------------------------------"
echo "🛠️  Setting up Autoscaling Tools for: $CLUSTER_NAME"
echo "🌐 Region: $AWS_REGION"
echo "--------------------------------------------------------"

# --------------------------------------------------------
# Step 3: Metrics Server 설치 (센서 장착) [cite: 2026-04-04]
# --------------------------------------------------------
echo "👀 1. Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# --------------------------------------------------------
# Step 4: Karpenter 설치 준비 (OIDC & IAM Role) [cite: 2026-04-04]
# --------------------------------------------------------
echo "🏗️  2. Configuring IAM for Karpenter..."

# OIDC 공급자 생성 (AWS IAM과 EKS 연동) [cite: 2026-04-04]
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve

# Karpenter 전용 IAM Role 및 ServiceAccount 생성 [cite: 2026-04-04]
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --name=karpenter \
  --namespace=kube-system \
  --role-name="${CLUSTER_NAME}-karpenter-role" \
  --attach-policy-arn="arn:aws:iam::aws:policy/AdministratorAccess" \
  --approve \
  --override-existing-serviceaccounts

# --------------------------------------------------------
# Karpenter 엔진 설치 (Helm 이용) [cite: 2026-04-04]
# --------------------------------------------------------
echo "🚀 3. Installing Karpenter Engine via Helm..."

# Helm 레포지토리 추가 [cite: 2026-04-04]
helm repo add karpenter https://charts.karpenter.sh/
helm repo update

# Karpenter 설치 (버전은 최신 안정판 기준) [cite: 2026-04-04]
helm upgrade --install karpenter karpenter/karpenter \
  --namespace kube-system \
  --create-namespace \
  --set serviceAccount.create=false \
  --set serviceAccount.name=karpenter \
  --set settings.aws.clusterName=$CLUSTER_NAME \
  --set settings.aws.defaultInstanceProfile="${CLUSTER_NAME}-karpenter-role" \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --wait

echo "--------------------------------------------------------"
echo "✅ Autoscaling tools installation complete!"
echo "🔍 Check status: kubectl get pods -n kube-system"
echo "--------------------------------------------------------"
