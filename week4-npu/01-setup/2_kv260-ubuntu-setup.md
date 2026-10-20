# KV260 Ubuntu 22.04 셋업 (타겟)

Canonical이 제공하는 **Ubuntu Server/Desktop 22.04 LTS (Kria SOM용 인증 이미지)**를 사용합니다.

## 1. 이미지 확보 및 쓰기

1. Canonical downloads에서 "Ubuntu for Kria" / KV260 22.04 이미지를 내려받습니다.
2. 32GB 이상 microSD(U3 권장)에 이미지를 씁니다.
   - Windows: Raspberry Pi Imager 또는 balenaEtcher
   - Linux: `dd` 또는 Raspberry Pi Imaster
3. SOM firmware(PLM/PMUFW 등)가 이미지와 궁합이 맞는지 강사가 사전 확인합니다. Canonical 인증 이미지는 Kria firmware 업데이트 안내가 있는 경우가 있어, 첫 부팅 전에 강사 안내문을 따르세요.

## 2. 최초 부팅

1. 어댑터(12V 3A, 별매) 연결 → microSD 삽입 → 전원.
2. 모니터(HDMI/DP) 또는 이더넷 SSH로 접속. 기본 계정은 이미지 안내에 따릅니다.
3. 시스템 점검:

```
uname -r                  # 커널 5.15 계열 (22.04 기준)
cat /etc/os-release       # Ubuntu 22.04
hostnamectl
```

## 3. 네트워크·SSH

호스트와 직접 연결하는 경우 호스트 측에 고정 IP를 줍니다 (예: 192.168.1.10/24). 타겟에서:

```
ip addr show              # 이더넷 인터페이스 이름 확인 (예: enP1p1s0)
# DHCP가 안 되면 직접 설정 예시:
sudo nmcli con mod "이더넷 연결 1" ipv4.addresses 192.168.1.20/24
sudo nmcli con mod "이더넷 연결 1" ipv4.gateway 192.168.1.1
sudo nmcli con mod "이더넷 연결 1" ipv4.dns "8.8.8.8"
sudo nmcli con up "이더넷 연결 1"

sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

호스트에서 `ssh 사용자@192.168.1.20` 접속 확인.

## 4. 교육용 준비 패키지

```
sudo apt update
sudo apt install -y build-essential python3 python3-pip git vim device-tree-compiler
pip3 install numpy --break-system-packages 2>/dev/null || pip3 install numpy
```

## 5. Kria 펌웨어·도구 확인

```
which xmutil || sudo apt install xlnx-apps 2>/dev/null
xmutil listapps
```

- `xmutil`이 없으면 AMD/Canonical Kria 앱 패키지 설치 경로를 강사 안내문으로 배포합니다 (배포 소스에 따라 패키지명이 다릅니다).
- `xmutil listapps`가 동작하면 3일차 overlay 로딩 실습 준비 완료입니다.

## 6. udmabuf 준비 (4일차 DMA 버퍼)

```
sudo modprobe udmabuf
ls -l /dev/udmabuf       # 장치 파일 확인
# 부팅 시 자동 로드:
echo udmabuf | sudo tee /etc/modules-load.d/udmabuf.conf
echo 'options udmabuf phys_addr=logical' | sudo tee /etc/modprobe.d/udmabuf.conf
```

## 7. 권한 (교육용)

mmap 실습을 위해 교육 계정에 sudo 전체 허용을 두는 것이 편합니다:

```
sudo usermod -aG sudo 사용자명
```

## 8. 검증 체크

- [ ] SSH로 호스트에서 접속 가능
- [ ] `xmutil listapps` 동작
- [ ] `/dev/udmabuf` 존재 (또는 모듈 로드 가능)
- [ ] `python3 -c "import numpy"` 동작
- [ ] 재부팅 후에도 네트워크·ssh 자동 복구
