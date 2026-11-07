transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xilinx_vip
vlib activehdl/xil_defaultlib

vmap xilinx_vip activehdl/xilinx_vip
vmap xil_defaultlib activehdl/xil_defaultlib

vlog -work xilinx_vip  -sv2k12 "+incdir+D:/Vivado/2026.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xil_defaultlib \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/axi_vip_if.sv" \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/clk_vip_if.sv" \
"D:/Vivado/2026.1/Vivado/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+D:/Vivado/2026.1/Vivado/data/rsb/busdef" "+incdir+../../../modul 10.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../modul 10.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../modul 10.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../modul 10.gen/sources_1/bd/design_1/ipshared/ee6d" "+incdir+D:/Vivado/2026.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xil_defaultlib \
"../../../modul 10.srcs/sim_1/new/tb_block_vip.sv" \

vlog -work xil_defaultlib \
"glbl.v"

