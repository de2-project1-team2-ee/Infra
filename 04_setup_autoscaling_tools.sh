# Helm을 이용한 Metrics Server + Karpenter 설치
#!/bin/bash

# 1. 기본 정보 설정 (1번 스택에서 추출)

export AWS_REGION=$(aws configure get region)
if [ ! -z "$AWS_REGION" ]; then
    export CLUSTER_NAME=$(eksctl get cluster --region $AWS_REGION -o json | jq -r '.[0].Name')
fi

# [검증 단계] 변수가 비어있는지 팩트 체크 [cite: 2026-01-23]
echo "--------------------------------------------------------"
echo "🔍 Environment Check"
echo "🌐 Detected Region: $AWS_REGION"
echo "🏗️  Detected Cluster: $CLUSTER_NAME"
echo "--------------------------------------------------------"

# 변수가 하나라도 없으면 중단 (에러 방지) [cite: 2026-04-04]
if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" == "null" ] || [ -z "$AWS_REGION" ]; then
    echo "❌ 에러: 변수를 추출하지 못했어! 'aws configure'와 클러스터 상태를 확인해 봐."
    exit 1
fi

# 3. Metrics Server 설치 [cite: 2026-04-04]
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 4. Karpenter 설치 (추출된 변수 주입)
helm upgrade --install karpenter karpenter/karpenter \
  --namespace kube-system \
  --create-namespace \
  --set settings.aws.clusterName=$CLUSTER_NAME \
  --set settings.aws.defaultInstanceProfile="${CLUSTER_NAME}-karpenter-role" \
  --set settings.aws.region=$AWS_REGION \
  --wait

echo "--------------------------------------------------------"
echo "✅ Fixed Installation Complete!"
echo "--------------------------------------------------------"
