`timescale 1ns / 1ps
`default_nettype none

//******************************************************************************
//* TMDS adó.                                                                  *
//******************************************************************************
module tmds_transmitter(
   //Órajel és reset.
   input  wire       clk,                 //Pixel órajel bemenet.
   input  wire       clk_5x,              //5x pixel órajel bemenet.
   input  wire       rst,                 //Reset jel.
   
   //Bemeneti video adatok.
   input  wire [7:0] red_in,              //Piros színkomponens.
   input  wire [7:0] green_in,            //Zöld színkomponens.
   input  wire [7:0] blue_in,             //Kék színkomponens.
   input  wire       blank_in,            //A nem látható képtartomány jelzése.
   input  wire       hsync_in,            //Horizontális szinkronjel.
   input  wire       vsync_in,            //Vertikális szinkronjel.
   
   //Kimenõ TMDS jelek.
   output wire       tmds_data0_out_p,    //Adat 0.
   output wire       tmds_data0_out_n,
   output wire       tmds_data1_out_p,    //Adat 1.
   output wire       tmds_data1_out_n,
   output wire       tmds_data2_out_p,    //Adat 2.
   output wire       tmds_data2_out_n,
   output wire       tmds_clock_out_p,    //Pixel órajel.
   output wire       tmds_clock_out_n
);

//*****************************************************************************
//* A TMDS kódolók példányosítása.                                            *
//*****************************************************************************
wire [9:0] tmds_red, tmds_green, tmds_blue;

tmds_encoder encoder_r(
   //Órajel és reset.
   .clk(clk),                       //Pixel órajel bemenet.
   .rst(rst),                       //Aszinkron reset bemenet.
   
   //Bemenõ adat.
   .data_in(red_in),                //A kódolandó pixel adat.
   .data_en(~blank_in),             //A látható képtartomány jelzése.
   .ctrl0_in(1'b0),                 //Vezérlõjelek.
   .ctrl1_in(1'b0),
   
   //Kimenõ adat.
   .tmds_out(tmds_red)
);

tmds_encoder encoder_g(
   //Órajel és reset.
   .clk(clk),                       //Pixel órajel bemenet.
   .rst(rst),                       //Aszinkron reset bemenet.
   
   //Bemenõ adat.
   .data_in(green_in),              //A kódolandó pixel adat.
   .data_en(~blank_in),             //A látható képtartomány jelzése.
   .ctrl0_in(1'b0),                 //Vezérlõjelek.
   .ctrl1_in(1'b0),
   
   //Kimenõ adat
   .tmds_out(tmds_green)
);

tmds_encoder encoder_b(
   //Órajel és reset.
   .clk(clk),                       //Pixel órajel bemenet.
   .rst(rst),                       //Aszinkron reset bemenet.
   
   //Bemenõ adat.
   .data_in(blue_in),               //A kódolandó pixel adat.
   .data_en(~blank_in),             //A látható képtartomány jelzése.
   .ctrl0_in(hsync_in),             //Vezérlõjelek.
   .ctrl1_in(vsync_in),
   
   //Kimenõ adat
   .tmds_out(tmds_blue)
);


//*****************************************************************************
//* A párhuzamos-soros átalakítok példányosítása.                             *
//*****************************************************************************
oserdes_10to1 oserdes0(
   //Órajel és reset.
   .clk(clk),                       //1x órajel bemenet.
   .clk_5x(clk_5x),                 //5x órajel bemenet (DDR mód).
   .rst(rst),                       //Aszinkron reset jel.
   
   //10 bites adat bemenet.
   .data_in(tmds_blue),
   
   //Differenciális soros adat kimenet.
   .dout_p(tmds_data0_out_p),
   .dout_n(tmds_data0_out_n)
);

oserdes_10to1 oserdes1(
   //Órajel és reset.
   .clk(clk),                       //1x órajel bemenet.
   .clk_5x(clk_5x),                 //5x órajel bemenet (DDR mód).
   .rst(rst),                       //Aszinkron reset jel.
   
   //10 bites adat bemenet.
   .data_in(tmds_green),
   
   //Sifferenciális soros adat kimenet.
   .dout_p(tmds_data1_out_p),
   .dout_n(tmds_data1_out_n)
);

oserdes_10to1 oserdes2(
   //Órajel és reset.
   .clk(clk),                       //1x órajel bemenet.
   .clk_5x(clk_5x),                 //5x órajel bemenet (DDR mód).
   .rst(rst),                       //Asynchronous reset signal.
   
   //10 bites adat bemenet.
   .data_in(tmds_red),
   
   //Differenciális soros adat kimenet.
   .dout_p(tmds_data2_out_p),
   .dout_n(tmds_data2_out_n)
);


//*****************************************************************************
//* TMDS pixel órajel csatorna.                                               *
//*****************************************************************************
wire clk_out;

ODDR #(
   .DDR_CLK_EDGE("OPPOSITE_EDGE"),  // "OPPOSITE_EDGE" vagy "SAME_EDGE". 
   .INIT(1'b0),                     // A Q kimenet kezdeti értéke.
   .SRTYPE("ASYNC")                 // "SYNC" vagy "ASYNC" beállítás/törlés. 
) ODDR_clk (
   .Q(clk_out),                     // 1 bites DDR kimenet.
   .C(clk),                         // 1 bites órajel bemenet.
   .CE(1'b1),                       // 1 bites órajel engedélyezõ bemenet.
   .D1(1'b1),                       // 1 bites adat bemenet (felfutó él).
   .D2(1'b0),                       // 1 bites adat bemenet (lefutó él).
   .R(rst),                         // 1 bites törlõ bemenet.
   .S(1'b0)                         // 1 bites 1-be állító bemenet.
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

