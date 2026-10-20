# Vitis AI 3.0 도커 환경 (DPU 비교 시연용)

5일차 DPU 비교 시연 전용입니다. **학생 전체 PC에는 설치하지 않고** 강사 PC 또는 공용 PC 1~2대에만 준비합니다. 기준 조합: **Vitis AI 3.0 ↔ Vivado/PetaLinux 2022.2 ↔ DPUCZDX8G 4.1**.

## 1. 요구사항

| 항목 | 값 |
|---|---|
| OS | Ubuntu 20.04/22.04 LTS |
| 디스크 | 도커 이미지 + 워크스페이스 100GB 이상 |
| RAM | 32GB 권장 |
| Docker | 20.10 이상 |

```
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker $USER   # 재로그인 필요
docker --version
```

## 2. 도커 이미지 받기

```
git clone https://github.com/Xilinx/Vitis-AI.git -b v3.0
cd Vitis-AI
docker pull xilinx/vitis-ai-cpu:3.0
```

실행:

```
./docker_run.sh xilinx/vitis-ai-cpu:3.0
# 컨테이너 안:
conda activate vitis-ai-pytorch
python -c "import pytorch; print('ok')"
```

(3.0 기준 conda 환경 이름은 `vitis-ai-pytorch`, `vitis-ai-tensorflow` 등이 있습니다. 설치된 목록은 `conda env list`로 확인.)

## 3. KV260 DPU 하드웨어 (사전 빌드)

시연용 bitstream은 교육 중에 만들지 않고 **사전 빌드**합니다.

1. Vitis AI 저장소의 Zynq MPSoC DPU 프로젝트(또는 AMD 공지의 KV260 DPU 튜토리얼)에서 **DPUCZDX8G, arch B512** 구성을 선택합니다. B512가 자원·구현 시간 면에서 교육용 시연에 적합합니다.
2. Vivado 2022.2로 DPU + Zynq MPSoC Block Design 빌드 → XSA 추출.
3. PetaLinux 2022.2(또는 Canonical Ubuntu + 커널 패키지)로 DPU 드라이버(xrnn)가 포함된 커널/모듈 준비.
4. KV260 Ubuntu 타겟에 firmware 패키지(xmutil용)로 설치하고 `xmutil listapps`에 나타나는지 확인.

> 시연 당일 빌드는 금지. bitstream, xmodel, 타겟 패키지는 전부 사전에 검증 완료 상태로 복사해 둡니다.

## 4. 모델 준비 (ResNet18 또는 MNIST)

컨테이너 안에서 (예: PyTorch ResNet18):

```
conda activate vitis-ai-pytorch
cd /workspace
# 1) 부동소수점 모델 확보 (torchvision 등)
# 2) 양자화
vai_q_pytorch   # 워크플로우는 3.0 문서(UG1414 v3.0)의 calib/eval 순서를 따름
# 3) 컨테이너 종료 후 호스트에서 그래프 변환·컴파일
vai_c_xir -x quantized/ResNet_int.xmodel \
          -a /opt/vitis_ai/compiler/arch/DPUCZDX8G/KV260/arch.json \
          -n resnet18_kv260_b512 \
          -o ./deploy
```

산출물: `deploy/resnet18_kv260_b512.xmodel`.

MNIST 소형 모델을 쓰는 경우도 동일한 vai_q → vai_c_xir 흐름이며, 커리큘럼의 직접 설계 NPU와 동일한 모델(784→10 또는 784→64→10, INT8)을 쓰면 비교가 공정합니다.

## 5. 타겟 추론 (시연 순서)

1. KV260에 사전 준비한 DPU 펌웨어 로드: `xmutil load_accelulator <앱명>` (오타 주의: load_accelerator)
2. 호스트에서 xmodel을 타겟으로 복사 (scp).
3. 타겟에서 VART 예제 실행 (3.0 기준):

```
sudo xmutil load_accelerator dpuKV260
xmutil listapps
# VART 런타임이 설치된 타겟 이미지 기준:
./resnet18_app /path/to/images
# 또는 Python vart API 예제
```

4. 추론 ms/FPS를 기록해 두고 5일차 비교표에 입력.

## 6. 검증 체크

- [ ] 도커 이미지 pull 및 conda activate 성공
- [ ] 사전 빌드 DPU bitstream으로 KV260 부팅, `xmutil listapps`에 DPU 앱 표시
- [ ] `xmutil load_accelerator` 후 `/dev/dri` 또는 xrnn 디바이스 노드 확인
- [ ] xmodel 추론 1회 성공, FPS 기록
- [ ] 네트워크 카메라 등 부가 요소 없이 라이트 추론만으로 10분 이내 시연 가능
