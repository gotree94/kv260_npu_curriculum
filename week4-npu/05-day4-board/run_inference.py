import argparse
import gzip
import os
import struct
import time
import urllib.request

import numpy as np

from npu_mmap import Npu

BASE = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE, "models", "mnist_int8.npz")
DATA_DIR = os.path.join(BASE, "data")

URLS = {
    "train_images": "https://storage.googleapis.com/cvdf-datasets/mnist/train-images-idx3-ubyte.gz",
    "train_labels": "https://storage.googleapis.com/cvdf-datasets/mnist/train-labels-idx1-ubyte.gz",
    "test_images": "https://storage.googleapis.com/cvdf-datasets/mnist/t10k-images-idx3-ubyte.gz",
    "test_labels": "https://storage.googleapis.com/cvdf-datasets/mnist/t10k-labels-idx1-ubyte.gz",
}


def download(name):
    os.makedirs(DATA_DIR, exist_ok=True)
    path = os.path.join(DATA_DIR, name + ".gz")
    if not os.path.exists(path):
        print(f"[INFO] downloading {name} ...")
        urllib.request.urlretrieve(URLS[name], path)
    return path


def load_idx_images(path):
    with gzip.open(path, "rb") as f:
        magic, n, rows, cols = struct.unpack(">IIII", f.read(16))
        data = np.frombuffer(f.read(), dtype=np.uint8)
    return data.reshape(n, rows * cols)


def load_idx_labels(path):
    with gzip.open(path, "rb") as f:
        magic, n = struct.unpack(">II", f.read(8))
        labels = np.frombuffer(f.read(), dtype=np.uint8)
    return labels


def softmax(z):
    z = z - z.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def train_linear(x, y, epochs=8, lr=0.5, batch=128, seed=0):
    rng = np.random.default_rng(seed)
    x = x.astype(np.float32) / 255.0
    w = np.zeros((x.shape[1], 10), dtype=np.float32)
    b = np.zeros(10, dtype=np.float32)
    n = x.shape[0]
    for ep in range(epochs):
        idx = rng.permutation(n)
        for s in range(0, n, batch):
            xb = x[idx[s:s + batch]]
            yb = y[idx[s:s + batch]]
            logits = xb @ w + b
            prob = softmax(logits)
            grad_w = xb.T @ (prob - np.eye(10)[yb]) / xb.shape[0]
            grad_b = (prob - np.eye(10)[yb]).mean(axis=0)
            w -= lr * grad_w
            b -= lr * grad_b
        acc = (softmax(x @ w + b).argmax(1) == y).mean()
        print(f"[INFO] epoch {ep + 1}/{epochs} train_acc={acc:.4f}")
    return w, b


def quantize_int8(x):
    scale = np.float32(np.max(np.abs(x)) / 127.0) if np.max(np.abs(x)) > 0 else np.float32(1.0)
    q = np.clip(np.round(x / scale), -128, 127).astype(np.int8)
    return q, scale


def cmd_train():
    x_tr = load_idx_images(download("train_images"))
    y_tr = load_idx_labels(download("train_labels"))
    x_te = load_idx_images(download("test_images"))
    y_te = load_idx_labels(download("test_labels"))

    print("[INFO] training linear 784->10 ...")
    w, b = train_linear(x_tr, y_tr)

    wq, sw = quantize_int8(w)
    xq_test, sx = quantize_int8(x_te.astype(np.float32))
    bias_scaled = np.round(b / (sx * sw)).astype(np.int32)

    acc = (softmax(x_te.astype(np.float32) / 255.0 @ w + b).argmax(1) == y_te).mean()
    int8_pred = np.zeros(x_te.shape[0], dtype=np.int32)
    x_flat = xq_test.reshape(x_te.shape[0], -1).astype(np.int32)
    scores = x_flat @ wq.astype(np.int32) + bias_scaled
    int8_pred = scores.argmax(1)
    acc_int8 = (int8_pred == y_te).mean()

    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    np.savez(MODEL_PATH, w=wq, sx=np.float32(sx), sw=np.float32(sw),
             bias_scale=bias_scaled, test_labels=y_te,
             test_acc_float=np.float32(acc), test_acc_int8=np.float32(acc_int8))
    print(f"[INFO] float acc={acc:.4f}  int8 acc={acc_int8:.4f}")
    print(f"[INFO] saved {MODEL_PATH}")


