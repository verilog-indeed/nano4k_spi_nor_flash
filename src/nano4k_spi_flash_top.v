module nano4k_spi_flash_top(
								input crystalClk,
								input reset, //active low

								input fMiso,
								output fChipSel,
								output fMosi,
								output fMclk	
							);
	wire s_clock;

	Gowin_CLKDIV divide_by_eight_serial(
        .clkout(s_clock), //output clkout
        .hclkin(crystalClk), //input hclkin
        .resetn(reset) //input resetn
    );

	reg[21:0] testStateCounter;
	always@(posedge s_clock) begin
		if (reset) begin
			testStateCounter <= testStateCounter + 1;
			if (writeStrobe || readStrobe) begin
				i_enable_n <= 1;
			end
			case (testStateCounter)
				1110: begin
					flashCmd <= `WREN;
					i_enable_n <= 1;
				end
				1111: begin
					i_enable_n <= 0;
				end
				1200: begin
					flashCmd <= `PE;
					flashAddr <= 22'hA001;
					i_enable_n <= 1;
				end
				1201: begin
					i_enable_n <= 0;
				end
				5055: begin
					flashCmd <= `RDCR;
					i_enable_n <= 1;
				end
				5056: begin
					i_enable_n <= 0;
				end
				5311: begin
					flashCmd <= `RDID;
					i_enable_n <= 1;
				end
				5312: begin
					i_enable_n <= 0;
				end
				5350: begin
					i_enable_n <= 1;
					wr_data <= wr_data + 1;
				end
				
				900300: begin
					flashCmd <= `WREN;
					i_enable_n <= 0;
				end
				990250: begin
					flashCmd <= `RDSR;
					i_enable_n <= 0;
				end
				990300: begin
					flashCmd <= `PP;
					flashAddr <= 22'hA001;
					i_enable_n <= 0;
					wr_data <= wr_data + 1;
				end
				
				990350: begin
					flashCmd <= `RDSR;
					i_enable_n <= 0;
				end
				
				1000420: begin
					flashCmd <= `FREAD;
					flashAddr <= 22'hA001;
					i_enable_n <= 0;
				end
				default: begin
				end
			endcase
		end else begin
			testStateCounter <= 0;
			//flashAddr <= 0;
			flashCmd <= 0;
			i_enable_n <= 1;
			wr_data <= 0;
		end
	end

	reg i_enable_n;
	reg[7:0] flashCmd;
	reg[21:0] flashAddr;
	reg[7:0] wr_data;
	wire[7:0] rd_data;
	reg[7:0] readBuff;
	wire writeStrobe;
	wire readStrobe;

	nano4k_spi_flash dut(
        .serialClk(s_clock),
        .interfaceEnable_n(i_enable_n),
        .fCommand(flashCmd),
        .fAddress(flashAddr),
        .fData_WR(wr_data),
        .fData_RD(rd_data),
        .RdDataValid(readStrobe),
        .WrDataReady(writeStrobe),

        .MISO(fMiso),
        .MOSI(fMosi),
        .MCLK(fMclk),
        .CS_n(fChipSel)
    );

	initial begin
		testStateCounter <= 0;
		flashAddr <= 0;
		flashCmd <= 0;
		i_enable_n <= 1;
		wr_data <= 0;
	end
endmodule