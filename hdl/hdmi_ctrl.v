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
   output wire       tmds_clock_out_n,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXI TDATA" *)
    input [31:0] tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXI TLAST" *)
    input tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXI TVALID" *)
    input tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXI TREADY" *)
    output tready
);

    /*
    * Erdemes egy kulon modult csinalni a sync- es blank jelek generalasahoz
    * A 640x480 @ 60 Hz kriteriumai:
    *   - 25(,175) MHz pixelorajel
    *   - horizontal:
    *       - front porch: 16
    *       - sync pulse : 96
    *       - back porch : 48
    *   - vertical:
    *       - front porch: 10
    *       - sync pulse : 2
    *       - back porch : 33
    *   - teljes frame: 800x525
    */


reg [7:0] red_r;
reg [7:0] green_r;
reg [7:0] blue_r;

wire [7:0] red_w;
wire [7:0] green_w;
wire [7:0] blue_w;

reg blank_r;
reg hsync_r;
reg vsync_r;
reg frame_end_r;

wire blank_w;
wire hsync_w;
wire vsync_w;
wire frame_end_w;

reg [1:0] state = 0;

localparam INIT = 2'b00;
localparam SYNC = 2'b01;
localparam DISP = 2'b10;

always @(posedge clk) begin
    if(rst) begin
        state <= INIT;
    end
    else begin
        case(state)
            INIT: begin
                if(tlast)
                    state <= SYNC;
                else
                    state <= INIT;
            end

            SYNC: begin
                if(frame_end_r) begin
                    if(tvalid)
                        state <= DISP;
                    else
                        state <= INIT;
                end
                else
                    state <= SYNC;
            end

            DISP: begin
                if(tlast | ~tvalid)
                    state <= SYNC;
                else
                    state <= DISP;
            end
        endcase
    end
end

always @(posedge clk) begin
    if(state == DISP) begin
        red_r <= tdata[7:0];
        green_r <= tdata[15:8];
        blue_r <= tdata[23:16];
    end
    else begin
        red_r <= 0;
        green_r <= 0;
        blue_r <= 0;
    end
end

assign tready = ~blank_r & ((state == INIT) || (state == DISP));

assign red_w = blank_r ? 7'b0 : red_r;
assign green_w = blank_r ? 7'b0 : green_r;
assign blue_w = blank_r ? 7'b0 : blue_r;

tmds_transmitter TMDS_TX(
    .clk(clk),
    .clk_5x(clk_5x),
    .rst(rst),
    .red_in(red_w),
    .green_in(green_w),
    .blue_in(blue_w),
    .blank_in(blank_r),
    .hsync_in(hsync_r),
    .vsync_in(vsync_r),

   .tmds_data0_out_p(tmds_data0_out_p),
   .tmds_data0_out_n(tmds_data0_out_n),
   .tmds_data1_out_p(tmds_data1_out_p),
   .tmds_data1_out_n(tmds_data1_out_n),
   .tmds_data2_out_p(tmds_data2_out_p),
   .tmds_data2_out_n(tmds_data2_out_n),
   .tmds_clock_out_p(tmds_clock_out_p),
   .tmds_clock_out_n(tmds_clock_out_n)
);

vga_timing TIMING(
    .clk(clk),
    .rst(rst),
    .h_cnt(),
    .v_cnt(),
    .h_sync(hsync_w),
    .v_sync(vsync_w),
    .frame_end(frame_end_w),
    .blank(blank_w)
);

always @(posedge clk) begin
    hsync_r <= hsync_w;
    vsync_r <= vsync_w;
    frame_end_r <= frame_end_w;
    blank_r <= blank_w;
end

endmodule








