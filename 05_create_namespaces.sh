# 1. 파일 생성 (cat 사용) [cite: 2026-02-14]
cat << 'EOF' > 05_create_namespaces.sh
#!/bin/bash

# 환경 변수 체크 로직 [cite: 2026-01-23]
source ./env_config.sh || exit 1

echo "--------------------------------------------------------"
echo "🏗️ Creating Namespaces for $SERVICE_NAME (Team $TEAM_NUMBER)"
echo "--------------------------------------------------------"

# 템플릿 생성 [cite: 2026-02-14]
cat << 'INNER_EOF' > 05_create_namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    service: ${SERVICE_NAME}
    team: team-${TEAM_NUMBER}
    env: dev
    karpenter.sh/discovery: ${CLUSTER_NAME}
---
apiVersion: v1
kind: Namespace
metadata:
  name: stg
  labels:
    service: ${SERVICE_NAME}
    team: team-${TEAM_NUMBER}
    env: stg
---
apiVersion: v1
kind: Namespace
metadata:
  name: prod
  labels:
    service: ${SERVICE_NAME}
    team: team-${TEAM_NUMBER}
    env: prod
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    service: kubernetes-infra
    team: admin
    env: infra
INNER_EOF

# 배포 [cite: 2026-02-14]
envsubst < 05_create_namespaces.yaml | kubectl apply -f -

echo "✅ Namespaces created successfully:"
kubectl get ns -l service=${SERVICE_NAME} --show-labels
kubectl get ns monitoring --show-labels
EOF

chmod +x 05_create_namespaces.sh
./05_create_namespaces.sh
