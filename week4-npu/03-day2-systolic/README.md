# 2일차 — PE와 4×4 Systolic Array

목표: 출력 정적(output-stationary) 4×4 Systolic Array를 RTL로 작성하고, 1일차 골든 벡터와 비교해 xsim에서 PASS를 확인한다.

파일:

| 파일 | 내용 |
|---|---|
| [rtl/pe.v](rtl/pe.v) | 출력 정적 MAC PE (INT8×INT8 → INT32) |
| [rtl/systolic_array.v](rtl/systolic_array.v) | 4×4 PE 어레이 (파라미터 N) |
| [sim/tb_systolic.v](sim/tb_systolic.v) | hex 벡터 비교 테스트벤치 |
| [sim/run_xsim.tcl](sim/run_xsim.tcl) | xsim 일괄 실행 스크립트 |

## 데이터플로 (출력 정적)

```
        b_top[j] (가중치 W[k][j], 위에서 아래로)
            ↓
a_left[i] → [PE(i,j)] → a_right      (활성화 A[i][k], 왼 → 오)
            ↓
           psum_down                  (이 어레이에서는 acc가 PE 안에 고정)
```

- PE(i,j)는 자신의 누적기 `acc`에 `A[i][k] * W[k][j]`를 k=0..K-1 동안 누적합니다.
- 활성화는 왼→오, 가중치는 위→아래로 **스큐(skew)**를 두고 흘려보냅니다 (i행은 i클럭 지연, j열은 j클럭 지연).
- K 사이클이 어레이 안을 모두 통과한 뒤, 각 PE의 `acc`가 C[i][j]가 됩니다.
- 교육용 단순화: **K = N = 4** (한 번의 clear → 통과 → 판독). K>4는 3일차에서 타일링/반복 누적으로 확장합니다.

## 실습 순서

### 실습 2-1. 벡터 복사

```
cd week4-npu/03-day2-systolic
mkdir -p sim/vectors
copy ..\02-day1-golden-model\vectors\* sim\vectors\     # Windows
# cp ../02-day1-golden-model/vectors/* sim/vectors/     # Linux
```

### 실습 2-2. RTL 읽기 (30분)

1. `pe.v`: 3개 출력(a_out, b_out, acc)과 clear_acc 동작을 파형으로 종이에 그리기.
2. `systolic_array.v`: 인스턴스 배치와 좌우/상하 연결 확인.

### 실습 2-3. 시뮬레이션 실행 (30분)

```
cd sim
vivado -mode batch -source run_xsim.tcl
```

또는 Vivado GUI에서 xsim 프로젝트를 직접 만들어도 됩니다. 기대 출력:

```
[INFO] Loaded A 4x4, W 4x4, REF 4x4
[INFO] Cycle 0..: feed skewed data
[PASS] all 16 outputs match reference (int32)
```

### 실습 2-4. 실험 (과제)

1. `tb_systolic.v`에서 skew를 제거하면(모든 행/열에 동시 입력) 무엇이 깨지는지 관찰하고, PE 파형으로 설명.
2. `N`을 8로 바꾸고 `gen_vectors.py`의 M=K=N=8 케이스 벡터로 재검증 (Python에서 `M=K=N=8`로 수정 후 생성).
3. `clear_acc`를 누락하면 결과가 어떻게 달라지는지 확인.

## 자주 나오는 오류

| 증상 | 원인 |
|---|---|
| 하위 2바이트만 맞고 상위가 이상함 | acc가 아니라 prod만 비교 중, 또는 signed 캐스트 누락 |
| 대각선 방향으로만 정답 | skew 방향(a는 i 지연, b는 j 지연) 잘못됨 |
| 첫 PE만 정답 | clear_acc 타이밍 또는 어레이 상하 연결 오타 |
| xsim에서 파일 못 찾음 | working dir가 `sim/`이 아닐 때 (run_xsim.tcl 기준은 sim/) |

## 평가 포인트

- `[PASS] all 16 outputs match` 출력
- N=8 확장 과제 제출 (선택)
- skew 설명 구술 또는 짧은 리포트
