import os
import numpy as np

M = 4
K = 4
N = 4
SEED = 42
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vectors")


def to_signed_hex8(v):
    return [f"{(int(x) & 0xFF):02x}" for x in np.asarray(v).reshape(-1)]


def to_signed_hex32(v):
    lines = []
    for x in np.asarray(v).reshape(-1):
        lines.append(f"{(int(np.int32(x)) & 0xFFFFFFFF):08x}")
    return lines


def main():
    rng = np.random.default_rng(SEED)
    a = rng.integers(-128, 127, size=(M, K), dtype=np.int8)
    w = rng.integers(-128, 127, size=(K, N), dtype=np.int8)

    c = a.astype(np.int32) @ w.astype(np.int32)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "a.hex"), "w") as f:
        f.write("\n".join(to_signed_hex8(a)) + "\n")
    with open(os.path.join(OUT_DIR, "w.hex"), "w") as f:
        f.write("\n".join(to_signed_hex8(w)) + "\n")
    with open(os.path.join(OUT_DIR, "ref.hex"), "w") as f:
        f.write("\n".join(to_signed_hex32(c)) + "\n")
    with open(os.path.join(OUT_DIR, "vectors_meta.txt"), "w") as f:
        f.write(f"M={M}\nK={K}\nN={N}\nseed={SEED}\nlayout=a_row_major,w_kx_n,c_row_major\n")

    print(f"wrote vectors to {OUT_DIR}")
    print("A=\n", a)
    print("W=\n", w)
    print("C=\n", c)


if __name__ == "__main__":
    main()
