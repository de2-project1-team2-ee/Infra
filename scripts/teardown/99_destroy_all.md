# 리소스 삭제 확인 절차

`99_destroy_all.txt`를 실행한 뒤, 아래 항목을 순서대로 확인한다.
스크립트가 놓친 리소스가 남아 있으면 과금이 계속되므로 콘솔 확인까지 반드시 수행한다.

## 1. 배스천 호스트에서 확인 (명령어)

클러스터가 삭제되었는지 확인한다.

```bash
# 아무것도 출력되지 않거나 'No clusters found'가 나와야 정상이다.
eksctl get cluster --region $AWS_REGION
```

CloudFormation 콘솔에서 cluster 관련 스택이 삭제되었는지도 함께 확인한다.
(클러스터 스택은 가장 늦게 삭제되는 편이다.)

쿠버네티스 연결이 끊겼는지 확인한다.

```bash
# 'The connection to the server was refused' 오류가 나오면 정상이다. (API 서버가 삭제된 상태)
kubectl get nodes
```

## 2. AWS 콘솔에서 수동 확인 (필수)

명령어로는 회수되지 않는 리소스가 남을 수 있다. 아래 메뉴를 직접 확인한다.

| 메뉴 | 확인 내용 |
| --- | --- |
| EC2 > 인스턴스 | 배스천(`<서비스명>-team-<번호>-bastion`) 외 모든 인스턴스가 Terminated 상태여야 한다. |
| EC2 > 볼륨 (EBS) | `Available` 상태로 남은 10~20GB 볼륨이 있으면 삭제한다. 파드가 사라져도 PV가 남아 과금되는 대표 사례이다. |
| EC2 > 로드밸런서 (ALB) | `k8s-kubecost`, `k8s-dev`로 시작하는 로드밸런서가 남아 있으면 삭제한다. |
| EC2 > 탄력적 IP | NAT 게이트웨이가 삭제된 뒤 미할당 상태로 남은 EIP가 있으면 해제한다. |
| RDS > 데이터베이스 | `<서비스명>-db` 인스턴스가 목록에서 사라졌는지 확인한다. |
| CloudFormation | 네트워크/배스천 스택까지 모두 DELETE_COMPLETE 인지 확인한다. |
