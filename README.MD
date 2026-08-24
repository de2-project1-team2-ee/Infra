# EKS 기반 데이터 서비스 인프라 (Team 2)

AWS 위에 3-Tier VPC → EKS 클러스터 → RDS → GitOps 배포 파이프라인까지를
**단계별 실행 스크립트**로 구성한 인프라 저장소입니다.

각 파일은 배스천 호스트에서 순서대로 실행하는 모듈이며,
CloudFormation 스택의 Output을 후속 스크립트가 자동으로 읽어가는 방식으로 연결됩니다.

- 아키텍처 다이어그램: [infra.drawio](https://app.diagrams.net/#Hsilver-ring-data%2FBootcamp_Study%2Fmain%2FK8S%2Finfra.drawio#%7B%22pageId%22%3A%22Mu30gTYnqA34-WPC4D4Z%22%7D)
  (열리지 않을 경우 << 다이어그램 이미지를 저장소에 직접 첨부 >>)
- 매니페스트 저장소: [de2-project1-team2-ee/manifests](https://github.com/de2-project1-team2-ee/manifests)

---

## 담당 범위

여러 명이 함께 구성한 저장소입니다. 아래 표는 `git blame` 기준 라인 수로,
파일별 주 작성자와 공동 작업 범위를 있는 그대로 정리한 것입니다.

| 파일 | 역할 | 주 작성 | 공동 작업 |
| --- | --- | --- | --- |
| `01_cloudformation_network_infra.yml` | VPC, 서브넷, NAT, IGW, 라우팅 | @silver-ring-data (358) | — |
| `02_cloudformation_bastion-EC2.yml` | 배스천 EC2, 보안 그룹, IAM, 도구 자동 설치 | @silver-ring-data (139) | @codingpoppy94 (6) |
| `env_config.txt` | 스택 Output 기반 공통 환경 변수 로더 | @silver-ring-data (61) | @codingpoppy94 (32) — GitHub 인증 블록 |
| `03_create_eks.sh` | EKS 클러스터 생성 (eksctl) | @silver-ring-data (69) | — |
| `04_setup_autoscaling_tools.txt` | Karpenter, Metrics Server, 모니터링 스택 설치 | @silver-ring-data (92) — Karpenter, IAM, discovery 태그 | @olevl9e (24) — metrics-server Helm 전환, kube-prometheus-stack 추가 / @codingpoppy94 (3) |
| `05_create_namespaces.sh` | 네임스페이스 및 라벨 구성 | @silver-ring-data (61) | — |
| `06_rds_setup.sh` | RDS(PostgreSQL) 프로비저닝 및 보안 그룹 연결 | @silver-ring-data (73) | @codingpoppy94 (47) — manifests 저장소 연동 |
| `07_deploy_app.txt` | ALB 컨트롤러, ArgoCD, 애플리케이션 배포 | @codingpoppy94 (59) — ArgoCD CI/CD | @silver-ring-data (52) — ALB 컨트롤러 / @olevl9e (1) |
| `08_monitoring.txt` | Prometheus / Grafana Ingress 구성 | @olevl9e (18) | — |
| `10_install_kubecost.txt` | EBS CSI Driver, Kubecost 설치 | @silver-ring-data (104) | — |
| `scripts/teardown/` | 전체 리소스 삭제 및 확인 절차 | @silver-ring-data | — |
| `v2.0/` | 기존 VPC 재사용 + 팀별 CIDR 자동 분할 개선안 (작업 중) | @silver-ring-data (384) | — |

> `08_monitoring.txt` 는 전적으로 다른 팀원이 작성한 파일이므로 원본을 그대로 유지합니다.
> 그 외 파일의 정리 작업(주석 정리, 보안 수정)은 저장소 소유자가 수행했습니다.

---

## 실행 순서

### [1] `01_cloudformation_network_infra.yml`

**역할**: VPC, 서브넷, NAT, IGW, Route Tables 생성

0. CloudFormation에서 스택 생성
   - $\color{red}{\text{스택 이름은 nat-stack 으로 지정}}$ (임시 규칙, 명명 규칙 개선 필요)
1. Service Name 입력 (`-`, `_` 가 들어가지 않도록 작성)
2. Team Number 입력

<img width="1889" height="401" alt="Image" src="https://github.com/user-attachments/assets/1ece3b4a-f98a-42d8-8cbd-d2684f2ce4fa" />

이후 파라미터는 필요할 때만 변경합니다. (CIDR 관련)

### [2] `02_cloudformation_bastion-EC2.yml`

**역할**: 배스천 서버, 보안 그룹, IAM 역할, 도구 자동 설치
1번 파일에서 만든 VPC ID와 Public Subnet A를 `Fn::ImportValue`로 자동 연결합니다.
도구 설치 때문에 스택 생성에 시간이 다소 걸립니다.

0. CloudFormation에서 스택 생성
1. $\color{red}{\text{Service Name (1번 파일과 동일해야 함)}}$
2. $\color{red}{\text{Team Number (1번 파일과 동일해야 함)}}$
3. Key pair 선택

**자동 설치되는 도구**: kubectl, helm, eksctl, aws cli, gh

**접근 통제 (3단계)**
1. 보안 그룹 — 지정한 IP만 22번 포트 허용
2. 키페어 — 파일 소유자만 SSH 접속 가능
3. IAM 역할 — 인스턴스 프로파일로만 권한 부여 (액세스 키를 배스천에 두지 않음)

이후 PuTTY 등으로 배스천에 접속하여 아래 단계를 진행합니다.

### [env_config.txt]

**역할**: 작업 시작 전 공통 변수 로드

1. 내용 복사 후 붙여넣기
2. Enter
3. 리전 입력, GitHub 계정/PAT 입력

`nat-stack`의 Output에서 VPC ID, 서브넷 ID, 서비스명, 팀 번호를 자동으로 읽어옵니다.
이미 로드된 셸에서 다시 호출되면 재입력 없이 넘어갑니다.

### [3] `03_create_eks.sh`

**역할**: 환경 변수 저장 및 EKS 클러스터 생성

1. 내용 복사 후 붙여넣기
2. Enter (약 15분 소요)

**참고**
- 1번 스택 이름을 자동화하려면 수정이 필요합니다. 현재는 `nat-stack`으로 생성한다고 가정합니다.
  - 태그 기반 조회를 쓰지 않은 이유는 안정성 때문입니다.
- 클러스터 명명은 추후 "개발팀 공유 클러스터 / 마케팅 공유 클러스터" 형태로 바꿔야 합니다.
  현재는 팀마다 개별 클러스터를 사용하고 있어 비용이 중복됩니다.

### [4] `04_setup_autoscaling_tools.txt` + `env_config.txt`

**역할**: Karpenter, Metrics Server 설치

1. 내용 복사 후 붙여넣기
2. Enter

**참고**: 해당 클러스터의 index 0인 노드 그룹에만 권한을 할당합니다.
모든 노드 그룹에 할당하려면 아래와 같이 반복문으로 변경해야 합니다. (미검증)

```bash
#!/bin/bash
# 변경 전
AUTO_NODEGROUP_NAME=$(aws eks list-nodegroups ... query "nodegroups[0]")

# 변경 후
NODEGROUP_LIST=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION} --query "nodegroups" --output text)

for NG in $NODEGROUP_LIST; do
    ROLE_ARN=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name $NG --region ${AWS_REGION} --query "nodegroup.nodeRole" --output text)
    ROLE_NAME=$(echo $ROLE_ARN | cut -d'/' -f2)

    echo "Injecting policy to: $NG ($ROLE_NAME)"
    aws iam put-role-policy --role-name ${ROLE_NAME} --policy-name KarpenterControllerPolicy --policy-document '{...}'
done
```

보안 그룹에서 4443 포트를 개방해야 합니다.

### [5] `05_create_namespaces.sh`

**역할**: 네임스페이스 생성

1. 내용 복사 후 붙여넣기
2. Enter

```bash
$ kubectl get ns --show-labels
NAME              STATUS   AGE    LABELS
default           Active   3h2m   kubernetes.io/metadata.name=default
dev               Active   53s    env=dev,karpenter.sh/discovery=<서비스명>-team-<번호>-cluster,kubernetes.io/metadata.name=dev,service=<서비스명>,team=team-<번호>
karpenter         Active   152m   kubernetes.io/metadata.name=karpenter,name=karpenter
kube-node-lease   Active   3h2m   kubernetes.io/metadata.name=kube-node-lease
kube-public       Active   3h2m   kubernetes.io/metadata.name=kube-public
kube-system       Active   3h2m   kubernetes.io/metadata.name=kube-system
monitoring        Active   53s    env=infra,kubernetes.io/metadata.name=monitoring,service=kubernetes-infra,team=admin
prod              Active   53s    env=prod,kubernetes.io/metadata.name=prod,service=<서비스명>,team=team-<번호>
stg               Active   53s    env=stg,kubernetes.io/metadata.name=stg,service=<서비스명>,team=team-<번호>
```

**참고**
- 구성은 dev(개발), stg(스테이징), prod(운영) + monitoring(관제)입니다.
- 모니터링 네임스페이스 분리 이유
  - Prometheus(수집), Grafana(시각화), Kubecost(비용 분석)를 한곳에 모읍니다.
  - 서비스 네임스페이스(dev, prod)와 섞이지 않아야 권한과 리소스 경계가 명확해집니다.
- YAML을 별도 파일로 분리하는 편이 낫지만, 소규모 작업이라 현재는 `.sh` 안에 함께 두었습니다.
  앞선 파일들도 마찬가지이며 규모가 커지면 분리가 필요합니다.

### [6] `06_rds_setup.sh`

**역할**: RDS(PostgreSQL) 세팅

1. 마스터 비밀번호를 환경 변수로 주입합니다. (저장소에 남기지 않기 위함)
   ```bash
   read -rsp "DB 마스터 비밀번호: " DB_PASSWORD; export DB_PASSWORD; echo
   ```
2. 내용 복사 후 붙여넣기
3. Enter (약 15분 소요, 중간에 `q` 입력이 필요할 수 있음)

**참고**
- `--multi-az` 로 AWS가 대기 인스턴스 이중화와 장애 조치를 처리합니다.
- 초기 개발 기간에는 배스천에서 DB에 접속할 수 있어야 하므로 배스천 보안 그룹을 열어 둡니다.
  **개발이 끝나면 해당 인바운드 규칙을 회수해야 합니다.**
- 같은 서비스의 다른 팀(`develop-team-1`, `develop-team-2`)인 경우
  - `create-db-instance` 는 건너뛰고, 아래 보안 그룹 설정만 수행합니다.
    - 다른 팀이 만든 RDS의 보안 그룹에 해당 팀의 EKS 노드 / 배스천 보안 그룹 ID를 Inbound 규칙으로 추가

### [7] `07_deploy_app.txt`

**역할**: ALB 컨트롤러 설치 + ArgoCD 설치 + 애플리케이션 배포 + 로드밸런서 연결

1. 내용 복사 후 붙여넣기
2. Enter (약 2분 소요)

<img width="788" height="123" alt="Image" src="https://github.com/user-attachments/assets/96fe4f74-87e3-4eaa-99f2-5e68ffad8234" />

```bash
$ kubectl logs -f deployment/<앱이름> -c log-sidecar -n dev
Found 2 pods, using pod/<앱이름>-65d6bc8445-584rv
10.0.16.130 - - [05/Apr/2026:06:50:42 +0000] "GET / HTTP/1.1" 200 124 "-" "ELB-HealthChecker/2.0" "-"
10.0.17.99 - - [05/Apr/2026:06:50:57 +0000] "GET / HTTP/1.1" 200 124 "-" "ELB-HealthChecker/2.0" "-"
10.0.16.130 - - [05/Apr/2026:06:50:57 +0000] "GET / HTTP/1.1" 200 124 "-" "ELB-HealthChecker/2.0" "-"
```

**CI/CD 흐름**

```
개발자 코드 Push → GitHub Actions(CI) → ECR 이미지 Push
→ manifests 레포 k8s/deployment.yaml 이미지 태그 갱신
→ ArgoCD(CD) 변경 감지 → EKS 자동 배포
```

### [8] `08_monitoring.txt`

**역할**: Grafana Ingress 재적용

ALB 컨트롤러(07번) 설치 이후에 실행해야 Ingress가 실제 로드밸런서로 승격됩니다.

### [10] `10_install_kubecost.txt`

**역할**: EBS CSI Driver 설치 + Kubecost 설치 및 Ingress 구성

Kubecost가 PV를 사용하므로 EBS CSI Driver를 먼저 설치합니다.

### [정리] `scripts/teardown/`

- `99_destroy_all.txt` — 전체 리소스 삭제 스크립트
- `99_destroy_all.md` — 삭제 후 콘솔에서 직접 확인해야 하는 항목

삭제 순서가 중요합니다. Ingress(ALB) → 네임스페이스 → Helm 릴리스 → IRSA → RDS → 클러스터 순으로
회수해야 보안 그룹이 ENI에 묶여 삭제가 실패하는 문제를 피할 수 있습니다.

---

## 보안 관련 결정과 남은 과제

이 저장소는 부트캠프 실습 환경을 전제로 구성되어 있습니다.
운영 환경에 그대로 적용할 수 없는 지점을 아래에 명시합니다.

### 조치 완료

| 항목 | 문제 | 조치 |
| --- | --- | --- |
| RDS 마스터 비밀번호 | 스크립트에 평문 하드코딩 | 실행 시점의 `DB_PASSWORD` 환경 변수로 주입. 미설정 시 `:?` 확장으로 즉시 실패하므로 약한 기본값으로 DB가 생성되지 않음 |
| GitHub PAT | 원격 URL에 포함, `~/.git-credentials` 에 평문 저장 | `GIT_ASKPASS` 헬퍼로 환경 변수 전달. `ps` 출력·`.git/config`·디스크 어디에도 남지 않음 |
| Karpenter `iam:PassRole` | `Resource: "*"` 로 전체 허용 | Karpenter가 실제로 넘기는 `KarpenterNodeRole-<클러스터>` 하나로 제한. 인스턴스 프로파일 조작도 계정 내 ARN으로 한정 |
| Karpenter 중단 큐 설정 | 존재하지 않는 SQS 큐를 `interruptionQueueName` 으로 지정하여 컨트롤러 기동 실패 | 해당 설정 제거. v1.x의 올바른 키 이름(`interruptionQueue`)과 큐 선행 생성 조건을 주석으로 명시 |
| RDS 보안 그룹 조회 | 배스천을 `*bastion*` 와일드카드로 탐색하여 다른 팀의 보안 그룹이 선택될 수 있음 | VPC와 정확한 Name 태그로 한정 |
| 정리 스크립트 | `kubectl patch` / `aws eks delete-addon` 에 존재하지 않는 `--ignore-not-found` 옵션 사용으로 해당 단계 실패 | 종료 코드를 무시하도록 수정 |

### 남은 과제

| 항목 | 현재 상태 | 개선 방향 |
| --- | --- | --- |
| 배스천 IAM 역할 | `AdministratorAccess` | eksctl이 요구하는 EKS / CloudFormation / EC2 / IAM 범위로 축소. IAM 조작은 `eksctl-*`, `KarpenterNodeRole-*` 등 이름 패턴으로 제한 |
| 배스천 SSH | `SgIngressSshCidr` 기본값이 `0.0.0.0/0` | 스택 생성 시 반드시 본인 IP `/32` 로 지정. 기본값 제거 필요 |
| 애플리케이션 ALB | 80포트를 `0.0.0.0/0` 에 개방 | 특정 IP 대역으로 제한하거나 HTTPS(ACM) 적용 |
| Grafana / Kubecost / ArgoCD | `internet-facing` ALB로 노출 | `alb.ingress.kubernetes.io/inbound-cidrs` 로 접근 대역 제한, 기본 관리자 비밀번호 교체 |
| Karpenter 컨트롤러 권한 | 노드 IAM 역할에 인라인 정책으로 부여. 해당 노드의 모든 파드가 메타데이터를 통해 같은 권한을 사용할 수 있음 | IRSA(서비스 어카운트 단위 역할)로 컨트롤러 권한을 분리. `iam:PassRole` 범위 제한은 완화 조치이며 근본 해결은 아님 |
| DB 접속 정보 | manifests 저장소의 Secret 매니페스트로 전달 | Secret은 Git에 두지 않고 External Secrets Operator 또는 `kubectl create secret` 으로 클러스터에 직접 주입 |
| RDS 마스터 비밀번호 관리 | 운영자가 환경 변수로 직접 관리 | AWS Secrets Manager 관리형 비밀번호(`--manage-master-user-password`)로 전환하여 자동 교체 |
| RDS 저장소 암호화 | 미적용 | `--storage-encrypted` 및 백업 보관 기간 설정 |
| 노드 IMDS | IMDSv1 허용, 홉 제한 미설정 | `httpTokens: required`, `httpPutResponseHopLimit: 1` 로 컨테이너에서의 자격 증명 탈취 경로 차단 |

## 기타 고려 사항

- 모듈식으로 나눈 파일들을 일괄 실행하되, 조건에 따라 일부 모듈(DB 생성 등)을 건너뛰도록 만들어야 합니다.
- 현재 실행 방식은 "파일 내용을 배스천에 붙여넣기"입니다. 저장소를 clone 하여 실행하는 방식으로 바꾸면
  스크립트가 자기 자신을 다시 생성하는 구조를 없앨 수 있습니다.
