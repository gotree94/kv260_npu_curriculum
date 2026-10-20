# Kria KV260 기반 로직 설계 → Embedded Linux → NPU 설계 (4주)

## 기준 툴 버전: Vivado / Vitis 2022.2

---

## 1. 과정 개요

| 항목 | 내용 |
|---|---|
| 교육 기간 | 4주 (주 5일, 수업 1일 7시간 / 체류 8시간, 총 수업 140시간) |
| 사용 보드 | AMD Kria KV260 Vision AI Starter Kit (Zynq UltraScale+ MPSoC, K26 SOM = XCZU5EV) |
| 개발 환경 | **Vivado ML Edition 2022.2 / Vitis 2022.2 / Vitis AI 3.0** |
| 라이선스 | **Vivado ML Standard — 라이선스 파일 불필요** (Kria SOM 포함, 2022.2 기준) |
| 대상 (가정) | 전자·전기·컴퓨터 계열 전공자, 취업준비생 (C 언어와 기초 디지털 회로 지식 보유) |
| 최종 목표 | 직접 설계한 INT8 Systolic Array NPU를 KV260에 구현하고, Linux에서 구동해 소형 신경망 추론 성능을 측정. AMD DPU와 비교 분석 |

> **버전 고정 원칙**: 2022.2(베이스)로 통일합니다. 2022.2.1/.2 업데이트는 Versal 디바이스 대응이 주 목적이라 K26(KV260) 교육에는 베이스 2022.2로 충분합니다. 혼용 금지 — 학생 PC·강사 PC·서버 전체를 동일 버전으로 유지하세요.
>
> **차기 버전 업그레이드**: 본 커리큘럼 검증 완료 후 2025.2로 이식하는 계획은 [10절](#10-20252-업그레이드-로드맵) 참조.

### 툴 구성 (학생 배포용)

| 툴 | 버전 | 용도 | 비고 |
|---|---|---|---|
| Vivado ML Edition (Standard) | 2022.2 | HDL 설계, 합성, 구현, 시뮬레이션(xsim), ILA | **설치 후 바로 사용, 라이선스 발급 절차 없음** |
| Vitis | 2022.2 | 베어메탈 애플리케이션, HLS | classic(XSCT) 플로우 |
| Vitis AI | 3.0 (도커) | DPU(NPU IP) 모델 양자화·컴파일·추론 | 2022.2와 공식 페어링 |
| Canonical Ubuntu Server/Desktop | 22.04 LTS (KV260용) | 타겟 Linux | Canonical 인증 이미지 |
| PetaLinux (강사용) | 2022.2 | Yocto 빌드 시연 | 학생 설치 불필요 |

> ⚠️ 지원 목록의 **Vivado Lab Solutions는 하드웨어 프로그래밍/디버깅 전용 경량 도구**이며 설계(합성·구현)가 불가합니다. 교육용에는 Vivado ML Edition 전체 설치가 필요합니다.

### 학습 흐름

```
1주차: 로직 설계 (Verilog/VHDL, Vivado, PL 실습)
   ↓
2주차: SoC 통합 (PS-PL, AXI, DMA, 가속기 IP — classic Vitis)
   ↓
3주차: Embedded Linux (부팅, Device Tree, Overlay, 드라이버)
   ↓
4주차: NPU 설계 (MAC → Systolic Array → 시스템 통합 → DPU 비교 → 성능 측정)
```

### 일일 시간 운영 (수업 7시간 기준)

| 시간 | 구성 |
|---|---|
| 09:00 – 10:30 | 이론 / 시연 (90분) |
| 10:40 – 12:10 | 실습 1 (90분) |
| 12:10 – 13:10 | 점심 (체류 시간) |
| 13:10 – 14:40 | 실습 2 (90분) |
| 14:50 – 16:20 | 실습 3 / 과제 (90분) |
| 16:30 – 17:30 | 정리, Q&A, 일일 점검 (60분) |

- **수업 시간: 일 7시간 × 20일 = 140시간.** 출결·평가 기준은 이 140시간을 따릅니다.
- 체류 시간(점심·휴식 포함) 기준으로는 총 160시간입니다.
- 이론 약 25%, 실습 약 75%. 합성·구현 대기 시간은 이론이나 코드 리뷰로 채웁니다. (2022.2 기준 KV260 규모 합성은 학생 PC에서 10~30분 수준)

---

## 2. 1주차 — 디지털 로직 설계 (Verilog / VHDL)

**주간 목표**: HDL로 조합·순차회로와 FSM을 설계하고, Vivado 플로우(시뮬레이션 → 합성 → 구현 → 비트스트림)를 혼자 수행한다.

| 일차 | 주제 | 주요 내용 | 실습 / 산출물 |
|---|---|---|---|
| 1일 | 오리엔테이션, FPGA 개요, Vivado 플로우 | FPGA 구조(LUT, FF, DSP, BRAM), KV260 보드 구성, 툴 설치 확인, 프로젝트 생성, 조합회로 Verilog (assign, always @*) | 가산기, MUX, 디코더 설계 후 xsim 시뮬레이션 |
| 2일 | 순차회로와 테스트벤치 | 플립플롭, 블로킹/논블로킹 할당, 카운터, 시프트 레지스터, 테스트벤치 작성, 파형 분석 | 카운터·시프트 레지스트 + self-checking 테스트벤치 |
| 3일 | FSM과 타이밍 | Moore/Mealy FSM, 합성 가능한 코딩 스타일, 클럭·리셋 설계, XDC 제약, 타이밍 리포트 읽기 | 버튼 디바운서 + FSM 기반 시퀀스 검출기 |
| 4일 | VHDL 비교와 UART | VHDL 문법(entity/architecture, signal/process), Verilog와 1:1 비교, 혼합 언어 시뮬레이션 | 같은 카운터·FSM을 VHDL로 변환, UART TX/RX 설계 |
| 5일 | 메모리, 연산기, 디버깅 | BRAM 추론, FIFO, DSP48 기반 곱셈·MAC 추론, ILA 디버깅 | 파이프라인 MAC 유닛 설계, 주간 평가 |

### 보드 실습 안내

- KV260 캐리어 카드 **J2에 Digilent Pmod 2×6(12핀, I/O 8개)**이 있고 **PL에 직접 연결**되어 있습니다. 교육용으로는 Pmod LED 모듈(4비트) + Pmod 스위치 모듈(4비트) 1세트가 기본 구성입니다.
- **Pmod는 보드당 1개뿐**입니다. 2인 1조 운영 시 조당 1세트를 공유하며, PMOD 모듈 수량 = 조 수로 사전 계획하세요.
- 전원 핀 공급 능력: 3.3V / 100mA 제한 — 고전력 모듈(모터류)은 사용 금지.
- XDC 핀맵 (J2): S1A~S4A = HDA11~HDA14 (패키지 핀 H12, E10, D10, C11), S1B~S4B = HDA15~HDA18 (B10, E12, D11, B11). LVCMOS33. 교재에 함드아웃으로 첨부.
- 1~2일차는 시뮬레이션 중심, 3~5일차에 보드 실습을 배치합니다.

### 2022.2 환경 참고

- xsim, ILA, System ILA 등 디버그 기능은 Standard 에디션에서 **무제한 풀 기능**입니다 (2026.1의 BASIC 티어 제한 없음).
- Vivado 2022.2는 Windows 10/11, Ubuntu 20.04/22.04 공식 지원.

**1주차 평가**: 필기 퀴즈(30%) + 실습 평가 (UART 또는 MAC 설계, 70%)

---

## 3. 2주차 — SoC 통합 (PS-PL, AXI)

**주간 목표**: Zynq UltraScale+ PS와 PL을 연결하고, 직접 만든 IP를 AXI로 PS에서 제어한다. (classic Vitis 플로우 기준)

| 일차 | 주제 | 주요 내용 | 실습 / 산출물 |
|---|---|---|---|
| 1일 | Zynq UltraScale+ 아키텍처, Block Design | APU/RPU/PMU 구성, PS-PL 인터페이스(HP/HPM/ACP), IP Integrator, PS 설정, XSA 추출, **Vitis classic 흐름**(app 템플릿, FSBL+PMUFW+ATF+U-Boot 부트 컴포넌트) | PS 포함 Block Design 생성, XSA 추출, Hello World 실행 |
| 2일 | AXI 프로토콜 | AXI4-Lite, AXI4, AXI-Stream 핸드셰이크(VALID/READY), 버스 시뮬레이션 | AXI-Lite 슬레이브 레지스터 IP 작성 및 시뮬레이션 |
| 3일 | 커스텀 IP와 인터럽트 | IP 패키징, 레지스터 맵 설계, 베어메탈 드라이버 작성, 인터럽트 연결(GIC) | LED/카운터 제어 IP + 인터럽트 기반 PS 제어 |
| 4일 | DMA와 스트리밍 | AXI DMA(Simple/SG), AXI-Stream 파이프라인, 데이터 무결성 검증 | 스트림 MAC/필터 가속기 + DMA 루프백 |
| 5일 | HLS 맛보기, 미니 프로젝트 | Vitis HLS 기본(pragma, 인터페이스), RTL과 HLS 결과 비교(자원·지연시간) | 미니 프로젝트: 스트리밍 FIR/MAC 가속기 PS 구동, 주간 평가 |

### 운영 참고

- **AXI-Lite IP는 Vivado "Create and Package New IP" 템플릿을 활용**합니다. 인터페이스 스텁은 툴이 생성하고, 핸드셰이크·레지스터 동작 논리만 학생이 작성하도록 실습지를 설계하세요. 처음부터 손으로 쓰면 1일차 일정이 깨집니다.
- 2022.2의 Vitis는 classic IDE + XSCT 기반입니다. 향후 2025.2의 Unified IDE/EDF 플로우와 화면이 다르므로, 실습 매뉴얼은 2022.2 화면 기준으로 자체 캡처해 배포하세요.
- 부트 이미지 구성요소 학습: FSBL (ZynqMP第一段), PMU Firmware, ATF, U-Boot — 2022.2 시점 공식 명칭입니다.

**2주차 평가**: 미니 프로젝트 시연(80%) + 코드 리뷰(20%)

---

## 4. 3주차 — Embedded Linux

**주간 목표**: KV260의 부팅 구조를 이해하고, Linux에서 PL 가속기를 로딩·제어하는 소프트웨어 스택을 구성한다.

| 일차 | 주제 | 주요 내용 | 실습 / 산출물 |
|---|---|---|---|
| 1일 | 부팅 플로우와 Linux 환경 | BootROM → FSBL/PMU Firmware → ATF → U-Boot → Kernel, **Canonical Ubuntu 22.04 LTS(KV260용) 설치·부팅**, 기본 시스템 점검, 네트워크·SSH 설정 | SD 카드 이미지 작성, 부팅 로그 분석 |
| 2일 | Device Tree와 PL 동적 로딩 | Device Tree 구조, Overlay(dtbo), bitstream 변환(bit.bin), **xmutil**, shell.json, Kria firmware 패키지 구조, 동적 로딩 | 2주차 IP를 firmware 앱으로 패키징해 Linux에서 로드 |
| 3일 | 사용자 공간 접근 | UIO, /dev/mem, mmap, Python 제어(선택: PYNQ), 레지스터 읽기/쓰기 | Python으로 IP 제어, 인터럽트 대기 |
| 4일 | 커널 드라이버와 DMA 버퍼 | 플랫폼 드라이버 기본, 캐릭터 디바이스, 인터럽트 처리, DMA 버퍼 관리(udmabuf/DMA-BUF) | 간단한 커널 모듈 작성, DMA 전송 응용 |
| 5일 | Yocto/PetaLinux 빌드 개요, 통합 실습 | PetaLinux 2022.2 빌드 구조(시연 중심, 빌드 시간 고려), 이미지 커스터마이징 개념, 통합 과제 | 통합 과제: Linux에서 DMA로 스트리밍 가속기 구동, 주간 평가 |

### 운영 참고

- 타겟 Linux는 **Canonical이 제공하는 KV260용 Ubuntu 22.04 LTS 인증 이미지**를 기본으로 합니다. Canonical 인증 이미지는 Kria firmware 업데이트가 필요할 수 있으므로, 부팅 전에 SOM/캐리어 firmware 버전을 강사가 사전에 맞춰 두세요.
- PetaLinux/Yocto 풀 빌드는 시간과 디스크(수십~100GB)가 크므로, 5일차는 **미리 빌드해 둔 결과물(PetaLinux 2022.2)**로 구조 설명과 일부 레이어 수정 시연을 하는 방식으로 진행합니다.
- 2022.2 시점에는 PetaLinux가 정식 툴이었고(2025.x 이후 Yocto 기반으로 정책 이동), 3주차 명칭을 "PetaLinux/Yocto" 병기하면 학생들이 향후 자료를 찾기도 쉽습니다.

**3주차 평가**: 통합 과제 시연(70%) + 부팅/Device Tree 구술 질의(30%)

---

## 5. 4주차 — NPU 설계

**주간 목표**: INT8 Systolic Array 기반 NPU를 직접 설계·구현하고, Linux에서 소형 신경망을 추론해 성능을 측정한다. 마지막 날 AMD DPU와 비교한다.

| 일차 | 주제 | 주요 내용 | 실습 / 산출물 |
|---|---|---|---|
| 1일 | NN 연산과 NPU 구조 | FC/Conv를 행렬곱(GEMM)으로 변환, INT8 양자화, NPU 구조(PE 어레이, 버퍼, 컨트롤러), 스펙 정의(어레이 크기, 데이터 폭) | NumPy 골든 모델(INT8 행렬곱, MNIST 소형 모델) |
| 2일 | PE와 Systolic Array | PE(MAC) 설계, 데이터 흐름(weight/output stationary), 4×4 어레이 → 파라미터화, 입력 스큐 | RTL Systolic Array + 골든 모델 비교 테스트벤치 |
| 3일 | 버퍼, 컨트롤러, 시스템 통합 | BRAM 기반 입출력 버퍼, 타일링, 컨트롤 FSM/레지스터 맵, AXI-Stream/DMA 연동 | NPU 코어 + DMA + AXI-Lite 제어 통합, 시스템 시뮬레이션 |
| 4일 | 보드 구현과 추론 | 합성·구현·타이밍 클로징, Linux 드라이버/Python API 연동, 소형 모델 추론, 성능 측정 | MNIST 추론 데모, GOPS·지연시간·자원 측정표 |
| 5일 | DPU 비교, 최종 발표 | **Vitis AI 3.0 기반 DPU 추론 시연**, 직접 설계 NPU와의 성능·자원·유연성 비교, 최적화 논의, 최종 발표 | 비교 분석표, 결과 보고서, 발표, 최종 평가 |

### 4주차 설계 규모 권장

- 기본 목표는 **4×4 ~ 8×8 INT8 Systolic Array**입니다. K26은 DSP 약 1,200개, LUT 117K 수준이라 자원 여유가 있지만, 교육 일정과 타이밍 클로징 시간을 고려해 보수적으로 잡으세요.
- PE를 브루트포스로 늘리는 것보다, **타일링·데이터 재사용·제어 로직 심화**가 교육 효과와 자원 효율 면에서 낫습니다.
- 심화 팀 과제: 어레이 크기 확장, Conv 타일링, ReLU·재양자화 블록 추가.

### DPU 비교 시연 (5일차, 확정 포함)

2022.2 + Vitis AI 3.0은 **Zynq UltraScale+ DPU(DPUCZDX8G)의 공식 검증 조합**이므로, 사전 준비를 통해 실동작 시연이 가능합니다.

사전 준비 항목 (강사):
1. Vitis AI 3.0 도커 이미지: `docker pull xilinx/vitis-ai-cpu:3.0`
2. DPU 포함 Bitstream: KV260용 DPU 프로젝트(arch: B4096 또는 B512)를 2022.2로 빌드해 둠 — B512가 자원·구현 시간 면에서 교육용에 적합
3. 타겟: Canonical Ubuntu 22.04 이미지에 DPU 펌웨어 패키지(xmutil 로드용) 설치
4. 모델: MNIST 또는 ResNet18(소형)을 Vitis AI 3.0으로 양자화·컴파일 (`vai_c_xir`, arch.json: `/opt/vitis_ai/compiler/arch/DPUCZDX8G/KV260/arch.json`)

비교 관점 (보고서 템플릿에 포함):
| 관점 | 직접 설계 NPU | AMD DPU |
|---|---|---|
| 성능 (GOPS, 추론 ms) | 학생 측정값 | 학생 측정값 |
| 자원 (LUT/FF/DSP/BRAM) | 학생 측정값 | 학생 측정값 |
| 재구성 | 네트워크마다 RTL 수정 | 소프트웨어 컴파일만으로 교체 |
| 설계 학습 효과 | 구조 전체 이해 | ISA·컴파일러 스택 이해 |

**4주차 평가**: 최종 프로젝트(설계 완성도 40%, 동작 시연 30%, 성능 분석·보고서 30%)

---

## 6. 전체 평가 구성

| 항목 | 비중 |
|---|---|
| 1주차 평가 (HDL 설계) | 15% |
| 2주차 미니 프로젝트 (SoC 통합) | 20% |
| 3주차 통합 과제 (Linux) | 20% |
| 4주차 최종 프로젝트 (NPU) | 35% |
| 출석·참여·일일 점검 | 10% |

---

## 7. 준비물 및 사전 점검

### 하드웨어

| 품목 | 수량 기준 | 비고 |
|---|---|---|
| Kria KV260 Starter Kit | 학생당 1대 또는 2인 1조 | SOM + 캐리어 + 방열판 포함 |
| **12V 3A DC 어댑터** | **KIT에 미포함 — 별매 필수** | 2.5mm 바렐(중앙 +). 예: CUI SMI36-12-V-P6. 수량 = 보드 수 |
| **microSD 카드 (32GB 이상, U3 권장)** | 보드당 1장 | 베이식 킷 구성에 따라 미포함 — 사전 확인 후 별도 조달 |
| Pmod LED 모듈 + Pmod 스위치 모듈 | **조당 1세트** (Pmod는 보드당 1개) | Digilent 호환 2×6 Type 1A |
| USB 케이블 (Micro-USB, JTAG/UART) | 보드당 1 | 케이블 포함 여부는 킷 구성 확인 |
| 이더넷 케이블, 모니터·키보드·마우스 | 환경에 맞게 | Ubuntu 데스크톱 이미지 사용 시 모니터 필요 |
| USB 전력계 (선택) | 1~2개 | 4주차 전력 측정용 |

> KV260 구매 시 **Kria Basic Accessory Pack** 별매 품목(전원, 케이블 등 포함 여부)이 킷 구성과 다를 수 있습니다. 주문 전에 판매처 구성표를 확인하세요.

### 소프트웨어 / 서버

- **Vivado ML Edition 2022.2** (Standard) — 라이선스 파일 불필요, Windows 10/11 및 Ubuntu 지원
- **Vitis 2022.2** — classic IDE 플로우
- 설치 용량: Vivado 약 50~60GB, Vitis 포함 시 80GB급. RAM 32GB 이상 권장
- 학생 PC 사양이 부족하면 **공용 빌드 서버(원격 접속)** 구성을 사전에 검토
- 보조 도구: Python 3 (NumPy), Verilator/cocotb (선택 — 대형 TB나 무ライ선스 시뮬레이션 보조), Git, Docker (Vitis AI용, 강사/공용 1~2대)

### 강사 사전 검증 체크리스트

- [ ] **Vivado/Vitis 2022.2 통일 확정** — 2022.2.1/.2 혼용 금지, 전 실습 예제 사전 빌드 완료
- [ ] 학생 PC·서버 OS 호환성 확인 (Windows 11 또는 Ubuntu 22.04 기준)
- [ ] **Canonical Ubuntu 22.04 KV260 이미지** 다운로드·부팅 검증, Kria firmware/SOM firmware 버전 확정
- [ ] KV260 Ubuntu 이미지와 2022.2로 빌드한 overlay/firmware(xmutil 패키지) 로딩 호환성 확인
- [ ] **12V 3A 어댑터·microSD·Pmod 모듈 수량 확보** (조 단위)
- [ ] 2주차 → 3주차 → 4주차로 이어지는 IP 재사용 흐름 검증
- [ ] 4주차 NPU 레퍼런스 설계(골든 모델, 테스트벤치, Linux 앱) 완성본 준비
- [ ] **Vitis AI 3.0 도커 + KV260 DPU(B512) 프로젝트 빌드 + 추론까지 end-to-end 검증** (5일차 시연 확정)
- [ ] 합성·구현 시간 측정 후 일정(대기 시간 활용 계획) 조정
- [ ] 2022.2 화면 기준 실습 매뉴얼 자체 캡처·제작 (학생이 검색한 최신 문서와 화면이 다름)

---

## 8. 위험 요소와 대응

| 위험 | 대응 |
|---|---|
| 툴 설치 문제로 1일차 지연 | 사전 설치 안내 배포, 사전 검증된 VM 또는 원격 서버 준비. 라이선스 발급 절차는 없으나 설치 용량·시간 안내는 필수 |
| 합성·구현 시간으로 실습 지연 | 시뮬레이션 우선 검증, 작은 예제 유지, 대기 시간에 코드 리뷰 |
| Pmod 부족으로 1주차 보드 실습 제한 | 2인 1조 운영, 시뮬레이션 비중 확대, Pmod 모듈 수량 = 조 수로 확보 |
| 학생 수준 편차 | 기본/심화 과제 분리, 조 편성 시 수준 혼합 |
| 학생이 검색한 문서가 2024~2026 버전이어서 혼란 | 자체 실습 매뉴얼(2022.2 캡처) 필수 배포, 과제 명시에 툴 버전 명기 |
| 3주차 Linux/PetaLinux 빌드 시간 과다 | 사전 빌드 결과물 사용, 빌드는 시연 중심 |
| 4주차 NPU 타이밍 미충족 | 클럭을 낮춰 먼저 동작 확인, 어레이 크기 축소, 파이프라인 단계 추가 |
| Vitis AI 3.0 도커 환경 문제 | 도커 이미지 사전 풀, 추론 데모는 사전 빌드 xmodel + 이미지 준비해 두고 현장 빌드는 보조로 |

---

## 9. 확장 / 후속 과정 아이디어

- Conv 계층 타일링과 ReLU·풀링 블록을 포함한 CNN 가속기 심화 과정
- 양자화 인식 학습(QAT)과 모델 컴파일러(TVM 등) 연동
- DPU(Vitis AI) 심화: 커스텀 아키텍처, 다중 DPU, 최신 모델 배포
- 검증 방법론(UVM/cocotb) 및 저전력·타이밍 최적화 과정

---

## 10. 2025.2 업그레이드 로드맵

본 커리큘럼(2022.2) 검증 완료 후, 차기 훈련부터 아래 순서로 2025.2로 이식합니다. 2025.2도 **ML Standard 무료(라이선스 파일 불필요)**이므로 라이선스 운영 부담은 동일합니다.

| 항목 | 2022.2 (현행) | 2025.2 (이식 시) | 작업량 |
|---|---|---|---|
| Vivado | ML Standard, 무제한 | ML Standard, 무제한 | 소 — 화면 차이 확인만 |
| Vitis IDE | classic + XSCT | **Unified IDE**(기본) — classic 폐기 수순 | **중 — 2주차 실습 매뉴얼 전면 재작성** |
| 부트/플랫폼 | classic BSP | SDT/EDF 플로우 권장 | 중 — 강사 검증 필요 |
| Vitis AI | 3.0 (도커) | **6.1 공식 페어링 (2025.2)** — quantizer·compiler 워크플로우 변경 (Quark 등) | **중~대 — 4주차 DPU 실습 재검증** |
| Ubuntu 타겟 | 22.04 | 22.04 유지 가능 / 24.04 인증 이미지 여부 확인 | 소~중 |
| PetaLinux | 2022.2 | 2025.2 | 소 — 시연 중심이라 영향 낮음 |
| 실습 매뉴얼 | 2022.2 캡처 | 2025.2 캡처로 갱신 | 대 — 전체 갱신 |

이식 우선순위: (1) Vitis classic → Unified IDE 변경이 2주차의 핵심, (2) Vitis AI 3.0 → 6.x 워크플로우가 4일차의 핵심. 1·3주차는 비교적 그대로 이식 가능합니다.

---

## 부록 A. KV260 Pmod J2 핀맵 (XDC 핸드아웃용)

| Pmod 핀 | 넷 이름 (캐리어) | ZynqMP 패키지 핀 | SOM240_1 |
|---|---|---|---|
| 1 (S1A) | HDA11 | H12 | A17 |
| 2 (S1B) | HDA15 | B10 | B20 |
| 3 (S2A) | HDA12 | E10 | D20 |
| 4 (S2B) | HDA16_CC | E12 | B21 |
| 5 (S3A) | HDA13 | D10 | D21 |
| 6 (S3B) | HDA17 | D11 | B22 |
| 7 (S4A) | HDA14 | C11 | D22 |
| 8 (S4B) | HDA18 | B11 | C22 |
| 5V (J2.9) | — | — | — |
| GND (J2.10/12) | — | — | — |

IOSTANDARD: LVCMOS33, DRIVE: 16 예시. 공급 전류 100mA 제한.

## 부록 B. 교육 검증 기록 (강사용)

| 항목 | 검증일 | 결과 | 비고 |
|---|---|---|---|
| Vivado/Vitis 2022.2 설치 (Win11) | | | |
| 1주차 예제 전량 빌드 | | | |
| 2주차 베어메탈 + DMA | | | |
| Canonical Ubuntu 22.04 부팅 | | | |
| xmutil overlay 로딩 | | | |
| Vitis AI 3.0 DPU 추론 (KV260) | | | |
| 4주차 NPU 레퍼런스 end-to-end | | | |
