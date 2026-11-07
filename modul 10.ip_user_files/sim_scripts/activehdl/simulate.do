transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+tb_block_vip  -L xil_defaultlib -L xilinx_vip -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.tb_block_vip xil_defaultlib.glbl

do {tb_block_vip.udo}

run 1000ns

endsim

quit -force
