import argparse
import mmap
import os
import random
import struct
import time

NPU_BASE = 0xA0000000
NPU_SIZE = 0x1000

REG_CTRL = 0x00
REG_STATUS = 0x04
REG_DIM = 0x08
REG_ITER = 0x0C
REG_A_BASE = 0x10
REG_W_BASE = 0x50
REG_C_BASE = 0x90

CTRL_START = 0x1
STATUS_BUSY = 0x1
STATUS_DONE = 0x2

PAGE_SIZE = 4096


class Npu:
    def __init__(self, base=NPU_BASE, devmem="/dev/mem", timeout_s=1.0):
        if base % PAGE_SIZE:
            raise ValueError("base must be page aligned")
        self.base = base
        self.timeout_s = timeout_s
        fd = os.open(devmem, os.O_RDWR | os.O_SYNC)
        try:
            self.mem = mmap.mmap(fd, NPU_SIZE, mmap.MAP_SHARED,
                                 mmap.PROT_READ | mmap.PROT_WRITE,
                                 offset=base)
        finally:
            os.close(fd)

    def close(self):
        self.mem.close()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def rd32(self, off):
        return struct.unpack_from("<I", self.mem, off)[0]

    def wr32(self, off, val):
        struct.pack_into("<I", self.mem, off, val & 0xFFFFFFFF)

    @staticmethod
    def pack_row(values):
        if len(values) != 4:
            raise ValueError("need 4 int8 values")
        word = 0
        for i, v in enumerate(values):
            v = int(v)
            if not -128 <= v <= 127:
                raise ValueError(f"int8 overflow: {v}")
            word |= (v & 0xFF) << (8 * i)
        return word

    @staticmethod
    def unpack_word(word, signed=True):
        out = []
        for i in range(4):
            b = (word >> (8 * i)) & 0xFF
            out.append(b - 256 if signed and b >= 128 else b)
        return out

    def gemm4(self, a_rows, w_rows):
        if len(a_rows) != 4 or len(w_rows) != 4:
            raise ValueError("need 4x4 A and 4x4 W (rows as int8 lists)")
        for i in range(4):
            self.wr32(REG_A_BASE + 4 * i, self.pack_row(a_rows[i]))
        for k in range(4):
            self.wr32(REG_W_BASE + 4 * k, self.pack_row(w_rows[k]))
        self.wr32(REG_CTRL, CTRL_START)
        deadline = time.time() + self.timeout_s
        while True:
            st = self.rd32(REG_STATUS)
            if st & STATUS_DONE:
                break
            if time.time() > deadline:
                raise TimeoutError(f"STATUS busy timeout: 0x{st:08x}")
            if not (st & STATUS_BUSY):
                time.sleep(0.0001)
        out = []
        for i in range(4):
            row = []
            for j in range(4):
                row.append(struct.unpack_from("<i", self.mem, REG_C_BASE + 4 * (i * 4 + j))[0])
            out.append(row)
        return out

    def iter_count(self):
        return self.rd32(REG_ITER)


def numpy_gemm(a_rows, w_rows):
    a = [[int(v) for v in row] for row in a_rows]
    w = [[int(v) for v in row] for row in w_rows]
    c = [[0] * 4 for _ in range(4)]
    for i in range(4):
        for j in range(4):
            acc = 0
            for k in range(4):
                acc += a[i][k] * w[k][j]
            c[i][j] = acc
    return c


def selftest(n=20, base=NPU_BASE):
    random.seed(7)
    with Npu(base=base) as npu:
        print(f"[INFO] NPU base=0x{base:08X}")
        print(f"[TEST] random 4x4 GEMM x {n}")
        ok = 0
        for t in range(n):
            a = [[random.randint(-128, 127) for _ in range(4)] for _ in range(4)]
            w = [[random.randint(-128, 127) for _ in range(4)] for _ in range(4)]
            ref = numpy_gemm(a, w)
            got = npu.gemm4(a, w)
            if got == ref:
                ok += 1
            else:
                print(f"[FAIL] case {t}")
                print("  got:", got)
                print("  ref:", ref)
        print(f"[{'PASS' if ok == n else 'FAIL'}] {ok}/{n} match numpy int32 reference")
        print(f"[INFO] ITER counter = {npu.iter_count()}")
        return ok == n


def main():
    global NPU_BASE
    ap = argparse.ArgumentParser(description="KV260 NPU /dev/mem self test")
    ap.add_argument("-n", "--num", type=int, default=20)
    ap.add_argument("--base", type=lambda x: int(x, 0), default=NPU_BASE)
    args = ap.parse_args()
    NPU_BASE = args.base
    if not os.access("/dev/mem", os.R_OK | os.W_OK):
        raise SystemExit("[ERROR] /dev/mem 접근 불가 — sudo 권한으로 실행하세요")
    raise SystemExit(0 if selftest(args.num, base=args.base) else 1)


if __name__ == "__main__":
    main()
