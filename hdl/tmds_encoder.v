`timescale 1ns / 1ps
`default_nettype none

//******************************************************************************
//* TMDS k�dol�.                                                               *
//******************************************************************************
module tmds_encoder(
   //�rajel �s reset.
   input  wire       clk,        //Pixel �rajel bemenet.
   input  wire       rst,        //Aszinkron reset bemenet.
   
   //Bemen� adat.
   input  wire [7:0] data_in,    //A k�doland� pixel adat.
   input  wire       data_en,    //A l�that� k�ptartom�ny jelz�se.
   input  wire       ctrl0_in,   //Vez�rl� jelek.
   input  wire       ctrl1_in,
   
   //Kimen� adat.
   output reg  [9:0] tmds_out
);

//*****************************************************************************
//* Az "1" �rt�k� bitek sz�m�nak meghat�roz�sa a bej�v� pixel adatokban.      *
//* A pipeline fokozatok sz�ma: 1                                             *
//*****************************************************************************
reg [7:0] data_in_reg;
reg [3:0] din_num_1s;

always @(posedge clk)
begin
   data_in_reg <= data_in;
   din_num_1s  <= ((data_in[0] + data_in[1]) + (data_in[2] + data_in[3])) +
                  ((data_in[4] + data_in[5]) + (data_in[6] + data_in[7]));
end


//*****************************************************************************
//* A TMDS k�dol�s els� l�p�se: 8 bitr�l 9 bitre t�rt�n� �talak�t�s.          *
//* A pipeline fokozatok sz�ma: 1                                             *
//*****************************************************************************
wire [8:0] stage1;
reg  [8:0] stage1_out;

//Az els� d�nt�si felt�tel:
//- az "1" bitek sz�ma nagyobb 4-n�l vagy
//- az "1" bitek sz�ma 4 �s a bej�v� adat LSb-je 0.
wire decision1 = (din_num_1s > 4'd4) | ((din_num_1s == 4'd4) & ~data_in_reg[0]);

assign stage1[0] = data_in_reg[0];
assign stage1[1] = (stage1[0] ^ data_in_reg[1]) ^ decision1;
assign stage1[2] = (stage1[1] ^ data_in_reg[2]) ^ decision1;
assign stage1[3] = (stage1[2] ^ data_in_reg[3]) ^ decision1;
assign stage1[4] = (stage1[3] ^ data_in_reg[4]) ^ decision1;
assign stage1[5] = (stage1[4] ^ data_in_reg[5]) ^ decision1;
assign stage1[6] = (stage1[5] ^ data_in_reg[6]) ^ decision1;
assign stage1[7] = (stage1[6] ^ data_in_reg[7]) ^ decision1;
assign stage1[8] = ~decision1;

always @(posedge clk)
begin
   stage1_out <= stage1;
end


//*****************************************************************************
//* Az "1" �rt�k� bitek sz�m�nak meghat�roz�sa az els� l�p�s kimenet�ben.     *
//* A pipeline fokozatok sz�ma: 1                                             *
//*****************************************************************************
reg  [8:0] stage2_in;
reg  [3:0] s1_num_1s;

always @(posedge clk)
begin
   stage2_in <= stage1_out;
   s1_num_1s <= ((stage1_out[0] + stage1_out[1]) + (stage1_out[2] + stage1_out[3])) +
                ((stage1_out[4] + stage1_out[5]) + (stage1_out[6] + stage1_out[7]));
end


//*****************************************************************************
//* Pipeline regiszterek az enged�lyez� �s a vez�rl� jelek sz�m�ra.           *
//*****************************************************************************
reg [2:0] data_en_reg;
reg [5:0] ctrl_reg;

always @(posedge clk)
begin
   if (rst)
      data_en_reg <= 3'd0;
   else
      data_en_reg <= {data_en_reg[1:0], data_en};
end

always @(posedge clk)
begin
   if (rst)
      ctrl_reg <= 6'd0;
   else
      ctrl_reg <= {ctrl_reg[3:0], ctrl1_in, ctrl0_in};
end


//*****************************************************************************
//* A TMDS k�dol�s m�sodik l�p�se: 9 bitr�l 10 bitre t�rt�n� �talak�t�s.      *
//*****************************************************************************
localparam CTRL_TOKEN_0 = 10'b1101010100;
localparam CTRL_TOKEN_1 = 10'b0010101011;
localparam CTRL_TOKEN_2 = 10'b0101010100;
localparam CTRL_TOKEN_3 = 10'b1010101011;

//A kimeneti "0" �s "1" bitek sz�m�nak k�l�nbs�ge (MSb az el�jel bit).
reg [4:0] cnt;

//A m�sodik d�nt�si felt�tel:
//- az eddig kiadott "0" �s "1" bitek sz�ma azonos vagy
//- az els� l�p�s kimenet�nek als� 8 bitj�n a "0" �s az "1" bizek sz�ma azonos.
wire decision2 = (cnt == 5'd0) | (s1_num_1s == 4'd4);

//A harmadik d�nt�si felt�tel:
//- eddig t�bb "1" bit ker�lt elk�ld�sre, mint "0" �s az els� l�p�s kimenet�ben
//  az "1" �rt�k� bitek sz�ma a nagyobb vagy
//- eddig t�bb "0" bit ker�lt elk�ld�sre, mint "1" �s az els� l�p�s kimenet�ben
//  a "0" �rt�k� bitek sz�ma a nagyobb
wire decision3 = (~cnt[4] & (s1_num_1s > 4'd4)) | (cnt[4] & (s1_num_1s < 4'd4));

always @(posedge clk or posedge rst)
begin
   if (rst || (data_en_reg[2] == 0))
      cnt <= 5'd0;
   else
      if (decision2)
         if (stage2_in[8])
            //cnt = cnt + (#1s - #0s)
            cnt <= cnt + ({s1_num_1s, 1'b0} - 5'd8);
         else
            //cnt = cnt + (#0s - #1s)
            cnt <= cnt + (5'd8 - {s1_num_1s, 1'b0});
      else
         if (decision3)
            //cnt = cnt + 2*stage2_in[8] + (#0s - #1s)
            cnt <= (cnt + {stage2_in[8], 1'b0})  + (5'd8 - {s1_num_1s, 1'b0});
         else
            //cnt = cnt - 2*(~stage2_in[8]) + (#1s - #0s)
            cnt <= (cnt - {~stage2_in[8], 1'b0}) + ({s1_num_1s, 1'b0} - 5'd8);
end

always @(posedge clk or posedge rst)
begin
   if (rst)
      tmds_out <= 10'd0;
   else
      if (data_en_reg[2])
         if (decision2)
            tmds_out <= {~stage2_in[8], stage2_in[8], stage2_in[7:0] ^ {8{~stage2_in[8]}}};
         else
            if (decision3)
               tmds_out <= {1'b1, stage2_in[8], ~stage2_in[7:0]};
            else
               tmds_out <= {1'b0, stage2_in[8],  stage2_in[7:0]};
      else
         case (ctrl_reg[5:4])
            2'b00: tmds_out <= CTRL_TOKEN_0;
            2'b01: tmds_out <= CTRL_TOKEN_1;
            2'b10: tmds_out <= CTRL_TOKEN_2;
            2'b11: tmds_out <= CTRL_TOKEN_3;
         endcase
end

endmodule

`default_nettype wire
 
