`timescale 1ns / 1ps
`default_nettype none

//******************************************************************************
//* 10:1 p?rhuzamos-soros ?talak?t? differenci?lis kimenettel.                 *
//******************************************************************************
module oserdes_10to1(
   //?rajel ?s reset.
   input  wire       clk,              //1x ?rajel bemenet.
   input  wire       clk_5x,           //5x ?rajel bemenet (DDR m?d).
   input  wire       rst,              //Aszinkron reset jel.
   
   //10 bites adat bemenet.
   input  wire [9:0] data_in,
   
   //Differenci?lis soros adat kimenet.
   output wire       dout_p,
   output wire       dout_n
);

//*****************************************************************************
//* Master OSERDES.                                                           *
//*****************************************************************************
wire data_to_iob, master_shiftin1, master_shiftin2;

OSERDESE2 #(
   .DATA_RATE_OQ("DDR"),
   .DATA_RATE_TQ("DDR"),
   .DATA_WIDTH(10),
   .INIT_OQ(1'b0),
   .INIT_TQ(1'b0),
   .SERDES_MODE("MASTER"),
   .SRVAL_OQ(1'b0),
   .SRVAL_TQ(1'b0),
   .TBYTE_CTL("FALSE"),
   .TBYTE_SRC("FALSE"),
   .TRISTATE_WIDTH(1)
) master_oserdes (
   .OFB(),
   .OQ(data_to_iob),
   .SHIFTOUT1(),
   .SHIFTOUT2(),
   .TBYTEOUT(),
   .TFB(),
   .TQ(),
   .CLK(clk_5x),
   .CLKDIV(clk),
   .D1(data_in[0]),
   .D2(data_in[1]),
   .D3(data_in[2]),
   .D4(data_in[3]),
   .D5(data_in[4]),
   .D6(data_in[5]),
   .D7(data_in[6]),
   .D8(data_in[7]),
   .OCE(1'b1),
   .RST(rst),
   .SHIFTIN1(master_shiftin1),
   .SHIFTIN2(master_shiftin2),
   .T1(1'b0),
   .T2(1'b0),
   .T3(1'b0),
   .T4(1'b0),
   .TBYTEIN(1'b0),
   .TCE(1'b0)
);


//*****************************************************************************
//* Slave OSERDES.                                                            *
//*****************************************************************************
OSERDESE2 #(
   .DATA_RATE_OQ("DDR"),
   .DATA_RATE_TQ("DDR"),
   .DATA_WIDTH(10),
   .INIT_OQ(1'b0),
   .INIT_TQ(1'b0),
   .SERDES_MODE("SLAVE"),
   .SRVAL_OQ(1'b0),
   .SRVAL_TQ(1'b0),
   .TBYTE_CTL("FALSE"),
   .TBYTE_SRC("FALSE"),
   .TRISTATE_WIDTH(1)
) slave_oserdes (
   .OFB(),
   .OQ(),
   .SHIFTOUT1(master_shiftin1),
   .SHIFTOUT2(master_shiftin2),
   .TBYTEOUT(),
   .TFB(),
   .TQ(),
   .CLK(clk_5x),
   .CLKDIV(clk),
   .D1(1'b0),
   .D2(1'b0),
   .D3(data_in[8]),
   .D4(data_in[9]),
   .D5(1'b0),
   .D6(1'b0),
   .D7(1'b0),
   .D8(1'b0),
   .OCE(1'b1),
   .RST(rst),
   .SHIFTIN1(1'b0),
   .SHIFTIN2(1'b0),
   .T1(1'b0),
   .T2(1'b0),
   .T3(1'b0),
   .T4(1'b0),
   .TBYTEIN(1'b0),
   .TCE(1'b0)
);


//*****************************************************************************
//* Differenci?lis kimeneti buffer.                                           *
//*****************************************************************************
OBUFDS #(
   .IOSTANDARD("TMDS_33"),
   .SLEW("FAST")
) output_buffer (
   .I(data_to_iob),
   .O(dout_p),
   .OB(dout_n)
);

endmodule

`default_nettype wire

 