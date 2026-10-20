# 호스트 PC 설정 (Vivado / Vitis 2022.2)

대상 OS: **Windows 11 또는 Ubuntu 22.04 LTS** (둘 다 2022.2 공식 지원).

## 1. 디스크·메모리

| 항목 | 최소 | 권장 |
|---|---|---|
| 디스크 여유 | 100GB | 150GB (NVMe) |
| RAM | 16GB | 32GB |

## 2. Vivado ML Edition 2022.2 설치

1. AMD 다운로드 페이지에서 **Vivado ML Edition 2022.2** Unified Installer(Web Installer 또는 SFD)를 받습니다.
   - 제품 선택 화면에서 **Vivado ML Editions → Standard** 선택 (라이선스 파일 불필요)
   - 디자인 도구 전체가 아닌 다음만 선택해도 교육에는 충분합니다:
     - Vivado (Synthesis, Implementation 포함)
     - Zynq UltraScale+ MPSoC 디바이스 지원
     - SDK/Vitis 지원이 포함된 구성 (Vitis 설치 시 vivado 백엔드로 사용)
2. 설치 경로에 **한글·공백·특수문자 금지** (예: `C:\Xilinx\2022.2`).
3. 설치 완료 후 Vivado를 열고 `Help → About`에서 2022.2確認.

라이선스: Standard는 별도 발급 절차가 없습니다. 열기만 하면 됩니다. (2026.1 이상으로 올라가면 BASIC 라이선스 발급이 필요해지므로, 2022.2 교육에서는 이 화면을 볼 일이 없습니다.)

## 3. Vitis 2022.2 설치

1. 동일한 Unified Installer에서 **Vitis** 컴포넌트를 추가 선택합니다. (이미 Vivado 설치에 포함된 인스톨러를 재실행해 추가 가능)
2. 설치 후 `Xilinx Vitis 2022.2` 셸(Windows) 또는 `settings64.sh`(Linux)에서 `vitis` 명령 확인.
3. 4주차 3~4일차는 classic IDE 플로우를 사용합니다. Unified IDE(2024.1 이후 기본)가 표시되면 classic 모드로 진행합니다.

## 4. 파이썬 환경

```
python --version          # 3.8 이상 (3.10 권장)
pip install numpy
```

골든 모델과 보드 제어 스크립트 모두 numpy만 사용합니다 (추가 프레임워크 불필요). 가상환경을 쓰는 경우 이름은 `npu4wk` 권장:

```
python -m venv npu4wk
# Windows: npu4wk\Scripts\activate
# Linux:   source npu4wk/bin/activate
pip install numpy
```

## 5. (선택) Verilator

xsim 50K 인스턴스 제한(2026.1 이후 이야기이고 2022.2에는 없음)과는 무관하지만, 대형 테스트벤치나 무_license 자습용으로 Verilator를 쓰는 팀이 있을 수 있습니다. 공식 실습은 xsim 기준이며, Verilator는 선택입니다.

- Windows: WSL2 Ubuntu에 `sudo apt install verilator`
- Linux: `sudo apt install verilator`

## 6. 검증 체크

```
vivado -version            # Vivado v2022.2
vitis --version            # Vitis 2022.2 (일부 빌드는 -v)
python -c "import numpy; print(numpy.__version__)"
```

Vivado에서 빈 프로젝트를 만들고 `xczu5ev-sfvc784-1-e` (K26 SOM) 디바이스 선택 → Close without saving 까지 동작 확인. KV260용 파트 번호는 Kria 문서의 K26 SOM 기준을 따릅니다 (BSP 선택은 나중에).
