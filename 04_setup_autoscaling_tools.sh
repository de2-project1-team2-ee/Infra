#!/bin/bash

# 1. 변수 추출 (IMDSv2 방식 - 가장 확실함) [cite: 2026-04-04]
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
export CLUSTER_NAME=$(eksctl get cluster --region $AWS_REGION -o json | jq -r '.[0].Name')

echo "--------------------------------------------------------"
echo "🔍 Environment Check"
echo "🌐 Detected Region: $AWS_REGION"
echo "🏗️  Detected Cluster: $CLUSTER_NAME"
echo "--------------------------------------------------------"

# 2. 기존에 꼬인 Karpenter 완전히 삭제 (중요: 깨끗한 상태에서 시작) [cite: 2026-04-04]
helm uninstall karpenter -n kube-system 2>/dev/null

# 3. Metrics Server 설치 [cite: 2026-04-04]
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 4. Karpenter 설치 (변수 주입 시 따옴표를 더 확실하게!)
# --wait 대신 --timeout을 늘려서 끝까지 성공하게 함 [cite: 2026-04-04]
helm upgrade --install karpenter karpenter/karpenter \
  --namespace kube-system \
  --create-namespace \
  --set settings.aws.clusterName="${CLUSTER_NAME}" \
  --set settings.aws.defaultInstanceProfile="${CLUSTER_NAME}-karpenter-role" \
  --set settings.aws.region="${AWS_REGION}" \
  --timeout 10m \
  --wait

echo "--------------------------------------------------------"
echo "✅ Fixed Installation Complete!"
echo "--------------------------------------------------------"
