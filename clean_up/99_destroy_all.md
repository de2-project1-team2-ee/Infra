1. 배스천 호스트에서 확인 (명령어)
먼저 우리 조종실에서 클러스터의 흔적이 지워졌는지 확인하는 단계야.

클러스터 존재 여부 확인:

```
Bash
# 아무것도 안 뜨거나 'No clusters found'가 나와야 해.
eksctl get cluster --region $AWS_REGION
```

쿠버네티스 연결 끊김 확인:
```
Bash
# 'The connection to the server was refused' 에러가 나면 정상이야. (서버가 죽었으니까!)
kubectl get nodes
```


2. AWS 콘솔에서 '수동' 확인 (가장 중요!)
은비야, 명령어가 놓치는 **'유령 리소스'**들이 있을 수 있어. 콘솔에서 아래 메뉴들을 꼭 들어가 봐.

EC2 > 인스턴스:
eunbee-team-1-bastion 외에는 모두 Terminated 상태여야 해.

EC2 > 볼륨 (EBS):
이게 핵심이야! Available 상태로 남은 10GB~20GB짜리 볼륨이 있다면 무조건 선택해서 [볼륨 삭제] 해줘.

EC2 > 로드밸런서 (ALB):
k8s-kubecost나 k8s-dev로 시작하는 이름이 없는지 확인해. 있으면 수동 삭제!

RDS > 데이터베이스:
eunbee-team-1-db가 리스트에서 사라졌는지 확인해.
