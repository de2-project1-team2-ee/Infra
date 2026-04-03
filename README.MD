# 첫번째 파일 (1_~) 
### 역할 : VPC, 서브넷, NAT, IGW, Route Tables 생성

1. Service Name 입력
2. team Number 입력

<img width="1889" height="401" alt="Image" src="https://github.com/user-attachments/assets/1ece3b4a-f98a-42d8-8cbd-d2684f2ce4fa" />

(이후 아래는 필요하다면 변경 CIDR 관련 파라미터들)

# 두번째 파일 (2_~)
### 역할 : Bastion 서버 만들기 (툴 자동 설치로 시간 좀 걸려요)
### 1번파일에서 만든 vpc id와 public subnet A를 자동으로 매칭해서 만들어줌
1. Service Name 입력 (1번에서 만들었던 이름과 완전히 같아야함)
2. team Number 입력 (1번에서 만들었던 이름과 완전히 같아야함)
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
