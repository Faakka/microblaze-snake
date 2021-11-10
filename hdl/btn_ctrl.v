`timescale 1ns / 1ps

/***********************************************************
*     (btn3) (btn2) (btn1) (btn0) gombok mintavetelezese   *
***********************************************************/

/*
* A nyomogombok ertekenek beolvasasa 100 Hz-en tortenik
*
* regiszterek:
*   - a legutobb lenyomott gombot jelolo regiszter (pollinghoz) (BASE_ADDR + 0x0, 32-bit, RD)
*   - megszakitas engedelyezo regiszter (BASE_ADDR + 0x4, 32-bit, R/W)
*   - megszakitas flag regiszter (BASE_ADDR + 0x8, 32-bit, R/W1C)
*/

module btn_ctrl(
    input  wire        clk,
    input  wire        rst,

    input  wire [ 3:0] wr_addr,
    input  wire        wr_en,
    input  wire [31:0] wr_data,
    input  wire [ 3:0] wr_strb,

    input  wire [ 3:0] rd_addr,
    input  wire        rd_en,
    output wire [31:0] rd_data,

    input wire  [ 3:0] btn_in,

    output wire        irq
);

// 100Hz-es jel letrehozasa egy 20 bites szamlaloval
reg [19:0] clk_div;
wire       clk_div_tc = (clk_div == 0);

always @(posedge clk) begin
    if(rst | clk_div_tc)
        //clk_div <= 20'd999999;
        clk_div <= 20'd2;
    else
        clk_div <= clk_div - 1'b1;
end

// A nyomogombok mintavetelezese a btn_reg regiszterbe
reg [3:0] btn_reg;

always @(posedge clk) begin
    if(rst)
        btn_reg <= 0;
    else if(clk_div_tc)
        btn_reg <= btn_in;
end

// A R/W engedelyezo jelek letrehozasa az egyes regiszterekhez
wire btn_rd = rd_en & (rd_addr[3:2] == 2'b00);

wire ier_rd = rd_en & (rd_addr[3:2] == 2'b01);
wire ier_wr = wr_en & (wr_addr[3:2] == 2'b01) & (wr_strb == 4'b1111);

wire ifr_rd = rd_en & (rd_addr[3:2] == 2'b10);
wire ifr_wr = wr_en & (wr_addr[3:2] == 2'b10) & (wr_strb == 4'b1111);

/**************************************************************************
* Legutobb lenyomott gomb reg.: BASE_ADDR+0x0, 32-bit, RD                 *
*                                                                         *
*    31          5     4       3     2    1    0                          *
*  -----------------------------------------------                        *
* |  x    ....   x     x     |BTN3|BTN2|BTN1|BTN0|                        *
*  -----------------------------------------------                        *
**************************************************************************/
wire [31:0] last_btn;
assign last_btn = {28'b0,btn_reg};

/**************************************************************************
* Megszakítás engedélyezõ reg.: BASE_ADDR+0x4, 32-bit, R/W                *
*                                                                         *
*    31          5     4       3     2    1    0                          *
*  -----------------------------------------------                        *
* |  x    ....   x     x     |IEB3|IEB2|IEB1|IEB0|                        *
*  -----------------------------------------------                        *
**************************************************************************/
reg [3:0] ier;
always @(posedge clk) begin
    if(rst)
        ier <= 0;
    else if(ier_wr)
        ier <= wr_data[3:0];
end

/**************************************************************************
* Megszakítás flag reg.: BASE_ADDR+0x8, 32-bit, R/W1C                     *
*                                                                         *
*    31          5     4       3     2    1    0                          *
*  -----------------------------------------------                        *
* |  x    ....   x     x     |IFB3|IFB2|IFB1|IFB0|                        *
*  -----------------------------------------------                        *
**************************************************************************/
reg [1:0] btn0_rising_edge_reg;
reg [1:0] btn1_rising_edge_reg;
reg [1:0] btn2_rising_edge_reg;
reg [1:0] btn3_rising_edge_reg;

always @(posedge clk) begin
    if(rst) begin
        btn0_rising_edge_reg <= 2'b00;
        btn1_rising_edge_reg <= 2'b00;
        btn2_rising_edge_reg <= 2'b00;
        btn3_rising_edge_reg <= 2'b00;
    end
    else if(clk_div_tc) begin
        btn0_rising_edge_reg <= {btn0_rising_edge_reg[0],btn_in[0]};
        btn1_rising_edge_reg <= {btn1_rising_edge_reg[0],btn_in[1]};
        btn2_rising_edge_reg <= {btn2_rising_edge_reg[0],btn_in[2]};
        btn3_rising_edge_reg <= {btn3_rising_edge_reg[0],btn_in[3]};
    end
end

wire [3:0] ifr_set;
assign ifr_set[0] = (btn0_rising_edge_reg == 2'b01);
assign ifr_set[1] = (btn1_rising_edge_reg == 2'b01);
assign ifr_set[2] = (btn2_rising_edge_reg == 2'b01);
assign ifr_set[3] = (btn3_rising_edge_reg == 2'b01);


reg [3:0] ifr;
integer i;

always @(posedge clk) begin
    for(i = 0; i < 4; i = i + 1) begin
        if(rst)
            ifr[i] <= 1'b0;
        else
            if(ifr_set[i])
                ifr[i] <= 1'b1;
            else if(ifr_wr & wr_data[i])
                ifr[i] <= 1'b0;
    end
end

assign irq = |(ier & ifr);

assign rd_data = btn_rd ? last_btn      : 
                (ier_rd ? {29'b0,ier}   :
                (ifr_rd ? {29'b0,ifr}   : 32'b0));


endmodule
