module nano4k_spi_flash_top(
								input crystalClk,
								input reset,
								output [2:0] ledOut,
								output reg readStrobeIndicator,

								input fMiso,
								output fChipSel,
								output fMosi,
								output fMclk	
							);
	wire i_clock;
	wire s_clock = crystalClk;

	Gowin_CLKDIV divide_by_eight(
        .clkout(i_clock), //output clkout
        .hclkin(s_clock), //input hclkin
        .resetn(reset) //input resetn
    );

	reg[21:0] testStateCounter;
	always@(posedge i_clock) begin
		if (reset) begin
			testStateCounter <= testStateCounter + 1;
			if ((writeStrobe && (flashCmd == `RSTEN || flashCmd == `RST))) begin
				i_enable_n <= 1;
			end
			if (readStrobe) begin
				readStrobeIndicator <= !readStrobeIndicator;
				i_enable_n <= 1;
				readBuff <= rd_data;
			end
			case (testStateCounter)
				0: begin
					wr_data <= wr_data + 1;
					flashCmd <= `RSTEN;
				end
				1: begin
					i_enable_n <= 0;
				end
				10: begin
					flashCmd <= `RST;
				end
				11: begin
					i_enable_n <= 0;
				end
				300: begin
					flashCmd <= `PP;
					flashAddr <= 8'hA0;
					//wr_data <= 8'h05;
				end
				301: begin
					i_enable_n <= 0;
				end
				306: begin
					i_enable_n <= 1;
					flashCmd <= `READ;
					flashAddr <= 8'hA0;
				end
				310: begin
					i_enable_n <= 0;
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
			readStrobeIndicator <= 0;
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
	assign ledOut = {!(readBuff[2:0])};

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

	initial begin
		testStateCounter <= 0;
		flashAddr <= 0;
		flashCmd <= 0;
		i_enable_n <= 1;
		wr_data <= 0;
		readStrobeIndicator <= 0;
	end
endmodule