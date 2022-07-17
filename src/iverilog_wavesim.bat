del a.out sim_result.vcd
iverilog -g2001 nano4k_spi_flash_tb.v
vvp a.out
gtkwave sim_result.vcd signal_save.gtkw