`timescale 1ns / 1ps

module tb_systolic;

    localparam N      = 4;
    localparam K      = 4;
    localparam DATA_W = 8;
    localparam ACC_W  = 32;
    localparam integer T_FEED = K + 2*N;
    localparam integer T_DONE = T_FEED + N + 8;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg clear_acc = 1'b1;
    reg [N*DATA_W-1:0] a_left = {N*DATA_W{1'b0}};
    reg [N*DATA_W-1:0] b_top  = {N*DATA_W{1'b0}};
    wire [N*N*ACC_W-1:0] acc_flat;

    systolic_array #(
        .DATA_W(DATA_W),
        .ACC_W (ACC_W),
        .N     (N)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .clear_acc  (clear_acc),
        .a_left_flat(a_left),
        .b_top_flat (b_top),
        .acc_flat   (acc_flat)
    );

    always #5 clk = ~clk;

    reg signed [DATA_W-1:0] a_mem [0:N*K-1];
    reg signed [DATA_W-1:0] w_mem [0:K*N-1];
    reg signed [ACC_W-1:0]  ref_mem [0:N*N-1];

    integer errors;
    integer t;
    integer i;
    integer j;
    integer k_idx;
    integer idx;
    reg signed [ACC_W-1:0] got;
    reg signed [ACC_W-1:0] exp;

    initial begin
        $readmemh("vectors/a.hex", a_mem);
        $readmemh("vectors/w.hex", w_mem);
        $readmemh("vectors/ref.hex", ref_mem);
        $display("[INFO] Loaded A %0dx%0d, W %0dx%0d, REF %0dx%0d", N, K, K, N, N, N);

        errors = 0;
        rst_n = 1'b0;
        clear_acc = 1'b1;
        a_left = {N*DATA_W{1'b0}};
        b_top  = {N*DATA_W{1'b0}};
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        clear_acc = 1'b0;

        for (t = 0; t < T_DONE; t = t + 1) begin
            @(negedge clk);

            if (t < T_FEED) begin
                for (i = 0; i < N; i = i + 1) begin
                    k_idx = t - i;
                    if (k_idx >= 0 && k_idx < K)
                        a_left[i*DATA_W +: DATA_W] = a_mem[i*K + k_idx];
                    else
                        a_left[i*DATA_W +: DATA_W] = {DATA_W{1'b0}};
                end

                for (j = 0; j < N; j = j + 1) begin
                    k_idx = t - j;
                    if (k_idx >= 0 && k_idx < K)
                        b_top[j*DATA_W +: DATA_W] = w_mem[k_idx*N + j];
                    else
                        b_top[j*DATA_W +: DATA_W] = {DATA_W{1'b0}};
                end
            end else begin
                a_left = {N*DATA_W{1'b0}};
                b_top  = {N*DATA_W{1'b0}};
            end
        end

        @(negedge clk);
        a_left = {N*DATA_W{1'b0}};
        b_top  = {N*DATA_W{1'b0}};
        repeat (4) @(posedge clk);
        @(negedge clk);

        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                idx = i*N + j;
                got = acc_flat[idx*ACC_W +: ACC_W];
                exp = ref_mem[idx];
                if (got !== exp) begin
                    errors = errors + 1;
                    $display("[FAIL] C[%0d][%0d] got=%0d exp=%0d", i, j, got, exp);
                end else begin
                    $display("[ OK ] C[%0d][%0d] = %0d", i, j, got);
                end
            end
        end

        if (errors == 0)
            $display("[PASS] all %0d outputs match reference (int32)", N*N);
        else
            $display("[FAIL] %0d / %0d mismatches", errors, N*N);

        $finish;
    end

endmodule
