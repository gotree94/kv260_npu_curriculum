`timescale 1ns / 1ps

module tb_npu_ctrl;

    localparam DATA_W  = 8;
    localparam ACC_W   = 32;
    localparam N       = 4;
    localparam AW      = 8;
    localparam DW      = 32;

    reg clk = 1'b0;
    reg rst_n = 1'b0;

    reg  [AW-1:0] awaddr = 0;
    reg           awvalid = 0;
    wire          awready;
    reg  [DW-1:0] wdata = 0;
    reg           wvalid = 0;
    wire          wready;
    wire [1:0]    bresp;
    wire          bvalid;
    reg           bready = 1;
    reg  [AW-1:0] araddr = 0;
    reg           arvalid = 0;
    wire          arready;
    wire [DW-1:0] rdata;
    wire [1:0]    rresp;
    wire          rvalid;
    reg           rready = 1;
    wire          irq;

    npu_ctrl #(
        .C_S_AXI_DATA_WIDTH(DW),
        .C_S_AXI_ADDR_WIDTH(AW),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W),
        .N     (N)
    ) dut (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rst_n),
        .S_AXI_AWADDR(awaddr), .S_AXI_AWVALID(awvalid), .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata), .S_AXI_WSTRB(4'hF), .S_AXI_WVALID(wvalid), .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp), .S_AXI_BVALID(bvalid), .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr), .S_AXI_ARVALID(arvalid), .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata), .S_AXI_RRESP(rresp), .S_AXI_RVALID(rvalid), .S_AXI_RREADY(rready),
        .irq(irq)
    );

    always #5 clk = ~clk;

    reg signed [DATA_W-1:0] a_mem [0:15];
    reg signed [DATA_W-1:0] w_mem [0:15];
    reg signed [ACC_W-1:0]  ref_mem [0:15];

    integer errors;

    task axi_write;
        input [AW-1:0] addr;
        input [31:0]   data;
        begin
            @(negedge clk);
            awaddr = addr; awvalid = 1'b1;
            @(posedge clk);
            while (!awready) @(posedge clk);
            @(negedge clk);
            awvalid = 1'b0;
            wdata = data; wvalid = 1'b1;
            @(posedge clk);
            while (!wready) @(posedge clk);
            @(negedge clk);
            wvalid = 1'b0;
            while (!bvalid) @(posedge clk);
            @(negedge clk);
        end
    endtask

    task axi_read;
        input  [AW-1:0] addr;
        output [31:0]   data;
        begin
            @(negedge clk);
            araddr = addr; arvalid = 1'b1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            @(negedge clk);
            arvalid = 1'b0;
            while (!rvalid) @(posedge clk);
            data = rdata;
            @(negedge clk);
        end
    endtask

    function [31:0] pack4;
        input signed [7:0] b0, b1, b2, b3;
        begin
            pack4 = {b3, b2, b1, b0};
        end
    endfunction

    integer i, j;
    reg [31:0] rd;
    reg signed [31:0] got;
    reg signed [31:0] exp;

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            a_mem[i] = 0;
            w_mem[i] = 0;
            ref_mem[i] = 0;
        end
        $readmemh("vectors/a.hex", a_mem);
        $readmemh("vectors/w.hex", w_mem);
        $readmemh("vectors/ref.hex", ref_mem);
        $display("[INFO] Loaded golden vectors (A/W/REF)");

        errors = 0;
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        for (i = 0; i < 4; i = i + 1)
            axi_write(8'h10 + 4*i, pack4(a_mem[i*4+0], a_mem[i*4+1], a_mem[i*4+2], a_mem[i*4+3]));
        for (i = 0; i < 4; i = i + 1)
            axi_write(8'h50 + 4*i, pack4(w_mem[i*4+0], w_mem[i*4+1], w_mem[i*4+2], w_mem[i*4+3]));

        axi_write(8'h00, 32'h1);

        rd = 0;
        while (!(rd & 32'h2)) begin
            axi_read(8'h04, rd);
        end
        $display("[INFO] DONE received, ITER counter check ...");

        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                axi_read(8'h90 + 4*(i*4+j), rd);
                got = rd;
                exp = ref_mem[i*4+j];
                if ((got !== exp) || (^got === 1'bx)) begin
                    errors = errors + 1;
                    $display("[FAIL] C[%0d][%0d] got=%0d exp=%0d", i, j, got, exp);
                end else begin
                    $display("[ OK ] C[%0d][%0d] = %0d", i, j, got);
                end
            end
        end

        if (errors == 0)
            $display("[PASS] npu_ctrl AXI-Lite register flow matches golden");
        else
            $display("[FAIL] %0d mismatches", errors);

        $finish;
    end

endmodule
