# 4일차 — 보드 구현과 Linux 추론

목표: 3일차 bitstream을 KV260 Ubuntu에 로드하고, Python mmap으로 NPU를 제어해 4×4 GEMM을 검증한 뒤, 학습한 MNIST 분류기를 NPU로 추론한다.

파일:
- [npu_mmap.py](npu_mmap.py) — /dev/mem 기반 AXI-Lite 레지스터 드라이버
- [run_inference.py](run_inference.py) — MNIST 학습·양자화·NPU 추론 파이프라인

## 1. 하드웨어 구성 (오전, 강사 시연 후 학생 동일 수행)

### 1-1. Bitstream 준비

Vivado 2022.2에서 3일차 Block Design 프로젝트:
1. Synthesis → Implementation → Generate Bitstream
2. **주소 확인 필수**: Block Design의 Address Editor에서 `npu_ctrl` base address를 기록 (예: `0xA0000000`). 아래 스크립트의 `NPU_BASE`와 일치해야 합니다.

### 1-2. Kria firmware 패키지 구성

KV260은 `xmutil`로 PL 애플리케이션을 동적 로딩합니다. 앱 디렉터리 구성 예시:

```
npu_app/
├── shell.json
├── npu.dtbo          (Device Tree Overlay)
└── npu.bit.bin       (bitstream 변환본)
```

shell.json 예시:

```json
{
  "shell": {
    "shell_name": "npu_edu",
    "app_src": ["/lib/firmware/npu_app"],
    "dtbo": "npu.dtbo",
    "bit": "npu.bit.bin"
  }
}
```

명세에 맞는 변환·배치:

```
# bitstream을 .bit.bin으로 (비트 스왑 포함 여부는 Kria 문서의 bootgen/petalinux flow 기준 따름)
# dtbo는 다음 dt編譯으로 생성:
dtc -@ -I dts -O dtb -o npu.dtbo npu.dts
sudo cp -r npu_app /lib/firmware/
sudo xmutil load_accelerator npu_edu
xmutil listapps        # npu_edu 가 Loaded 상태인지 확인
```

> 강사 팁: `npu.dts`는 3일차 XSA의 PS 구성에서 export한 DTS에 axi-lite 노드만 추가하는 방식이 가장 안전합니다. **강사가 만든 검증된 패키지 zip을 학생에게 배포**하고, 학생은 구성 변경이 아닌 배포·로드 실습만 합니다 (시간 절감 + 호환 리스크 제거).

### 1-3. 유효성 확인

```
sudo devmem 0xA0000000    # CTRL 레지스터 0 읽힘 확인 (도구: apt install devmem2 또는 busybox devmem)
```

## 2. Python mmap GEMM 검증 (오후 초반)

```
cd week4-npu/05-day4-board
python3 npu_mmap.py
```

기대 출력:

```
[INFO] NPU base=0xA0000000
[TEST] random 4x4 GEMM x 20
[PASS] 20/20 match numpy int32 reference
```

내부 동작: 랜덤 INT8 A/W 생성 → 레지스터 쓰기 → START → DONE 폴링 → C 읽기 → numpy `astype(int32)` 곱과 비교.

**레지스터 맵** (3일차 표와 동일해야 함):

| 오프셋 | 이름 |
|---|---|
| 0x00 | CTRL (bit0 START) |
| 0x04 | STATUS (bit0 BUSY, bit1 DONE / 읽으면 클리어) |
| 0x10~0x1C | A_ROW0..3 (행당 INT8 4개 packed, LE) |
| 0x50~0x5C | W_MAT0..3 (W의 k행 1개씩) |
| 0x90~0xCC | C_OUT0..15 (INT32) |

## 3. MNIST 추론 (오후)

```
python3 run_inference.py --train        # 최초 1회: MNIST 다운로드 + 선형분류기 학습 + 양자화 저장
python3 run_inference.py --npu          # numpy INT8 레퍼런스 vs NPU 추론 비교
```

### 파이프라인 개요

```
MNIST train (float) → 소프트맥스 선형모델 학습 (numpy, 784→10)
   → INT8 양자화 (xq, wq, scale) → models/mnist_int8.npz 저장
   → numpy INT8 정확률 (골든)
   → NPU 추론 정확률 (실제 하드웨어)
   → 두 결과가 같은 예측 비율(일치율) + 정확률 리포트
```

### NPU 매핑 방식 (실습 노트에 포함)

FC `Y[10] = X[784] × W[784×10]`을 4×4 어레이로 돌리기 위해:

- **K 타일링**: K=784를 K=4 구간으로 196조각. 각 조각마다 START 1회.
- **행 복제**: 어레이 M=4 행에 같은 X 조각을 복제 넣어 → 모든 행이 동일한 부분합(4개 출력)을 계산. 소프트웨어가 196회 부분합을 누적.
- **출력 타일**: N=10을 4씩 묶어 3그룹 (4+4+2). 총 START 횟수 ≈ 196 × 3 = 588회 → 100MHz 기준 수 ms 수준.
- 마지막 그룹은 출력 2개만 유효 (나머지 폐기).

이 매핑이 바로 3일차 과제("K=784 타일 수와 전송 횟수")의 정답입니다.

### 기대 결과

- numpy INT8 정확률: 약 88~92% (학습 설정에 따라)
- NPU 예측 일치율 vs numpy INT8: **100%** (같은 정수 연산이므로)
- 부동소수점 대비 약간 낮은 정확률은 양자화 손실로 설명

## 4. 성능·자원 기록 (5일차 준비물)

| 항목 | 측정 방법 | 기록 |
|---|---|---|
| 추론 1건 시간 | `run_inference.py --npu`의 wall time / 추론 횟수 | |
| 클럭 | `cat /sys/class/fpga_manager/fpga*/flags` 및 타이밍 리포트 fmax | |
| GOPS | `(2 × MAC 횟수) / 추론시간` = `2 × (784×10) / t` | |
| 자원 | Vivado Utilization Report: LUT/FF/DSP/BRAM | |
| 전력 (선택) | USB 전력계 idle vs 추론 | |

## 평가 포인트

- [ ] `npu_mmap.py` 20/20 PASS
- [ ] `run_inference.py --npu` 실행, 정확률·일치율 표 출력
- [ ] 성능 표를 5일차 보고서용으로 채워 제출
- [ ] START 588회 타일링 로직을 그림으로 설명 (제출)
