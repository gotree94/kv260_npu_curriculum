# 01 — 환경 설정

4주차 시작 전에 아래 3개 환경을 준비합니다. 예상 소요: 호스트 2~3시간(다운로드 제외), 타겟 1시간, 도커 1시간.

| 순서 | 문서 | 대상 |
|---|---|---|
| 1 | [1_host-pc-setup.md](1_host-pc-setup.md) | 학생/강사 호스트 (Windows 11 또는 Ubuntu 22.04) |
| 2 | [2_kv260-ubuntu-setup.md](2_kv260-ubuntu-setup.md) | KV260 타겟 (Canonical Ubuntu 22.04) |
| 3 | [3_vitis-ai-docker.md](3_vitis-ai-docker.md) | 강사/공용 PC 1~2대 (DPU 비교용) |

네트워크 예시 (직접 연결):

```
호스트 PC (예: 192.168.1.10) ←이더넷→ KV260 Ubuntu (예: 192.168.1.20)
```

SSH 계정은 교육용으로 교육명/학번 기반 계정을 만들어 배포합니다. root 권한이 필요한 실습(udo)이 있으므로 sudoers 허용을 사전에 설정하세요.
