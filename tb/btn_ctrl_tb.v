`timescale 1ns / 1ps

module btn_ctrl_tb;


    reg        clk = 0;
    reg        rst = 1;

    reg [ 3:0] wr_addr = 'b0;
    reg        wr_en = 1'b0;
    reg [31:0] wr_data = 'b0;
    reg [ 3:0] wr_strb = 'b0;

    reg [ 3:0] rd_addr = 'b0;
    reg        rd_en = 'b0;
    wire [31:0] rd_data;

    reg  [ 3:0] btn_in = 'b0;

    wire        irq;

    reg [31:0] data_read;

    btn_ctrl UUT (
        .clk(clk),
        .rst(rst),

        .wr_addr(wr_addr),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .wr_strb(wr_strb),

        .rd_addr(rd_addr),
        .rd_en(rd_en),
        .rd_data(rd_data),

        .btn_in(btn_in),

        .irq(irq)
    );

    always #5 clk = ~clk;

    initial begin
        #100 rst = 1'b0;
        #11 write_task(32'h0000_0004, 32'h0000_000f, 4'b1111);
        #42 btn_in <= 4'b0001;
        #29 read_task(32'h0000_0000, data_read);
        #42 btn_in <= 4'b0000;
        #29 read_task(32'h0000_0008, data_read);
        #2 write_task(32'h0000_0008, 32'h0000_000f, 4'b1111);
        #422 btn_in <= 4'b0010;
    end


    task write_task;
        input [31:0] addr;
        input [31:0] data;
        input [ 3:0] strb;
        begin
            @(posedge clk) begin
                wr_addr <= addr;
                wr_data <= data;
                wr_strb <= strb;
                wr_en <= 1'b1;
            end
            @(posedge clk) begin
                wr_addr <= 'b0;
                wr_data <= 'b0;
                wr_strb <= 'b0;
                wr_en <= 1'b0;
            end
        end
    endtask

    task read_task;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk) begin
                rd_addr <= addr;
                rd_en <= 1'b1;
            end
            @(posedge clk) begin
                data <= rd_data;
            end
            @(posedge clk) begin
                rd_addr <= 'b0;
                rd_en <= 1'b0;
            end
        end
    endtask

endmodule
