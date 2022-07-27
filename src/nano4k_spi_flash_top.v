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
		if (!reset) begin
			testStateCounter <= 0;
			flashCmd <= 0;
			i_enable_n <= 1;
			wr_data <= 0;
		end else begin
			testStateCounter <= testStateCounter + 1;
			if (cmdHasFinished) begin
				//deactivate spi flash when a command is completed
				i_enable_n <= 1;
			end
			case (testStateCounter)
				1110: begin
					//must make sure write enable latch is set before any erase/write operation
					flashCmd <= `WREN;
					i_enable_n <= 0;
				end

				1200: begin
					//erase page from 0xA000 to 0xA0FF
					flashCmd <= `PE;
					flashAddr <= 22'hA001;
					i_enable_n <= 0;
				end

				5055: begin
					//Read configuration register (output voltage info, hold/reset pin mode etc)
					flashCmd <= `RDCR;
					i_enable_n <= 0;
				end

				105311: begin
					//Read manufacturer JEDEC ID (0x85)
					flashCmd <= `RDID;
					i_enable_n <= 0;
				end
				
				900300: begin
					flashCmd <= `WREN;
					i_enable_n <= 0;
				end

				990250: begin
					//Read status register (busy flag, write enable latch status etc)
					flashCmd <= `RDSR;
					i_enable_n <= 0;
				end

				990300: begin
					//Page program, write wr_data byte to address 0xA001
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
					//Read starting from address 0xA001, FREAD has a higher frequency ceiling than READ
					flashCmd <= `FREAD;
					flashAddr <= 22'hA001;
					i_enable_n <= 0;
				end
				default: begin
				end
			endcase
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
	wire cmdHasFinished;

	nano4k_spi_flash dut(
        .serialClk(s_clock),
        .interfaceEnable_n(i_enable_n),
        .fCommand(flashCmd),
        .fAddress(flashAddr),
        .fData_WR(wr_data),
        .fData_RD(rd_data),
        .RdDataValid(readStrobe),
        .WrDataReady(writeStrobe),
		.cmdFinished(cmdHasFinished),

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