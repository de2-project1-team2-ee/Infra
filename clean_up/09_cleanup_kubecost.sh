cat << 'EOF' > 09_cleanup_kubecost.sh
#!/bin/bash
source ./env_config.sh || exit 1

echo "--------------------------------------------------------"
echo "🗑️  [Step 1] 리소스 강제 삭제 (Finalizer 제거)"
echo "--------------------------------------------------------"

# 1. Ingress 강제 삭제
kubectl patch ingress kubecost-ingress -n kubecost -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null

# 2. Namespace 강제 삭제 (꼬리표 제거)
kubectl patch namespace kubecost -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null

# 3. Helm 삭제
helm uninstall kubecost -n kubecost 2>/dev/null

echo "--------------------------------------------------------"
echo "🗑️  [Step 2] EKS Addon 및 IAM ServiceAccount 삭제"
echo "--------------------------------------------------------"

# 4. EBS CSI Addon 삭제
eksctl delete addon --name aws-ebs-csi-driver --cluster $CLUSTER_NAME --region $AWS_REGION

# 5. iamserviceaccount 삭제
eksctl delete iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --wait

echo "--------------------------------------------------------"
echo "✅ 삭제 완료 확인 중..."
kubectl get ns kubecost
echo "--------------------------------------------------------"
echo "💡 이제 08_install_kubecost.sh를 다시 실행해도 좋아!"
EOF

chmod +x 09_cleanup_kubecost.sh
./09_cleanup_kubecost.sh
