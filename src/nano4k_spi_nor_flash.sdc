//Copyright (C)2014-2022 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.06-1 
//Created Time: 2022-07-18 14:26:30
create_clock -name crystal -period 37.037 -waveform {0 18.518} [get_ports {crystalClk}]
create_generated_clock -name interface_clk -source [get_ports {crystalClk}] -master_clock crystal -divide_by 8 [get_nets {i_clock}]
