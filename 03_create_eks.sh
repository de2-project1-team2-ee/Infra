cat << 'EOF' > 03_create_eks.sh
#!/bin/bash

# --------------------------------------------------------
# 0. 환경 변수 로드 및 검증 (Idempotent Loader 활용) [cite: 2026-04-05]
# --------------------------------------------------------
# env_config.sh가 없거나 실행에 실패하면 즉시 종료 [cite: 2026-04-05]
source ./env_config.sh || exit 1

echo "--------------------------------------------------------"
echo "🚀 EKS Cluster Deployment Start"
echo "📦 Cluster Name: $CLUSTER_NAME"
echo "🏢 VPC ID: $VPC_ID"
echo "📍 Region: $INPUT_REGION"
echo "--------------------------------------------------------"

# --------------------------------------------------------
# 1. cluster.yaml Generation (EKS Version 1.34) [cite: 2026-04-03]
# --------------------------------------------------------
cat << INNER_EOF > cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${INPUT_REGION}
  version: "1.34"

vpc:
  id: ${VPC_ID}
  subnets:
    public:
      ${INPUT_REGION}a:
        id: ${PUB_SUBNET_A}
      ${INPUT_REGION}b:
        id: ${PUB_SUBNET_B}
    private:
      ${INPUT_REGION}a:
        id: ${APP_SUBNET_1}
      ${INPUT_REGION}b:
        id: ${APP_SUBNET_2}

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
INNER_EOF

# --------------------------------------------------------
# 2. Execute EKS Creation [cite: 2026-04-05]
# --------------------------------------------------------
echo "🏗️  Executing eksctl create cluster... (Takes approx. 15-20 mins)"
eksctl create cluster -f cluster.yaml
EOF

chmod +x 03_create_eks.sh
./03_create_eks.sh
