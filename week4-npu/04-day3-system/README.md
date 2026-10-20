# 3일차 — 시스템 통합 (AXI-Lite 제어 + DMA 스트림)

목표: 2일차 어레이를 감싸서 **AXI4-Lite 제어부 + AXI-Stream 데이터 경로**를 가진 NPU 블록으로 만들고, Vivado Block Design에서 AXI DMA와 연결한다.

파일:
- [rtl/npu_ctrl.v](rtl/npu_ctrl.v) — AXI4-Lite 슬레이브 레지스터 + 시작/완료 핸드셰이크 + Systolic Array 인스턴스
- [sim/tb_npu_ctrl.v](sim/tb_npu_ctrl.v) — AXI-Lite 쓰기/읽기로 골든 벡터 검증하는 테스트벤치
- [sim/run_xsim.tcl](sim/run_xsim.tcl) — xsim 일괄 실행

> 스트림 데이터 경로(activation/psum stream 인터페이스)는 `npu_ctrl`과 분리된 `npu_stream_if` 수준으로 설계하는 것을 권장하되, 당일 실습에서는 **레지스터 기반 kick + BRAM 버퍼 경로**를 먼저 구현해 동작을 확정한 뒤, 시간이 남는 팀이 DMA 스트림으로 확장하는 2단계로 진행합니다.

## 레지스터 맵 (AXI4-Lite, word 주소)

| 오프셋 | 이름 | R/W | 설명 |
|---|---|---|---|
| 0x00 | CTRL | W | bit0: START (쓰면 1클럭 pulse), bit1: CLEAR_ACC |
| 0x04 | STATUS | R | bit0: BUSY, bit1: DONE (읽으면 클리어) |
| 0x08 | DIM | R/W | [7:0] K 타일 수 (기본 1 = K4), [15:8] 예약 |
| 0x0C | ITER | R | 완료된 GEMM 반복 횟수 (디버그용) |
| 0x10~0x4C | A_ROW0..3 | R/W | 활성화 4×4 (INT8 4개打包 per word) — 축약 경로 |
| 0x50~0x8C | W_MAT | R/W | 가중치 4×4 (동일) |
| 0x90~0xCC | C_OUT | R | 출력 4×4 INT32 (word당 1개) |

> 교육용 단순화 경로: DMA 없이 PS가 레지스터로 직접 4×4 블록을 주고받는 방식. 4일차 Python에서도 동일 레지스터 맵을 mmap으로 접근하므로 **하드웨어·소프트웨어가 같은 맵으로 학습**됩니다. K=784 타일링은 DIM에 타일 수를 쓰고 START를 반복하는 소프트웨어 루프로 구현합니다.

## Block Design 구성 (KV260, 2022.2)

```
Zynq MPSoC (PS)
  ├─ M_AXI_HPM0_FPD ──► AXI Interconnect ──► npu_ctrl_0 (AXI4-Lite)
  │                                           ├─ BRAM控制器 ──► Block Memory Generator (A/W/C)
  │                                           └─ IRQ ──► PS IRQ_F2P[0]
  └─ (심화) S_AXI_HP0_FPD ◄── AXI DMA ◄── AXI-Stream (npu_stream)
```

### Vivado 수동 수행 순서

1. 새 프로젝트 → Block Design `npu_bd`
2. `Zynq UltraScale+ MPSoC` 추가 → Run Connection Automation (PS 고정 설정)
3. `Create and Package New IP`로 `npu_ctrl` 패키징 후 IP 카탈로그에 추가 → BD에 인스턴스화
4. AXI Interconnect + Automation으로 PS→npu_ctrl AXI4-Lite 연결, 레지스터맵 주소 할당 (자동)
5. BRAM Generator (True Dual Port, 4KB) 추가, npu_ctrl의 BRAM 포트와 연결
6. 인터럽트: npu_ctrl IRQ → PS xlconcat → IRQ_F2P
7. Validate → Generate Block Design → Create HDL Wrapper
8. XSA 추출: File → Export → Export Hardware (include bitstream)

심화 팀: AXI DMA (Simple mode) + AXI Data FIFO + Stream 포트를 추가해 대량 데이터 경로를 만듭니다. DMA는 2주차 실습의 것을 재사용합니다.

## 시스템 시뮬레이션 (Block Design 이전 검증)

BD 구성 전에 `npu_ctrl`이 AXI-Lite로 골든 값을 주고받는지 먼저 RTL 시뮬레이션으로 확인합니다 (2일차 `a.hex/w.hex/ref.hex` 재사용).

```
cd week4-npu/04-day3-system
mkdir -p sim/vectors
copy ..\03-day2-systolic\sim\vectors\* sim\vectors\      # Windows
# cp ../03-day2-systolic/sim/vectors/* sim/vectors/       # Linux

cd sim
vivado -mode batch -source run_xsim.tcl
```

기대 출력: `[PASS] npu_ctrl AXI-Lite register flow matches golden`. 이 검증이 통과하면 이후 BD/베어메탈의 실패는 AXI 연결이나 주소 설정 문제로 좁혀집니다.

> `run_xsim.tcl`은 3일차 rtl과 **2일차 rtl(pe.v, systolic_array.v)**을 함께 컴파일합니다. 어레이 모듈을 복사하지 않고 참조하므로 폴더를 함께 유지하세요.

## 베어메탈 검증 (Vitis 2022.2 classic)

```c
#define NPU_BASE 0xA0000000   /* 주소는 Address Editor 결과에 맞게 */
#define CTRL     (NPU_BASE + 0x00)
#define STATUS   (NPU_BASE + 0x04)
#define C_OUT(i) (NPU_BASE + 0x90 + 4*(i))

Xil_Out32(CTRL, 0x1);              /* START */
while (!(Xil_In32(STATUS) & 0x2)); /* DONE 대기 */
for (int i = 0; i < 16; i++)
    xil_printf("C[%d] = %d\r\n", i, Xil_In32(C_OUT(i)));
```

A/W 레지스터에는 1일차 `a.hex`/`w.hex`와 동일한 값을 채워 넣고, C가 `ref.hex`와 일치하는지 확인합니다.

## 실습 순서 (당일)

| 시간 | 내용 |
|---|---|
| 오전 | `npu_ctrl.v` 읽고 레지스터 맵표와 대조. AXI-Lite 응답 FSM 상태그림 그리기 + `run_xsim.tcl`로 통합 시뮬레이션 PASS 확인 |
| 오전 후반 | Vivado BD 구성 (강사 시연 + 동일 수행). XSA 추출까지 |
| 오후 초반 | Vitis 베어메탈 C로 START/DONE + 결과 판독. 4×4 골든 값 일치 확인 |
| 오후 후반 | DIM 타일 반복으로 K=16 이상 확장 (A/W 레지스터를 반복 채우는 소프트웨어 루프). 남는 팀은 AXI DMA 스트림 경로 심화 |

## 평가 포인트

- 베어메탈에서 C_OUT 16개가 ref와 일치
- 레지스터 맵표를 토대로 Python용 헤더/오프셋 표 작성 제출 (4일차에 사용)
- (심화) DMA 스트림 루프백 동작

## 4일차를 위한 산출물

- XSA + bitstream (강사 공유 폴더에 동일 파일 배포 권장 — 학생 개별 빌드 시간 절감)
- 레지스터 오프셋 최종표 (이 문서 표와 일치해야 함)
