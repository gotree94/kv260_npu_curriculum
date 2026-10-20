import numpy as np


def quantize_int8(x, scale):
    q = np.round(x / scale)
    return np.clip(q, -128, 127).astype(np.int8)


def dequantize(q, scale):
    return q.astype(np.float32) * scale


def gemm_int8(a_i8, w_i8):
    a32 = a_i8.astype(np.int32)
    w32 = w_i8.astype(np.int32)
    c32 = a32 @ w32
    return c32.astype(np.int32)


def requantize_int8(c32, scale_a, scale_w, scale_c):
    mult = (scale_a * scale_w) / scale_c
    q = np.round(c32.astype(np.float64) * mult)
    return np.clip(q, -128, 127).astype(np.int8)


def run_case(seed, m, k, n):
    rng = np.random.default_rng(seed)
    x = rng.normal(0, 1, size=(m, k)).astype(np.float32)
    w = rng.normal(0, 0.5, size=(k, n)).astype(np.float32)

    scale_x = np.float32(np.max(np.abs(x)) / 127.0)
    scale_w = np.float32(np.max(np.abs(w)) / 127.0)

    xq = quantize_int8(x, scale_x)
    wq = quantize_int8(w, scale_w)

    ref_python = gemm_int8(xq, wq)

    x32 = xq.astype(np.int32)
    w32 = wq.astype(np.int32)
    ref_manual = np.zeros((m, n), dtype=np.int32)
    for i in range(m):
        for j in range(n):
            acc = 0
            for kk in range(k):
                acc += int(x32[i, kk]) * int(w32[kk, j])
            ref_manual[i, j] = np.int32(acc)

    if not np.array_equal(ref_python, ref_manual):
        return False, "int mismatch between matmul and loop"

    if ref_python.max() >= 2**31 or ref_python.min() < -(2**31):
        return False, "int32 overflow"

    scale_c = np.float32(scale_x * scale_w)
    yq = requantize_int8(ref_python, scale_x, scale_w, scale_c)

    y_float = ref_python.astype(np.float32) * scale_c
    x_f = dequantize(xq, scale_x)
    w_f = dequantize(wq, scale_w)
    err = np.max(np.abs(y_float - x_f @ w_f))
    tol = np.max(np.abs(x_f @ w_f)) * 0.02 + 1e-6
    if err > tol:
        return False, f"dequant error {err} > {tol}"

    _ = yq
    return True, "ok"


def main():
    cases = [
        (1, 4, 4, 4),
        (2, 4, 8, 4),
        (3, 4, 16, 4),
        (4, 4, 64, 4),
        (5, 4, 256, 4),
        (6, 4, 784, 4),
        (7, 8, 8, 8),
        (8, 4, 784, 10),
    ]
    passed = 0
    for seed, m, k, n in cases:
        ok, msg = run_case(seed, m, k, n)
        status = "PASS" if ok else "FAIL"
        print(f"[{status}] seed={seed} M={m} K={k} N={n} ({msg})")
        passed += int(ok)
    print(f"{passed}/{len(cases)} cases")
    if passed != len(cases):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
