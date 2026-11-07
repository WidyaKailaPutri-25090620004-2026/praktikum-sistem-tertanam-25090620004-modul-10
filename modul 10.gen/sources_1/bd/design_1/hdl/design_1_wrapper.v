//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2026.1 (win64) Build 6511674 Tue Jun 16 11:02:23 MDT 2026
//Date        : Mon Nov  2 14:40:58 2026
//Host        : Aspire-A3 running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (clk_100MHz,
    led,
    reset_rtl_0,
    sw);
  input clk_100MHz;
  output [15:0]led;
  input reset_rtl_0;
  input [15:0]sw;

  wire clk_100MHz;
  wire [15:0]led;
  wire reset_rtl_0;
  wire [15:0]sw;

  design_1 design_1_i
       (.clk_100MHz(clk_100MHz),
        .led(led),
        .reset_rtl_0(reset_rtl_0),
        .sw(sw));
endmodule
