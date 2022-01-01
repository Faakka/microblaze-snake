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

module hdmi_ctrl#(
    parameter H_VISIBLE = 640,
    parameter H_FRONT_PORCH = 16,
    parameter H_SYNC_PULSE = 96,
    parameter H_BACK_PORCH = 48,

    parameter V_VISIBLE = 480,
    parameter V_FRONT_PORCH = 10,
    parameter V_SYNC_PULSE = 2,
    parameter V_BACK_PORCH = 33
)
(
   //Órajel és reset.
   input  wire       clk,                 //Pixel órajel bemenet.
   input  wire       clk_5x,              //5x pixel órajel bemenet.
   input  wire       rstn,                 //Reset jel.
   
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
    input wire [31:0] tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXI TLAST" *)
    input wire tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXI TVALID" *)
    input wire tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXI TREADY" *)
    output wire tready
);

    /*
    * Erdemes egy kulon modult csinalni a sync- es blank jelek generalasahoz
    * A 640x480 @ 60 Hz kriteriumai:
    *   - 25,175 MHz pixelorajel
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


    /*
reg [7:0] red_r;
reg [7:0] green_r;
reg [7:0] blue_r;

wire [7:0] red_w;
wire [7:0] green_w;
wire [7:0] blue_w;

reg blank_r;
reg hsync_r;
reg vsync_r;

wire blank_w;
wire hsync_w;
wire vsync_w;
wire frame_end;

reg [1:0] state = 0;

localparam INIT = 2'b00;
localparam SYNC = 2'b01;
localparam DISP = 2'b10;

always @(posedge clk) begin
    if(~rstn) begin
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
                if(frame_end & tvalid)
                    state <= DISP;
                else
                    state <= SYNC;
            end

            DISP: begin
                if(tlast)
                    state <= SYNC;
                else if(~tvalid)
                    state <= INIT;
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

assign tready = (state == INIT) | (~blank_r & (state == DISP));

assign red_w = (~blank_r & (state == DISP)) ? red_r : 8'b0;
assign green_w = (~blank_r & (state == DISP)) ? green_r : 8'b0;
assign blue_w = (~blank_r & (state == DISP)) ? blue_r : 8'b0;

tmds_transmitter TMDS_TX(
    .clk(clk),
    .clk_5x(clk_5x),
    .rst(~rstn),
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

vga_timing #(
    .H_VISIBLE(H_VISIBLE),
    .H_FRONT_PORCH(H_FRONT_PORCH),
    .H_SYNC_PULSE(H_SYNC_PULSE),
    .H_BACK_PORCH(H_BACK_PORCH),
    .V_VISIBLE(V_VISIBLE),
    .V_FRONT_PORCH(V_FRONT_PORCH),
    .V_SYNC_PULSE(V_SYNC_PULSE),
    .V_BACK_PORCH(V_BACK_PORCH)
) TIMING(
    .clk(clk),
    .rst(~rstn),
    .h_cnt(),
    .v_cnt(),
    .h_sync(hsync_w),
    .v_sync(vsync_w),
    .frame_end(frame_end),
    .blank(blank_w)
);

always @(posedge clk) begin
    hsync_r <= hsync_w;
    vsync_r <= vsync_w;
    blank_r <= blank_w;
end
    */

wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;

wire blank;
wire hsync;
wire vsync;
wire frame_end;

reg [1:0] state = 0;

localparam INIT = 2'b00;
localparam SYNC = 2'b01;
localparam DISP = 2'b10;

always @(posedge clk) begin
    if(~rstn) begin
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
                if(frame_end & tvalid)
                    state <= DISP;
                else
                    state <= SYNC;
            end

            DISP: begin
                if(tlast)
                    state <= SYNC;
                else if(~tvalid)
                    state <= INIT;
                else
                    state <= DISP;
            end
        endcase
    end
end

assign tready = (state == INIT) | (~blank & (state == DISP));

assign red = (~blank & (state == DISP)) ? tdata[7:0] : 8'b0;
assign green = (~blank & (state == DISP)) ? tdata[15:8] : 8'b0;
assign blue = (~blank & (state == DISP)) ? tdata[23:16] : 8'b0;

tmds_transmitter TMDS_TX(
    .clk(clk),
    .clk_5x(clk_5x),
    .rst(~rstn),
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

vga_timing #(
    .H_VISIBLE(H_VISIBLE),
    .H_FRONT_PORCH(H_FRONT_PORCH),
    .H_SYNC_PULSE(H_SYNC_PULSE),
    .H_BACK_PORCH(H_BACK_PORCH),
    .V_VISIBLE(V_VISIBLE),
    .V_FRONT_PORCH(V_FRONT_PORCH),
    .V_SYNC_PULSE(V_SYNC_PULSE),
    .V_BACK_PORCH(V_BACK_PORCH)
) TIMING(
    .clk(clk),
    .rst(~rstn),
    .h_cnt(),
    .v_cnt(),
    .h_sync(hsync),
    .v_sync(vsync),
    .frame_end(frame_end),
    .blank(blank)
);

endmodule








