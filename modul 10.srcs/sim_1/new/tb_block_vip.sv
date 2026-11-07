`timescale 1ns / 1ps

// Testbench simulasi Block Design: AXI VIP (master) -> SmartConnect -> axi_lite_gpio_v1_0
// Port wrapper: clk_100MHz, reset_rtl_0 (ACTIVE HIGH), led[15:0], sw[15:0]
// SESUAIKAN: BASE dengan Offset Address di tab Address Editor.

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

module tb_block_vip;

  localparam [31:0] BASE = 32'h00000000;   // sesuai Address Editor (0x0, 4K)

  bit         clk = 0;
  bit         rst = 1;                     // reset aktif tinggi
  wire [15:0] led;
  reg  [15:0] sw  = 16'h0000;

  design_1_wrapper DUT (
    .clk_100MHz  (clk),
    .reset_rtl_0 (rst),
    .led         (led),
    .sw          (sw)
  );

  always #5 clk = ~clk;                    // 100 MHz

  design_1_axi_vip_0_0_mst_t master_agent;
  xil_axi_resp_t             resp;
  xil_axi_data_beat          rd;
  int                        errors = 0;

  // Pengaman: hentikan simulasi bila macet
  initial begin
    #400us;
    $display("TIMEOUT: simulasi macet.");
    $finish;
  end

  initial begin
    master_agent = new("master_vip", DUT.design_1_i.axi_vip_0.inst.IF);
    master_agent.start_master();

    // Reset aktif tinggi 200 ns, lalu lepas
    rst = 1;
    #200;
    rst = 0;

    // Tunggu Clocking Wizard lock dan reset sistem lepas
    #20us;

    // Test 1: tulis reg0 (LED)
    master_agent.AXI4LITE_WRITE_BURST(BASE + 32'h0, 0, 32'h0000A5A5, resp);
    #50;
    if (led !== 16'hA5A5) begin $display("GAGAL Test 1: led = %h", led); errors++; end
    else                         $display("OK    Test 1: led = A5A5");

    // Test 2: baca balik reg0
    master_agent.AXI4LITE_READ_BURST(BASE + 32'h0, 0, rd, resp);
    if (rd !== 32'h0000A5A5) begin $display("GAGAL Test 2: rd = %h", rd); errors++; end
    else                          $display("OK    Test 2: reg0 = %h", rd);

    // Test 3: baca reg1 (switch)
    sw = 16'h1234;
    #100;                                   // tunggu sinkronisasi 2 FF
    master_agent.AXI4LITE_READ_BURST(BASE + 32'h4, 0, rd, resp);
    if (rd !== 32'h00001234) begin $display("GAGAL Test 3: rd = %h", rd); errors++; end
    else                          $display("OK    Test 3: reg1 = %h", rd);

    // Test 4: reg1 read-only
    master_agent.AXI4LITE_WRITE_BURST(BASE + 32'h4, 0, 32'hFFFFFFFF, resp);
    master_agent.AXI4LITE_READ_BURST (BASE + 32'h4, 0, rd, resp);
    if (rd !== 32'h00001234) begin $display("GAGAL Test 4: rd = %h", rd); errors++; end
    else                          $display("OK    Test 4: reg1 tetap read-only");

    // Test 5: walking pattern (meniru firmware)
    for (int i = 0; i < 16; i++) begin
      master_agent.AXI4LITE_WRITE_BURST(BASE + 32'h0, 0, (32'h1 << i), resp);
      #40;
      if (led !== (16'h1 << i)) begin $display("GAGAL Test 5 bit %0d: led = %h", i, led); errors++; end
    end
    $display("OK    Test 5: walking pattern selesai");

    if (errors == 0) $display("SIMULASI BLOCK DESIGN SELESAI: SEMUA TEST LULUS.");
    else             $display("SIMULASI BLOCK DESIGN SELESAI: %0d TEST GAGAL.", errors);
    $finish;
  end

endmodule