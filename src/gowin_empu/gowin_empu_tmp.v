//Copyright (C)2014-2022 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: GowinSynthesis V1.9.8.06-1
//Part Number: GW1NSR-LV4CQN48PC7/I6
//Device: GW1NSR-4C
//Created Time: Wed Jul 20 15:19:03 2022

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	Gowin_EMPU_Top your_instance_name(
		.sys_clk(sys_clk_i), //input sys_clk
		.gpioin(gpioin_i), //input [15:0] gpioin
		.gpioout(gpioout_o), //output [15:0] gpioout
		.gpioouten(gpioouten_o), //output [15:0] gpioouten
		.uart0_rxd(uart0_rxd_i), //input uart0_rxd
		.uart0_txd(uart0_txd_o), //output uart0_txd
		.reset_n(reset_n_i) //input reset_n
	);

//--------Copy end-------------------
