`timescale 1ns / 1ps

module hdmi_ctrl_test_tb;


reg clk100M_in = 0;
reg rst_in = 1;
reg rstn_in = 0;
    
wire tmds_clock_out_n;
wire tmds_clock_out_p;
wire tmds_data0_out_n;
wire tmds_data0_out_p;
wire tmds_data1_out_n;
wire tmds_data1_out_p;
wire tmds_data2_out_n;
wire tmds_data2_out_p;

hdmi_ctrl_test_wrapper UUT(
    .clk100M_in(clk100M_in),
    .rst_in(rst_in),
    .rstn_in(rstn_in),
    .tmds_clock_out_n(tmds_clock_out_n),
    .tmds_clock_out_p(tmds_clock_out_p),
    .tmds_data0_out_n(tmds_data0_out_n),
    .tmds_data0_out_p(tmds_data0_out_p),
    .tmds_data1_out_n(tmds_data1_out_n),
    .tmds_data1_out_p(tmds_data1_out_p),
    .tmds_data2_out_n(tmds_data2_out_n),
    .tmds_data2_out_p(tmds_data2_out_p)
);

always #5 clk100M_in = ~clk100M_in;

initial begin
    #20 rst_in = 0;
    #40 rstn_in = 1;
end

endmodule
