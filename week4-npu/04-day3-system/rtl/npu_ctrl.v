`timescale 1ns / 1ps

module npu_ctrl #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8,
    parameter DATA_W = 8,
    parameter ACC_W = 32,
    parameter N = 4
)(
    input  wire                         S_AXI_ACLK,
    input  wire                         S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire                         S_AXI_AWVALID,
    output reg                          S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                         S_AXI_WVALID,
    output reg                          S_AXI_WREADY,
    output reg  [1:0]                   S_AXI_BRESP,
    output reg                          S_AXI_BVALID,
    input  wire                         S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire                         S_AXI_ARVALID,
    output reg                          S_AXI_ARREADY,
    output reg  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg  [1:0]                   S_AXI_RRESP,
    output reg                          S_AXI_RVALID,
    input  wire                         S_AXI_RREADY,
    output wire                         irq
);

    localparam T_FEED = N + 2*N;

    localparam [1:0] WR_IDLE = 2'd0;
    localparam [1:0] WR_DATA = 2'd1;
    localparam [1:0] WR_RESP = 2'd2;

    localparam [1:0] RD_IDLE = 2'd0;
    localparam [1:0] RD_DATA = 2'd1;

    localparam [2:0] CP_IDLE   = 3'd0;
    localparam [2:0] CP_CLEAR  = 3'd1;
    localparam [2:0] CP_FEED   = 3'd2;
    localparam [2:0] CP_DRAIN  = 3'd3;
    localparam [2:0] CP_RESULT = 3'd4;

    reg [1:0] wr_state;
    reg [1:0] rd_state;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_r;
    reg [C_S_AXI_ADDR_WIDTH-1:0] araddr_r;

    reg [31:0] reg_ctrl;
    reg [31:0] reg_dim;
    reg [31:0] reg_iter;
    reg        start_pulse;
    reg        done_ack;
    reg [31:0] a_row [0:3];
    reg [31:0] w_mat [0:3];
    reg [31:0] c_out [0:15];

    reg [2:0]  cp_state;
    reg [7:0]  feed_t;
    reg [3:0]  drain_t;
    reg        done_r;
    reg        busy_r;
    reg        clear_acc_r;
    reg [N*DATA_W-1:0] a_left_r;
    reg [N*DATA_W-1:0] b_top_r;
    wire [N*N*ACC_W-1:0] acc_flat;

    integer ci;

    assign irq = done_r;

    function [DATA_W-1:0] pick_byte;
        input [31:0] word;
        input integer bidx;
        begin
            pick_byte = word[bidx*8 +: DATA_W];
        end
    endfunction

    systolic_array #(
        .DATA_W(DATA_W),
        .ACC_W (ACC_W),
        .N     (N)
    ) u_array (
        .clk        (S_AXI_ACLK),
        .rst_n      (S_AXI_ARESETN),
        .clear_acc  (clear_acc_r),
        .a_left_flat(a_left_r),
        .b_top_flat (b_top_r),
        .acc_flat   (acc_flat)
    );

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            wr_state     <= WR_IDLE;
            S_AXI_AWREADY <= 1'b1;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            awaddr_r      <= 0;
            rd_state      <= RD_IDLE;
            S_AXI_ARREADY <= 1'b1;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RDATA   <= 32'd0;
            araddr_r      <= 0;
            start_pulse   <= 1'b0;
            done_ack      <= 1'b0;
        end else begin
            start_pulse <= 1'b0;
            done_ack    <= 1'b0;
            case (wr_state)
                WR_IDLE: begin
                    if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                        awaddr_r       <= S_AXI_AWADDR;
                        S_AXI_AWREADY  <= 1'b0;
                        S_AXI_WREADY   <= 1'b1;
                        wr_state       <= WR_DATA;
                    end
                end
                WR_DATA: begin
                    if (S_AXI_WVALID && S_AXI_WREADY) begin
                        S_AXI_WREADY <= 1'b0;
                        S_AXI_BVALID <= 1'b1;
                        S_AXI_BRESP  <= 2'b00;
                        wr_state     <= WR_RESP;
                        case (awaddr_r[7:0])
                            8'h00: begin
                                reg_ctrl <= S_AXI_WDATA;
                                if (S_AXI_WDATA[0])
                                    start_pulse <= 1'b1;
                            end
                            8'h08: reg_dim  <= S_AXI_WDATA;
                            8'h10: a_row[0] <= S_AXI_WDATA;
                            8'h14: a_row[1] <= S_AXI_WDATA;
                            8'h18: a_row[2] <= S_AXI_WDATA;
                            8'h1C: a_row[3] <= S_AXI_WDATA;
                            8'h50: w_mat[0] <= S_AXI_WDATA;
                            8'h54: w_mat[1] <= S_AXI_WDATA;
                            8'h58: w_mat[2] <= S_AXI_WDATA;
                            8'h5C: w_mat[3] <= S_AXI_WDATA;
                            default: ;
                        endcase
                    end
                end
                WR_RESP: begin
                    if (S_AXI_BREADY) begin
                        S_AXI_BVALID  <= 1'b0;
                        S_AXI_AWREADY <= 1'b1;
                        wr_state      <= WR_IDLE;
                    end
                end
                default: wr_state <= WR_IDLE;
            endcase

            case (rd_state)
                RD_IDLE: begin
                    if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                        araddr_r      <= S_AXI_ARADDR;
                        S_AXI_ARREADY <= 1'b0;
                        S_AXI_RVALID  <= 1'b1;
                        S_AXI_RRESP   <= 2'b00;
                        rd_state      <= RD_DATA;
                        case (S_AXI_ARADDR[7:0])
                            8'h00: S_AXI_RDATA <= reg_ctrl;
                            8'h04: begin
                                S_AXI_RDATA <= {30'd0, done_r, busy_r};
                                done_ack    <= 1'b1;
                            end
                            8'h08: S_AXI_RDATA <= reg_dim;
                            8'h0C: S_AXI_RDATA <= reg_iter;
                            8'h10: S_AXI_RDATA <= a_row[0];
                            8'h14: S_AXI_RDATA <= a_row[1];
                            8'h18: S_AXI_RDATA <= a_row[2];
                            8'h1C: S_AXI_RDATA <= a_row[3];
                            8'h50: S_AXI_RDATA <= w_mat[0];
                            8'h54: S_AXI_RDATA <= w_mat[1];
                            8'h58: S_AXI_RDATA <= w_mat[2];
                            8'h5C: S_AXI_RDATA <= w_mat[3];
                            8'h90: S_AXI_RDATA <= c_out[0];
                            8'h94: S_AXI_RDATA <= c_out[1];
                            8'h98: S_AXI_RDATA <= c_out[2];
                            8'h9C: S_AXI_RDATA <= c_out[3];
                            8'hA0: S_AXI_RDATA <= c_out[4];
                            8'hA4: S_AXI_RDATA <= c_out[5];
                            8'hA8: S_AXI_RDATA <= c_out[6];
                            8'hAC: S_AXI_RDATA <= c_out[7];
                            8'hB0: S_AXI_RDATA <= c_out[8];
                            8'hB4: S_AXI_RDATA <= c_out[9];
                            8'hB8: S_AXI_RDATA <= c_out[10];
                            8'hBC: S_AXI_RDATA <= c_out[11];
                            8'hC0: S_AXI_RDATA <= c_out[12];
                            8'hC4: S_AXI_RDATA <= c_out[13];
                            8'hC8: S_AXI_RDATA <= c_out[14];
                            8'hCC: S_AXI_RDATA <= c_out[15];
                            default: S_AXI_RDATA <= 32'hDEADBEEF;
                        endcase
                    end
                end
                RD_DATA: begin
                    if (S_AXI_RREADY) begin
                        S_AXI_RVALID  <= 1'b0;
                        S_AXI_ARREADY <= 1'b1;
                        rd_state      <= RD_IDLE;
                    end
                end
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            cp_state    <= CP_IDLE;
            feed_t      <= 8'd0;
            drain_t     <= 4'd0;
            done_r      <= 1'b0;
            busy_r      <= 1'b0;
            reg_iter    <= 32'd0;
            clear_acc_r <= 1'b0;
            a_left_r    <= {N*DATA_W{1'b0}};
            b_top_r     <= {N*DATA_W{1'b0}};
            for (ci = 0; ci < 16; ci = ci + 1)
                c_out[ci] <= 32'd0;
        end else begin
            if (done_ack)
                done_r <= 1'b0;
            case (cp_state)
                CP_IDLE: begin
                    clear_acc_r <= 1'b0;
                    a_left_r    <= {N*DATA_W{1'b0}};
                    b_top_r     <= {N*DATA_W{1'b0}};
                    if (start_pulse) begin
                        busy_r   <= 1'b1;
                        done_r   <= 1'b0;
                        cp_state <= CP_CLEAR;
                    end
                end
                CP_CLEAR: begin
                    clear_acc_r <= 1'b1;
                    a_left_r    <= {N*DATA_W{1'b0}};
                    b_top_r     <= {N*DATA_W{1'b0}};
                    cp_state    <= CP_FEED;
                    feed_t      <= 8'd0;
                end
                CP_FEED: begin
                    clear_acc_r <= 1'b0;
                    for (ci = 0; ci < N; ci = ci + 1) begin
                        if (($signed({1'b0, feed_t}) - ci >= 0) &&
                            ($signed({1'b0, feed_t}) - ci < N))
                            a_left_r[ci*DATA_W +: DATA_W] <=
                                pick_byte(a_row[ci], $signed({1'b0, feed_t}) - ci);
                        else
                            a_left_r[ci*DATA_W +: DATA_W] <= {DATA_W{1'b0}};
                    end
                    for (ci = 0; ci < N; ci = ci + 1) begin
                        if (($signed({1'b0, feed_t}) - ci >= 0) &&
                            ($signed({1'b0, feed_t}) - ci < N))
                            b_top_r[ci*DATA_W +: DATA_W] <=
                                pick_byte(w_mat[$signed({1'b0, feed_t}) - ci], ci);
                        else
                            b_top_r[ci*DATA_W +: DATA_W] <= {DATA_W{1'b0}};
                    end
                    if (feed_t == T_FEED - 1)
                        cp_state <= CP_DRAIN;
                    else
                        feed_t <= feed_t + 8'd1;
                end
                CP_DRAIN: begin
                    a_left_r <= {N*DATA_W{1'b0}};
                    b_top_r  <= {N*DATA_W{1'b0}};
                    if (drain_t == 4'd7)
                        cp_state <= CP_RESULT;
                    else
                        drain_t <= drain_t + 4'd1;
                end
                CP_RESULT: begin
                    for (ci = 0; ci < 16; ci = ci + 1)
                        c_out[ci] <= acc_flat[ci*ACC_W +: ACC_W];
                    busy_r    <= 1'b0;
                    done_r    <= 1'b1;
                    reg_iter  <= reg_iter + 32'd1;
                    cp_state  <= CP_IDLE;
                end
                default: cp_state <= CP_IDLE;
            endcase
        end
    end

endmodule
