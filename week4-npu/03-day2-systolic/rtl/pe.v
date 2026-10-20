`timescale 1ns / 1ps

module pe #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     clear_acc,
    input  wire signed [DATA_W-1:0] a_in,
    input  wire signed [DATA_W-1:0] b_in,
    output reg  signed [DATA_W-1:0] a_out,
    output reg  signed [DATA_W-1:0] b_out,
    output reg  signed [ACC_W-1:0]  acc
);

    wire signed [2*DATA_W-1:0] prod = a_in * b_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= {DATA_W{1'b0}};
            b_out <= {DATA_W{1'b0}};
            acc   <= {ACC_W{1'b0}};
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            if (clear_acc)
                acc <= prod;
            else
                acc <= acc + prod;
        end
    end

endmodule
