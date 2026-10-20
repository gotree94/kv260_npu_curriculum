# 4주차 — NPU 설계 상세 실습 (환경 설정 ~ 예제 실행)

이 폴더는 `README.md`(4주 커리큘럼)의 **4주차**를 실제 진행할 수 있도록 환경 설정부터 보드 추론까지 단계별로 작성한 상세 자료입니다. 기준 툴은 **Vivado/Vitis 2022.2, Vitis AI 3.0, Canonical Ubuntu 22.04**입니다.

## 폴더 구성

| 폴더 / 파일 | 진행 시점 | 내용 |
|---|---|---|
| [01-setup](01-setup/README.md) | 사전 준비 (강사·학생) | 호스트 PC, KV260 Ubuntu, Vitis AI 도커 셋업 |
| [02-day1-golden-model](02-day1-golden-model/README.md) | 4주차 1일차 | INT8 골든 모델, 테스트 벡터 생성 |
| [03-day2-systolic](03-day2-systolic/README.md) | 2일차 | PE + 4×4 Systolic Array RTL, xsim 시뮬레이션 |
| [04-day3-system](04-day3-system/README.md) | 3일차 | AXI-Lite 제어 + AXI-Stream/DMA 통합 |
| [05-day4-board](05-day4-board/README.md) | 4일차 | 보드 구현, Linux Python 제어, MNIST 추론 |
| [06-day5-dpu-compare](06-day5-dpu-compare/README.md) | 5일차 | Vitis AI 3.0 DPU 비교 시연, 보고서 작성 |

## 설계 규모 (교육 기준)

| 항목 | 값 |
|---|---|
| Systolic Array | 4×4 (심화: 8×8) |
| 데이터 | INT8 (가중치·활성화), INT32 누적 |
| 연산 | GEMM (A[M×K] × B[K×N]) → MNIST FC 추론에 사용 |
| 제어 | AXI4-Lite 레지스터 |
| 데이터 이동 | AXI DMA (S2MM/MM2S) + AXI-Stream |
| 타겟 | KV260 (XCZU5EV), Ubuntu 22.04 |

## 전체 흐름

```
[01-setup] 호스트 + 타겟 + 도커 준비
      ↓
[02-day1]  numpy INT8 골든 모델 + 벡터 파일 생성 (a.hex, w.hex, ref.hex)
      ↓
[03-day2]  RTL PE/어레이가 같은 벡터로 골든과 일치 확인 (xsim)
      ↓
[04-day3]  어레이를 AXI-Lite/Stream으로 감싸 Block Design에 통합
      ↓
[05-day4]  bitstream → Ubuntu에서 Python mmap/DMA로 추론, MNIST 실행
      ↓
[06-day5]  DPU(보수 B512) 추론과 비교표 작성, 발표
```

## 학생 사전 점검 (1일차 시작 전)

- [ ] `01-setup`의 호스트 PC 항목 완료 (Vivado/Vitis 2022.2, Python 3, numpy)
- [ ] KV260 전원(12V 3A 별매 어댑터), Pmod 없이도 진행 가능 (4주차는 PMOD 불필요)
- [ ] 이더넷: 호스트 ↔ KV260 직접 연결 또는 동일 LAN, 고정 IP 계획 있음
- [ ] SSD/디스크 여유 80GB 이상 (Vivado+Vitis), 4주차 산출물 저장 공간

## 강사 사전 점검

- [ ] `03-day2` 시뮬레이션 전량 통과
- [ ] `04-day3` Block Design 레퍼런스 프로젝트 빌드 통과
- [ ] `05-day4` 보드 추론 end-to-end 통과 (MNIST 정확률 기록)
- [ ] `06-day5` DPU B512 bitstream + Vitis AI 3.0 도커 추론 통과
- [ ] 모든 hex/레퍼런스 산출물을 학생 공유 폴더에 배포
