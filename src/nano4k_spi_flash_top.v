module nano4k_spi_flash_top(
								input crystalClk,
								input reset, //active low
								output [3:0] ledOut,
								output uartTX,

								input fMiso,
								output fChipSel,
								output fMosi,
								output fMclk	
							);
	wire i_clock;
	wire s_clock;

	Gowin_CLKDIV divide_by_eight_serial(
        .clkout(s_clock), //output clkout
        .hclkin(crystalClk), //input hclkin
        .resetn(reset) //input resetn
    );

	Gowin_CLKDIV divide_by_eight_interface(
        .clkout(i_clock), //output clkout
        .hclkin(s_clock), //input hclkin
        .resetn(reset) //input resetn
    );

	reg[21:0] testStateCounter;
	always@(posedge i_clock) begin
		if (reset) begin
			testStateCounter <= testStateCounter + 1;
			if ((writeStrobe && (flashCmd == `RSTEN || flashCmd == `RST || flashCmd == `WREN))) begin
				i_enable_n <= 1;
			end
			/*if (readStrobe) begin
				i_enable_n <= 1;
				readBuff <= rd_data;
			end*/
			case (testStateCounter)
				
				0: begin
					//wr_data <= wr_data + 1;
					flashCmd <= `RSTEN;
				end
				100: begin
					i_enable_n <= 0;
				end
				1010: begin
					flashCmd <= `WREN;
				end
				1011: begin
					i_enable_n <= 0;
				end
				5000: begin
					flashCmd <= `RDSR;
					i_enable_n <= 0;
				end
				5005: begin
					flashCmd <= `RDCR;
					i_enable_n <= 1;
				end
				5006: begin
					i_enable_n <= 0;
				end
				5011: begin
					flashCmd <= `RDID;
					i_enable_n <= 1;
				end
				5012: begin
					i_enable_n <= 0;
				end
				5019: begin
					i_enable_n <= 1;
				end
				100300: begin
					flashCmd <= `PP;
					flashAddr <= 8'hA000;
					wr_data <= 8'h05;
				end
				100301: begin
					i_enable_n <= 0;
				end
				100309: begin
					i_enable_n <= 1;
				end
				100320: begin
					flashCmd <= `READ;
					flashAddr <= 8'hA000;
					i_enable_n <= 0;
				end
				100332: begin
					//i_enable_n <= 1;
				end
				default: begin
				end
			endcase
		end else begin
			testStateCounter <= 0;
			flashAddr <= 0;
			flashCmd <= 0;
			i_enable_n <= 1;
			wr_data <= 0;
		end
	end

	reg i_enable_n;
	reg[7:0] flashCmd;
	reg[7:0] flashAddr;
	reg[7:0] wr_data;
	wire[7:0] rd_data;
	reg[7:0] readBuff;
	wire writeStrobe;
	wire readStrobe;
	assign ledOut = ~(readBuff[3:0]);

	nano4k_spi_flash dut(
        .interfaceClk(i_clock),
        .serialClk(s_clock),
        .interfaceEnable_n(i_enable_n),
        .fCommand(flashCmd),
        .fAddress({14'b0,flashAddr}),
        .fData_WR(wr_data),
        .fData_RD(rd_data),
        .RdDataValid(readStrobe),
        .WrDataReady(writeStrobe),

        .MISO(fMiso),
        .MOSI(fMosi),
        .MCLK(fMclk),
        .CS_n(fChipSel)
    );
/*
	Gowin_EMPU_Top cortexM3(
		.sys_clk(crystalClk), //input sys_clk
		//.gpioin({wr_data, readBuff}), //input [15:0] gpioin
		.gpioin(testStateCounter[15:0]),
		//.gpioout(gpioout_o), //output [15:0] gpioout
		//.gpioouten(1'b0), //output [15:0] gpioouten
		//.uart0_rxd(uart0_rxd_i), //input uart0_rxd
		.uart0_txd(uartTX), //output uart0_txd
		.reset_n(reset) //input reset_n
	);
*/
	initial begin
		testStateCounter <= 0;
		flashAddr <= 0;
		flashCmd <= 0;
		i_enable_n <= 1;
		wr_data <= 0;
	end
endmodule