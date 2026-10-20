# 1일차 — INT8 골든 모델

목표: NumPy로 INT8 GEMM 골든 모델을 만들고, 2일차 RTL 시뮬레이션에 쓸 벡터 파일(`a.hex`, `w.hex`, `ref.hex`)을 생성한다.

파일:
- [golden_int8_gemm.py](golden_int8_gemm.py) — 정수 연산 골든 모델
- [gen_vectors.py](gen_vectors.py) — RTL TB용 hex 벡터 생성

## 배경 정리 (오전 이론 요약)

### GEMM을 NPU가 하는 일로

신경망의 FC/Conv는 결국 `C = A × B` 행렬곱입니다. NPU는 여기를 다음으로 분해합니다.

```
A: 활성화 [M × K]   (INT8)
B: 가중치 [K × N]   (INT8)
C: 출력   [M × N]   (INT32 누적 → 스케일로 INT8 재양자화)
```

4×4 어레이에서는 M, N을 4의 배수로 타일링해 한 번에 4×4 출력 블록을 계산합니다. K(수렴 차원)는 타일을 쌓아 올립니다.

### INT8 골든 모델 규칙 (RTL과 반드시 동일해야 함)

| 항목 | 규칙 |
|---|---|
| 입력 정수화 | `q = clamp(round(x / scale), -128, 127)` |
| 곱셈 | INT8 × INT8 → INT32 (부호 있는 2의 보수) |
| 누적 | INT32 더하기 (오버플로 주의: K 최대값 × 128² < 2³¹ 이면 안전) |
| 재양자화 | `y_i8 = clamp(round(y_i32 * (sa*sb/sc)), -128, 127)` |

1일차에는 **정수 입력만** 다룹니다. 부동소수점→INT8 변환(scale 계산)은 NumPy 골든에서 첨부하고, 학생은 정수 경로 검증에 집중합니다.

## 실습 순서

### 실습 1-1. 골든 모델 실행 (30분)

```
cd week4-npu/02-day1-golden-model
python golden_int8_gemm.py
```

기대 출력: `PASS 8/8 cases` (임의 테스트 8건 모두 일치). 내부적으로 Python int(가변 정밀)로 순수 정수 연산 후 INT32 캐스트 결과를 비교합니다.

### 실습 1-2. 벡터 파일 생성 (30분)

```
python gen_vectors.py
```

생성 파일:

| 파일 | 형식 | 내용 |
|---|---|---|
| `a.hex` | 1 byte/줄 (2 hex) | 활성화 A[4×4], row-major |
| `w.hex` | 1 byte/줄 | 가중치 B[4×4], row-major (K×N) |
| `ref.hex` | 4 byte/줄 (8 hex, little-endian word) | 기대 출력 C[4×4], INT32 |
| `vectors_meta.txt` | 텍스트 | M=N=K=4, scale 정보 |

이 파일들이 2일차 xsim 테스트벤치의 `$readmemh` 입력이 됩니다. **같은 seed로 항상 같은 결과**가 나오므로 조별로 파일이 달라도 골든 비교는 문제없습니다.

### 실습 1-3. 타일링 스케치 (과제, 오후)

784×10 FC(MNIST 마지막 층)를 4×4 어레이로 계산할 때:

- 몇 개의 (M,N) 타일이 필요한가? → `ceil(10/4) × ceil(784/4)` 가 아니라, 보통 M=출력 뉴런, K=784로 잡고 N 방향(출력)만 타일링하거나, 어레이를 K 방향으로 스트리밍합니다.
- 본 과정에서는 **A를 [4 × K] 블록으로, B를 [K × 4] 블록으로** 잘라 한 사이클 세션에 4×4 출력을 만드는 방식을 채택합니다. K=784면 세션 784회(또는 파이프라인으로 중복) 누적합니다.
- 종이에 K=784, N=10인 경우의 타일 수와 DMA 전송 횟수를 적어 제출.

## 평가 포인트

- 골든 모델이 `PASS`를 출력하는가
- hex 파일 3종이 생성되는가
- 타일링 스케치 제출 (K=784, N=10)

## 다음 날 준비

- 생성한 `a.hex`, `w.hex`, `ref.hex`를 `03-day2-systolic/sim/vectors/`로 복사해 둡니다.
- `03-day2-systolic/README.md`를 미리 읽어 두세요.