def gemm_k_tile(npu, x_row4, w_tile):
    a_rows = [list(x_row4) for _ in range(4)]
    w_rows = [list(w_tile[k]) for k in range(4)]
    return npu.gemm4(a_rows, w_rows)


def cmd_npu(limit):
    if not os.path.exists(MODEL_PATH):
        raise SystemExit("[ERROR] 모델 없음 — 먼저 --train 를 실행하세요")
    m = np.load(MODEL_PATH)
    wq = m["w"].astype(np.int8)
    sx = float(m["sx"])
    sw = float(m["sw"])
    bias = m["bias_scale"].astype(np.int64)
    y_te = m["test_labels"]
    acc_int8_ref = float(m["test_acc_int8"])

    x_te = load_idx_images(download("test_images"))
    if limit and limit < x_te.shape[0]:
        x_te = x_te[:limit]
        y_te = y_te[:limit]

    xq = np.clip(np.round(x_te.astype(np.float32) / sx), -128, 127).astype(np.int8)

    if not os.access("/dev/mem", os.R_OK | os.W_OK):
        raise SystemExit("[ERROR] /dev/mem 접근 불가 — sudo 권한으로 실행하세요")

    npu = Npu()
    print("[INFO] NPU opened")

    hw_pred = []
    numpy_pred = []
    t0 = time.time()
    with npu:
        for s in range(x_te.shape[0]):
            x_i8 = xq[s].astype(np.int32)
            acc_hw = np.zeros(10, dtype=np.int64)
            acc_sw = np.zeros(10, dtype=np.int64)
            for g in range(3):
                n_cols = 2 if g == 2 else 4
                for k0 in range(0, 784, 4):
                    x_tile = x_i8[k0:k0 + 4]
                    w_tile = wq[k0:k0 + 4, g * 4:g * 4 + n_cols]
                    if w_tile.shape[1] < 4:
                        pad = np.zeros((4, 4 - n_cols), dtype=np.int8)
                        w_tile = np.concatenate([w_tile, pad], axis=1)
                    out = gemm_k_tile(npu, x_tile, w_tile)
                    for c in range(n_cols):
                        acc_hw[g * 4 + c] += int(out[0][c])
                        acc_sw[g * 4 + c] += int(
                            x_tile.astype(np.int64) @ wq[k0:k0 + 4, g * 4 + c].astype(np.int64)
                        )
            acc_hw = acc_hw + bias
            acc_sw = acc_sw + bias
            hw_pred.append(int(np.argmax(acc_hw[:10])))
            numpy_pred.append(int(np.argmax(acc_sw[:10])))
    elapsed = time.time() - t0

    hw_pred = np.array(hw_pred)
    numpy_pred = np.array(numpy_pred)
    acc_hw = (hw_pred == y_te).mean()
    acc_np = (numpy_pred == y_te).mean()
    match = (hw_pred == numpy_pred).mean()

    print(f"[RESULT] samples            : {len(y_te)}")
    print(f"[RESULT] numpy INT8 acc     : {acc_np:.4f}")
    print(f"[RESULT] NPU acc            : {acc_hw:.4f}")
    print(f"[RESULT] NPU vs numpy match : {match:.4f}")
    print(f"[RESULT] total time         : {elapsed:.3f} s  ({elapsed / len(y_te) * 1000:.2f} ms/img)")
    macs = 784 * 10
    print(f"[RESULT] GOPS               : {2 * macs * len(y_te) / elapsed / 1e9:.3f}")
    if acc_int8_ref == acc_int8_ref:
        print(f"[RESULT] saved int8 acc(ref): {acc_int8_ref:.4f}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--train", action="store_true")
    ap.add_argument("--npu", action="store_true")
    ap.add_argument("--limit", type=int, default=100, help="추론 샘플 수 (0=전체)")
    args = ap.parse_args()
    if args.train:
        cmd_train()
    elif args.npu:
        cmd_npu(None if args.limit == 0 else args.limit)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
