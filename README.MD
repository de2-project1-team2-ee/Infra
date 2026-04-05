https://app.diagrams.net/#Hsilver-ring-data%2FBootcamp_Study%2Fmain%2FK8S%2Finfra.drawio#%7B%22pageId%22%3A%22Mu30gTYnqA34-WPC4D4Z%22%7D
# [1]. 01_cloudformation_network_infra.yml
### 역할 : VPC, 서브넷, NAT, IGW, Route Tables 생성

0. cloudformation에서 스택 생성
  $\color{red}{\text{- 이름 생성시 이름 : nat-stack}}$ (임시로 사용, 명명규칙 바꿔야함)
1. Service Name 입력
2. team Number 입력

<img width="1889" height="401" alt="Image" src="https://github.com/user-attachments/assets/1ece3b4a-f98a-42d8-8cbd-d2684f2ce4fa" />

(이후 아래는 필요하다면 변경 CIDR 관련 파라미터들)

# [2]. 02_noaccess-role-bastion-EC2.yml
### 역할 : Bastion 서버, 보안 그룹, IAM 역할, 자동 도구 설치 (툴 자동 설치로 시간 좀 걸려요)
### 1번파일에서 만든 vpc id와 public subnet A를 자동으로 매칭해서 만들어줌

0. cloudformation에서 스택 생성
$\color{red}{\text{1. Service Name (1번 파일로 만든 것이랑 동일해야 함)}}$

$\color{red}{\text{2. Team Number (1번 파일로 만든 것이랑 동일해야 함)}}$

3. key pair 선택
(이후 아래는 필요하다면 변경)

### 자동 설치되는 툴
- kubectl
- helm, eksctl
- aws cli

* 권한 관련 
1단계 방어: 보안 그룹 (내 IP만 허용)
2단계 방어: 키페어 (파일 소유자만 접속)
3단계 방어: IAM 최소 권한 

  - AdministratorAccess -> 최소 권한 4개로 변경
  - 파라미터로 넣는 방법은 권장되지 않음
# [3]. 03_create_eks.sh
### 역할 : 각종 환경변수 저장 및 클러스터 생성
0. vi 03_create_eks.sh
1. 내용 복붙 + esc + :wq (저장)
2. chmod +x 03_create_eks.sh 입력 후 권한 생성
3. ./03_create_eks.sh 실행

* 참고 : 1번 스택이름을 자동화하려면 수정 필요. 일단은 nat-stack으로 생성하는 것으로 가정하고 진행 
  - 태그를 안쓰는 이유는 안정성때문 (이라고합니다)
  - 후에 클러스터 명명을 개발팀 공유 클러스터 / 마케팅 공유 클러스터 이런식으로 만들어야함. : 현재는 팀마다 개발1팀개발2팀 각각 클러스터 사용 (단점 : 비용)



# [4]. 04_setup_autoscaling_tools.txt + env_config.txt
### 역할 : 카펜터, 매트릭서버 설치

0. env_config 생성
1. source env_config.sh로 실행하여 써야하는 변수 저장
2. 04_setup_autoscaling_tools.txt 내용 복붙
3. ./04_setup_autoscaling_tools.sh 실행
4. ***리전 지역 직접 입력***

* 참고 : 해당 클러스터의 index 0인 노드그룹에게만 권한 할당 혹시 모든 노드 그룹에게 할당하려면 아래로 바꾸어야 함 -> 이건 테스트를 아직 안해봐서 수정은 안할게요
```bash
#!/bin/bash
<변경전>
AUTO_NODEGROUP_NAME=$(aws eks list-nodegroups ... query "nodegroups[0]")
<변경후>
NODEGROUP_LIST=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION} --query "nodegroups" --output text)

for NG in $NODEGROUP_LIST; do
    ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name $NG --region ${AWS_REGION} --query "nodegroup.nodeRole" --output text)
    ROLE_NAME=$(echo $ROLE_ARN | cut -d'/' -f2)
    
    echo "🔑 Injecting policy to: $NG ($ROLE_NAME)"
    aws iam put-role-policy --role-name ${ROLE_NAME} --policy-name KarpenterControllerPolicy --policy-document '{...}' 
done
```
보안 그룹 4443 포트 개방

