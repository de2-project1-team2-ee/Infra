#!/bin/bash

# 1. 변수 자동 추출 [cite: 2026-04-04]
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
export CLUSTER_NAME=$(eksctl get cluster --region $AWS_REGION -o json | jq -r '.[0].Name')
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "--------------------------------------------------------"
echo "🚀 Starting Full Setup (IAM + Karpenter)"
echo "📍 Cluster: $CLUSTER_NAME / Region: $AWS_REGION"
echo "--------------------------------------------------------"

# 2.  Karpenter용 IAM Role 및 ServiceAccount 생성 [cite: 2026-04-04]
echo "🔑 Creating IAM Service Account and Role..."
eksctl create iamserviceaccount \
  --cluster="${CLUSTER_NAME}" --region="${AWS_REGION}" \
  --name=karpenter --namespace=kube-system \
  --role-name="${CLUSTER_NAME}-karpenter-role" \
  --attach-policy-arn="arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" \
  --attach-policy-arn="arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" \
  --attach-policy-arn="arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" \
  --attach-policy-arn="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" \
  --approve --override-existing-serviceaccounts

# 3. Metrics Server 설치 [cite: 2026-04-04]
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 4. Karpenter 설치 (이제 생성된 Role 이름을 정확히 연결!)
echo "⚙️  Installing Karpenter Engine..."
helm upgrade --install karpenter karpenter/karpenter \
  --namespace kube-system \
  --create-namespace \
  --set settings.aws.clusterName="${CLUSTER_NAME}" \
  --set settings.aws.defaultInstanceProfile="${CLUSTER_NAME}-karpenter-role" \
  --set settings.aws.region="${AWS_REGION}" \
  --timeout 10m --wait

echo "--------------------------------------------------------"
echo "✅ Everything is set! IAM Role created and Karpenter installed."
echo "--------------------------------------------------------"
