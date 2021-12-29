`timescale 1ns / 1ps
`default_nettype none

//******************************************************************************
//* 640 x 480 @ 60 Hz VGA id�z�t�s gener�tor.                                 *
//******************************************************************************
module vga_timing#(
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
   //�rajel �s reset.
   input  wire        clk,             //Pixel �rajel bemenet.
   input  wire        rst,             //Reset bemenet.
   
   //Az aktu�lis pixel poz�ci�.
   output reg  [10:0] h_cnt = 11'd0,   //X-koordin�ta.
   output reg  [9:0]  v_cnt = 10'd0,   //Y-koordin�ta.
   
   //Szinkron �s kiolt� jelek.
   output reg         h_sync = 1'b1,   //Horizont�lis szinkron pulzus.
   output reg         v_sync = 1'b0,   //Vertik�lis szinkron pulzus.
   output reg         frame_end = 1'b0,
   output wire        blank            //Kiolt� jel.
);

//******************************************************************************
//* Id�z�t�si param�terek.                                                     *
//******************************************************************************
localparam H_BLANK_BEGIN = H_VISIBLE     - 1;
localparam H_SYNC_BEGIN  = H_BLANK_BEGIN + H_FRONT_PORCH;
localparam H_SYNC_END    = H_SYNC_BEGIN  + H_SYNC_PULSE;
localparam H_BLANK_END   = H_SYNC_END    + H_BACK_PORCH;

localparam V_BLANK_BEGIN = V_VISIBLE     - 1;
localparam V_SYNC_BEGIN  = V_BLANK_BEGIN + V_FRONT_PORCH;
localparam V_SYNC_END    = V_SYNC_BEGIN  + V_SYNC_PULSE;
localparam V_BLANK_END   = V_SYNC_END    + V_BACK_PORCH;


//******************************************************************************
//* A horizont�lis �s vertik�lis sz�ml�l�k.                                    *
//******************************************************************************
always @(posedge clk)
begin
   if (rst || (h_cnt == H_BLANK_END))
      h_cnt <= 12'd0;
   else
      h_cnt <= h_cnt + 12'd1;
end

always @(posedge clk)
begin
   if (rst)
      v_cnt <= 11'd0;
   else
      if (h_cnt == H_BLANK_END)
         if (v_cnt == V_BLANK_END)
            v_cnt <= 11'd0;
         else
            v_cnt <= v_cnt + 11'd1;
end


//******************************************************************************
//* A szinkron pulzusok gener�l�sa.                                            *
//******************************************************************************
always @(posedge clk)
begin
   if (rst || (h_cnt == H_SYNC_END))
      h_sync <= 1'b1;
   else
      if (h_cnt == H_SYNC_BEGIN)
         h_sync <= 1'b0;
end

always @(posedge clk)
begin
   if (rst)
      v_sync <= 1'b0;
   else
      if (h_cnt == H_BLANK_END)
         if (v_cnt == V_SYNC_BEGIN)
            v_sync <= 1'b1;
         else
            if (v_cnt == V_SYNC_END)
               v_sync <= 1'b0;
end


//******************************************************************************
//* A kiolt� jel el��ll�t�sa.                                                  *
//******************************************************************************
reg h_blank = 1'b0;
reg v_blank = 1'b0;

always @(posedge clk)
begin
   if (rst || (h_cnt == H_BLANK_END))
      h_blank <= 1'b0;
   else
      if (h_cnt == H_BLANK_BEGIN)
         h_blank <= 1'b1;
end

always @(posedge clk)
begin
   if (rst)
      v_blank <= 1'b0;
   else
       if (h_cnt == H_BLANK_END) begin
            if (v_cnt == V_BLANK_END - 1'b1)
                frame_end <= 1'b1;
            else
                frame_end <= 1'b0;

            if (v_cnt == V_BLANK_BEGIN)
                v_blank <= 1'b1;
            else
                if (v_cnt == V_BLANK_END)
                    v_blank <= 1'b0;
       end
end

assign blank = h_blank | v_blank;

endmodule 

`default_nettype wire

