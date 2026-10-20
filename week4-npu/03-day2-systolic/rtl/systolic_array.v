`timescale 1ns / 1ps

module systolic_array #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter N      = 4
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        clear_acc,
    input  wire [N*DATA_W-1:0]         a_left_flat,
    input  wire [N*DATA_W-1:0]         b_top_flat,
    output wire [N*N*ACC_W-1:0]        acc_flat
);

    wire signed [DATA_W-1:0] a_wire [0:N][0:N];
    wire signed [DATA_W-1:0] b_wire [0:N][0:N];
    wire signed [ACC_W-1:0]  acc_wire [0:N-1][0:N-1];

    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : g_row
            for (gj = 0; gj < N; gj = gj + 1) begin : g_col
                pe #(
                    .DATA_W(DATA_W),
                    .ACC_W (ACC_W)
                ) u_pe (
                    .clk      (clk),
                    .rst_n    (rst_n),
                    .clear_acc(clear_acc),
                    .a_in     (a_wire[gi][gj]),
                    .b_in     (b_wire[gi][gj]),
                    .a_out    (a_wire[gi][gj+1]),
                    .b_out    (b_wire[gi+1][gj]),
                    .acc      (acc_wire[gi][gj])
                );
                assign acc_flat[((gi*N+gj)*ACC_W) +: ACC_W] = acc_wire[gi][gj];
            end
        end
    endgenerate

    genvar sk;
    generate
        for (sk = 0; sk < N; sk = sk + 1) begin : g_edge
            assign a_wire[sk][0] = a_left_flat[sk*DATA_W +: DATA_W];
            assign b_wire[0][sk] = b_top_flat[sk*DATA_W +: DATA_W];
        end
    endgenerate

endmodule
