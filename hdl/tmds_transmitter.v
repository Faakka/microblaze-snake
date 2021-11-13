`timescale 1ns / 1ps
`default_nettype none

//******************************************************************************
//* TMDS ad�.                                                                  *
//******************************************************************************
module tmds_transmitter(
   //�rajel �s reset.
   input  wire       clk,                 //Pixel �rajel bemenet.
   input  wire       clk_5x,              //5x pixel �rajel bemenet.
   input  wire       rst,                 //Reset jel.
   
   //Bemeneti video adatok.
   input  wire [7:0] red_in,              //Piros sz�nkomponens.
   input  wire [7:0] green_in,            //Z�ld sz�nkomponens.
   input  wire [7:0] blue_in,             //K�k sz�nkomponens.
   input  wire       blank_in,            //A nem l�that� k�ptartom�ny jelz�se.
   input  wire       hsync_in,            //Horizont�lis szinkronjel.
   input  wire       vsync_in,            //Vertik�lis szinkronjel.
   
   //Kimen� TMDS jelek.
   output wire       tmds_data0_out_p,    //Adat 0.
   output wire       tmds_data0_out_n,
   output wire       tmds_data1_out_p,    //Adat 1.
   output wire       tmds_data1_out_n,
   output wire       tmds_data2_out_p,    //Adat 2.
   output wire       tmds_data2_out_n,
   output wire       tmds_clock_out_p,    //Pixel �rajel.
   output wire       tmds_clock_out_n
);

//*****************************************************************************
//* A TMDS k�dol�k p�ld�nyos�t�sa.                                            *
//*****************************************************************************
wire [9:0] tmds_red, tmds_green, tmds_blue;

tmds_encoder encoder_r(
   //�rajel �s reset.
   .clk(clk),                       //Pixel �rajel bemenet.
   .rst(rst),                       //Aszinkron reset bemenet.
   
   //Bemen� adat.
   .data_in(red_in),                //A k�doland� pixel adat.
   .data_en(~blank_in),             //A l�that� k�ptartom�ny jelz�se.
   .ctrl0_in(1'b0),                 //Vez�rl�jelek.
   .ctrl1_in(1'b0),
   
   //Kimen� adat.
   .tmds_out(tmds_red)
);

tmds_encoder encoder_g(
   //�rajel �s reset.
   .clk(clk),                       //Pixel �rajel bemenet.
   .rst(rst),                       //Aszinkron reset bemenet.
   
   //Bemen� adat.
   .data_in(green_in),              //A k�doland� pixel adat.
   .data_en(~blank_in),             //A l�that� k�ptartom�ny jelz�se.
   .ctrl0_in(1'b0),                 //Vez�rl�jelek.
   .ctrl1_in(1'b0),
   
   //Kimen� adat
   .tmds_out(tmds_green)
);

tmds_encoder encoder_b(
   //�rajel �s reset.
   .clk(clk),                       //Pixel �rajel bemenet.
   .rst(rst),                       //Aszinkron reset bemenet.
   
   //Bemen� adat.
   .data_in(blue_in),               //A k�doland� pixel adat.
   .data_en(~blank_in),             //A l�that� k�ptartom�ny jelz�se.
   .ctrl0_in(hsync_in),             //Vez�rl�jelek.
   .ctrl1_in(vsync_in),
   
   //Kimen� adat
   .tmds_out(tmds_blue)
);


//*****************************************************************************
//* A p�rhuzamos-soros �talak�tok p�ld�nyos�t�sa.                             *
//*****************************************************************************
oserdes_10to1 oserdes0(
   //�rajel �s reset.
   .clk(clk),                       //1x �rajel bemenet.
   .clk_5x(clk_5x),                 //5x �rajel bemenet (DDR m�d).
   .rst(rst),                       //Aszinkron reset jel.
   
   //10 bites adat bemenet.
   .data_in(tmds_blue),
   
   //Differenci�lis soros adat kimenet.
   .dout_p(tmds_data0_out_p),
   .dout_n(tmds_data0_out_n)
);

oserdes_10to1 oserdes1(
   //�rajel �s reset.
   .clk(clk),                       //1x �rajel bemenet.
   .clk_5x(clk_5x),                 //5x �rajel bemenet (DDR m�d).
   .rst(rst),                       //Aszinkron reset jel.
   
   //10 bites adat bemenet.
   .data_in(tmds_green),
   
   //Sifferenci�lis soros adat kimenet.
   .dout_p(tmds_data1_out_p),
   .dout_n(tmds_data1_out_n)
);

oserdes_10to1 oserdes2(
   //�rajel �s reset.
   .clk(clk),                       //1x �rajel bemenet.
   .clk_5x(clk_5x),                 //5x �rajel bemenet (DDR m�d).
   .rst(rst),                       //Asynchronous reset signal.
   
   //10 bites adat bemenet.
   .data_in(tmds_red),
   
   //Differenci�lis soros adat kimenet.
   .dout_p(tmds_data2_out_p),
   .dout_n(tmds_data2_out_n)
);


//*****************************************************************************
//* TMDS pixel �rajel csatorna.                                               *
//*****************************************************************************
wire clk_out;

ODDR #(
   .DDR_CLK_EDGE("OPPOSITE_EDGE"),  // "OPPOSITE_EDGE" vagy "SAME_EDGE". 
   .INIT(1'b0),                     // A Q kimenet kezdeti �rt�ke.
   .SRTYPE("ASYNC")                 // "SYNC" vagy "ASYNC" be�ll�t�s/t�rl�s. 
) ODDR_clk (
   .Q(clk_out),                     // 1 bites DDR kimenet.
   .C(clk),                         // 1 bites �rajel bemenet.
   .CE(1'b1),                       // 1 bites �rajel enged�lyez� bemenet.
   .D1(1'b1),                       // 1 bites adat bemenet (felfut� �l).
   .D2(1'b0),                       // 1 bites adat bemenet (lefut� �l).
   .R(rst),                         // 1 bites t�rl� bemenet.
   .S(1'b0)                         // 1 bites 1-be �ll�t� bemenet.
);

OBUFDS #(
   .IOSTANDARD("TMDS_33"),
   .SLEW("FAST")
) OBUFDS_clk (
   .I(clk_out),
   .O(tmds_clock_out_p),
   .OB(tmds_clock_out_n)
);

endmodule

`default_nettype wire

