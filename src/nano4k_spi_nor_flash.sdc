//Copyright (C)2014-2022 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.03 Education
//Created Time: 2022-07-23 19:41:07
create_clock -name crystal -period 37.037 -waveform {0 18.518} [get_ports {crystalClk}]
