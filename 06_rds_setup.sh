cat << 'EOF' > 06.rds_setup.sh
#!/bin/bash

# 1. 공통 환경 변수 로드 (VPC, ClusterName 등) [cite: 2026-04-04]
source ./env_config.sh || exit 1

echo "--------------------------------------------------------"
echo "🔍 [Step 1] 실시간 인프라 자원 검색 (Live Fetching)"
echo "--------------------------------------------------------"

NODE_SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=tag:alpha.eksctl.io/cluster-name,Values=$CLUSTER_NAME \
  Name=group-name,Values="*ClusterSharedNodeSecurityGroup*" \
  --query "SecurityGroups[0].GroupId" --output text)

if [ "$NODE_SG_ID" == "None" ] || [ -z "$NODE_SG_ID" ]; then
    echo "❌ [Error] EKS 노드 보안 그룹을 찾을 수 없습니다."
    exit 1
fi

echo "✅ 탐색 성공: Node SG ($NODE_SG_ID)"

echo "--------------------------------------------------------"
echo "💎 [Step 2] RDS 리소스 프로비저닝"
echo "--------------------------------------------------------"

# 서브넷 그룹 (이미 만들어졌으니 에러 메시지 무시용 2>/dev/null) [cite: 2026-04-04]
aws rds create-db-subnet-group \
    --db-subnet-group-name ${SERVICE_NAME}-rds-sng \
    --db-subnet-group-description "Subnet group for ${SERVICE_NAME} RDS" \
    --subnet-ids "$DB_SUBNET_1" "$DB_SUBNET_2" 2>/dev/null || echo "ℹ️ Subnet Group already exists."

# 1. RDS 보안 그룹 생성 (이미 존재하면 ID만 가져옴) [cite: 2026-04-04]
RDS_SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=${SERVICE_NAME}-rds-sg --query "SecurityGroups[0].GroupId" --output text)

if [ "$RDS_SG_ID" == "None" ] || [ -z "$RDS_SG_ID" ]; then
    RDS_SG_ID=$(aws ec2 create-security-group \
        --group-name ${SERVICE_NAME}-rds-sg \
        --description "Security group for ${SERVICE_NAME} RDS" \
        --vpc-id $VPC_ID --output text --query 'GroupId')
fi

# 2. EKS 노드 그룹 보안 그룹 허용 (기존 로직) [cite: 2026-04-04]
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 3306 \
    --source-group $NODE_SG_ID 2>/dev/null || echo "ℹ️ Node SG rule already exists."

# 3. [추가] 배스천 호스트 보안 그룹 허용 (임시 오픈) [cite: 2026-04-04]
BASTION_SG_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values="*bastion-sg*" \
    --query "SecurityGroups[0].GroupId" --output text)

if [ "$BASTION_SG_ID" != "None" ]; then
    aws ec2 authorize-security-group-ingress \
        --group-id $RDS_SG_ID \
        --protocol tcp \
        --port 3306 \
        --source-group $BASTION_SG_ID 2>/dev/null || echo "ℹ️ Bastion SG rule already exists."
    echo "✅ 보안 설정 완료: Node SG($NODE_SG_ID) & Bastion SG($BASTION_SG_ID)"
fi

echo "✅ 보안 그룹 준비 완료: $RDS_SG_ID"

# RDS 인스턴스 생성 (옵션명 수정: --no-publicly-accessible) [cite: 2026-04-04]
aws rds create-db-instance \
    --db-instance-identifier ${SERVICE_NAME}-db \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username admin \
    --master-user-password "Password123!" \
    --allocated-storage 20 \
    --db-subnet-group-name ${SERVICE_NAME}-rds-sng \
    --vpc-security-group-ids $RDS_SG_ID \
    --multi-az \
    --no-publicly-accessible \
    --db-name "${SERVICE_NAME}db"

echo "--------------------------------------------------------"
echo "🚀 RDS 생성 요청이 전달되었습니다!" (15분 정도 소요)
echo "--------------------------------------------------------"
EOF

chmod +x 06.rds_setup.sh
./06.rds_setup.sh
