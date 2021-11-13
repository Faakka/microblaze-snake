`timescale 1ns / 1ps

/*
* 25 MHz-es pixelorajel a 640x480 felbontashoz
* a kulso memoriabol AXI-Streamen keresztul egy FIFO-ba kerulnek a pixelek szinkomponensei
* 
* ennek a modulnak a feldata, hogy folyamtosan olvassa a FIFO-bol a szinkomponenseket, majd
* ezekbol osszeallítsa es pixelorajelenkent kiadja a 3 szint + blank, vsync, hsync
*
* ahhoz, hogy 25 MHz-enkent ki lehessen adni egy pixelt, legalabb 3x olyan gyorsan kell beolvasni
* az egyes komponenseket
*
* egy DMA atvitellel a teljes keptartomany (640x480x3 bajt) belekerul a FIFO-ba
* a tlast jel jelzi, hogy melyik volt a legutolso atvitt bajt, azaz ennek alapjan kell
* a blank kiolto jelet vezerleni
*
* a hsync es vsync jeleket pedig ki kell szamolni a blank idotartambol
* a blank leteltevel ujra el kell kezdeni olvasni a FIFO-t es kuldeni a pixeleket
*
* */

module hdmi_ctrl(
   //Órajel és reset.
   input  wire       clk,                 //Pixel órajel bemenet.
   input  wire       clk_5x,              //5x pixel órajel bemenet.
   input  wire       rst,                 //Reset jel.
   
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

wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire       blank;
wire       hsync;
wire       vsync;

tmds_transmitter TMDS_TX(
    .clk(clk),
    .clk_5x(clk_5x),
    .rst(rst),
    .red_in(red),
    .green_in(green),
    .blue_in(blue),
    .blank_in(blank),
    .hsync_in(hsync),
    .vsync_in(vsync),

   .tmds_data0_out_p(tmds_data0_out_p),
   .tmds_data0_out_n(tmds_data0_out_n),
   .tmds_data1_out_p(tmds_data1_out_p),
   .tmds_data1_out_n(tmds_data1_out_n),
   .tmds_data2_out_p(tmds_data2_out_p),
   .tmds_data2_out_n(tmds_data2_out_n),
   .tmds_clock_out_p(tmds_clock_out_p),
   .tmds_clock_out_n(tmds_clock_out_n)
);




endmodule
