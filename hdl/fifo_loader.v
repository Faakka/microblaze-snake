`timescale 1ns / 1ps

module fifo_loader#(
    parameter DATA_WIDTH = 32,
    parameter LENGTH = 32
)
(
    input wire clk,
    input wire rstn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXI TDATA" *)
    output wire [DATA_WIDTH-1:0] tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXI TLAST" *)
    output wire tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXI TVALID" *)
    output wire tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXI TREADY" *)
    input wire tready
);

reg [DATA_WIDTH-1:0] word_cntr = 0;

wire cntr_clr;
assign cntr_clr = (word_cntr == LENGTH);

assign tlast = (word_cntr == LENGTH-1);

always @(posedge clk) begin
    if(~rstn | cntr_clr)
        word_cntr <= 0;
    else if(tready)
        word_cntr <= word_cntr + 1'b1;
end
    
assign tdata = 32'h00FF00FF;
assign tvalid = 1'b1;

endmodule