# [5]. 05_create_namespaces.sh 
### 역할 : 네임스페이스 생성

(0. env_config 생성) 했다고 가정
1. 06_create_namespaces.sh 내용 복붙
2. 실행
3. 확인
```bash
#!/bin/bash
[ec2-user@develop-team-1-bastion ~]$ kubectl get ns --show-labels
NAME              STATUS   AGE    LABELS
default           Active   3h2m   kubernetes.io/metadata.name=default
dev               Active   53s    env=dev,karpenter.sh/discovery=develop-team-1-cluster,kubernetes.io/metadata.name=dev,service=develop,team=team-1
karpenter         Active   152m   kubernetes.io/metadata.name=karpenter,name=karpenter
kube-node-lease   Active   3h2m   kubernetes.io/metadata.name=kube-node-lease
kube-public       Active   3h2m   kubernetes.io/metadata.name=kube-public
kube-system       Active   3h2m   kubernetes.io/metadata.name=kube-system
monitoring        Active   53s    env=infra,kubernetes.io/metadata.name=monitoring,service=kubernetes-infra,team=admin
prod              Active   53s    env=prod,kubernetes.io/metadata.name=prod,service=develop,team=team-1
stg               Active   53s    env=stg,kubernetes.io/metadata.name=stg,service=develop,team=team-1
done
```
* 참고 : 
구성은 dev(개발용), prod(테스트용), stg(서비스) + monitoring(모니터링) 
  - 모니터링에 대하여
    - (Prometheus(데이터 수집), Grafana(그래프 시각화), Kubecost(비용 분석)을 넣어서 모니터링용만
    - 목적 : 서비스 방(dev, prod)과 섞이지 않게 관리해야 인프라가 훨씬 깔끔하다고 합니다.
yaml파일을 따로 빼서 관리하는것이 좋지만 지금은 소규모 작업이라 일단은 편하게 sh에 다 넣어놨습니다. -> 앞 파일에서도 그렇고 추후 필요하면 분리 필요

# [6]. 06._rds_setup.sh
### 역할 : RDS 세팅

(0. env_config 생성) 했다고 가정
1. 06_create_namespaces.sh 내용 복붙
2. 실행 (10분~15분 걸려요)
3. 확인 

* 참고 : 
 - --multi-az로 AWS에서 친절하게 이중화 및 관리/연결을 해준다고 합니다. 복제 개념인거 같은데
 - 초기 개발 기간에는 베스천 서버랑 연결이 되어 있어야 개발작업이 진행이 되기 때문에 나중에는 보안그룹에서 연결을 끊어줘야해요. 지금은 연결되어 있습니다.
 - 같은 서비스 다른 팀일 경우 (develop-team-1, develop-team-2)
    - create-db-instance 로직은 건너뛰되, 아래 두 가지 보안 그룹 설정 필요
      - 다른 팀이 만든 RDS의 보안 그룹에 해당 팀의 EKS 노드 보안 그룹 ID/배스천 보안 그룹 ID를 'Inbound 규칙'으로 추가

# [7]. 07_depoly_app.txt (개발중)
### 역할 : ALB 컨트롤러 설치 + 웹 앱 배포 + 사이드카 로그 수집 + 로드밸런서(ALB) 연결

* 참고 : 
로그 (현재 아키텍처는 사이드카가 공유 볼륨에서 로그를 읽어들이는 단계까지 구현되어 있으며, 최종 단계에서는 Fluent Bit 같은 에이전트를 통해 CloudWatch 엔드포인트로 로그를 전송해야함) 

# [기타고려사항]
- 모듈식으로 만든 이 파일들을 일괄적으로 돌려서, 로직에 따라 일부 모듈은 실행하지 않도록 (db를 생성하지 않는다거나) 만들어야함
