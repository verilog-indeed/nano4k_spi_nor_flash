//P25Q32H command list, see datasheet page 22
`define FREAD 8'h0B //Byte-read, keep interface active for array read, Fmax is around 120MHz
`define READ 8'h03 //Byte-read, keep interface active for array read, Fmax is around 70MHz
`define RSTEN 8'h66 //Reset Enable
`define RST 8'h99   //Soft reset
`define PP 8'h02 //page program, if interface is kept active for more than 256 bytes the erase will wrap around to the set address.
`define PE 8'h81 //page erase, the least significant byte is irrelevant since the entire page (256 bytes) will be erased from 0xXXXX00 to 0xXXXXFF
`define WREN 8'h06	//set the write enable latch, remember to issue this command before erase/program instructions
`define RDSR 8'h05	//read status register that contains the busy flag/write enable status etc, Little-endian, see datasheet pg.29
`define RDCR 8'h15	//read configuration register for information about output drive strength, physical reset enable etc
`define RDID 8'h9F	//read JEDEC ID + device ID, expect bytes 0x85, 0x60 and 0x16 respectively

module nano4k_spi_flash(
                            /* Active-low
							Interface enable, directly wired to the flash's chip select
							Interface resets itself when interfaceEnable_n is deasserted
							*/
                            input interfaceEnable_n,

							/*
							Serial clock for both interface operation and data transmission
							*/
                            input serialClk,
							
							/*
							Flash command (instruction) input, see datasheet pg.22
							Commands defined in this file are the only ones guaranteed to work properly.
							*/
                            input [7:0] fCommand,
							
							//R/W address input of the flash data
                            input [23:0] fAddress,

							//Write data byte input
                            input [7:0] fData_WR,

							//Read data byte output.
                            output reg [7:0] fData_RD,

							/* Active high
							Indicates that the fData_RD byte is valid and safe to sample.
							*/
                            output reg RdDataValid,

							/* Active high
							Indicates that byte-n has begun transmission in page program instruction,
							and the interface is ready to accept byte-(n+1) for the next transmission.
							Byte-(n+1) is sampled on the 7-th rising serialClk edge after WrDataReady goes low,
							Byte-0 is sampled on the rising edge right before WrDataReady goes high for the first time.
							Preferably fData_WR should have byte-0 at the same time
							when enabling the interface and hold it until WrDataReady goes high.
							*/
                            output reg WrDataReady,

							/* Active high
							Indicates that the instruction has finished execution and/or 
							one byte has been transmitted/received in array read/write mode.
							When you wish to end the command properly, deassert interfaceEnable_n
							on the rising edge when cmdFinished is high.
							*/
							output reg cmdFinished,

                            //flash chip pins
                            input MISO,
                            output reg MOSI,
                            output MCLK,
                            output CS_n
                        );
    reg[7:0] currentCmd;
    reg[23:0] currentAddr;
    reg[3:0] flashState;

    //Flash interface states
    localparam IDLE = 0;
    localparam CMD_TX = 1;
    localparam ADDR_TX = 2;
    localparam DMMY_WAIT = 3;
    localparam DATA_PHASE = 4;

    //determines multiplication (bitshift) factor of phase cycles based on the transfer mode
    //2'b11 for single IO SPI, 2'b10 for dual IO SPI, 2'b01 for quad IO SPI
    reg[1:0] currentSPIMode;

    reg[4:0] addrCycleCount;
    reg[5:0] dmmyCycleCount;
    //num of required cycles for each phase depends on instruction and transfer mode (1xIO, 2xIO, 4xIO)
    //num of cycles = num of bytes * (8 for single SPI, 4 for dual SPI, 2 for quad SPI)
    wire[4:0] numOfAddrCycles = 3 << currentSPIMode;
    wire[5:0] numOfDmmyCycles = 1 << currentSPIMode; //TODO add support for RUID?
    wire[3:0] numOfDataCycles = 1 << currentSPIMode;


    //serializer active-low clock control
    reg serMclkEnable_n;
    //deserializer active-low clock control
    wire desMclkEnable_n = !deserializerEnable;

    //CPOL=1 idle-high SPI clock
    //MCLK active when either or both serializer/deserializer clock controls are active
    assign MCLK = serialClk | (serMclkEnable_n && desMclkEnable_n) | CS_n;
	assign CS_n = interfaceEnable_n;
	reg internalEn_n;

    always@(posedge serialClk) begin
		internalEn_n <= interfaceEnable_n;
        if (!internalEn_n) begin
            case (flashState)
                IDLE: begin
                    currentCmd <= fCommand;
                    currentAddr <= fAddress;
                    flashState <= CMD_TX;
                end
                CMD_TX: begin
                    if (internalWriteReady) begin
                        if (cmdHasAddrPhase)  begin
                            flashState <= ADDR_TX;
                        end else if (cmdHasDmmyPhase) begin
                            flashState <= DMMY_WAIT;
                        end else if (cmdHasDataPhase) begin
                            flashState <= DATA_PHASE;
							serializerByteBuffer <= fData_WR;
                        end else begin
                            flashState <= IDLE;
                        end
                        serializerEnable <= 0;
                    end else begin
                        serializerEnable <= 1;
                        serializerByteBuffer <= currentCmd;
                    end
                end
                ADDR_TX: begin
                    if (addrCycleCount == numOfAddrCycles) begin
                        addrCycleCount <= 0;
                        if (cmdHasDmmyPhase) begin 
                            flashState <= DMMY_WAIT;
                        end else if (cmdHasDataPhase) begin
                            flashState <= DATA_PHASE;
							serializerByteBuffer <= fData_WR;
                        end else begin
                            flashState <= IDLE;
                        end
                        serializerEnable <= 0;
                    end else begin
						if (addrCycleCount[2:0] == 3'b0) begin
							//current cycle is multiple of 8, shift in the next byte
                        	{serializerByteBuffer, currentAddr} <= {serializerByteBuffer, currentAddr} << 8;
						end
                        serializerEnable <= 1;
                        addrCycleCount <= addrCycleCount + 1;
                    end 
                    
                end
                DMMY_WAIT: begin
                    //retransmit whatever is in the buffer to waste SPI clock cycles
                    if (dmmyCycleCount == numOfDmmyCycles) begin
                        serializerEnable <= 0;
                        dmmyCycleCount <= 0;
                        if (cmdHasDataPhase) begin
                            flashState <= DATA_PHASE;
							serializerByteBuffer <= fData_WR;
                        end else begin
                            flashState <= IDLE;
							serializerEnable <= 0;
                        end
                    end else begin
                        //waste MCLK cycles, data sent/received is Don't Care
                        serializerEnable <= 1;
                        dmmyCycleCount <= dmmyCycleCount + 1;
                    end
                end
                DATA_PHASE: begin
					if (isReadCmd) begin
						deserializerEnable <= 1;
						serializerEnable <= 0;

						//deserializerBuffer is one spi clock behind, shift in the last bit from MISO
						if (deserializerCycleCount == 7) begin
							fData_RD <= {deserializerBuffer, MISO};
						end
					end else begin
						serializerEnable <= 1;
						deserializerEnable <= 0;
						if (serializerCycleCount == 7) begin
							//sample the next byte for transmission
							serializerByteBuffer <= fData_WR;
						end
					end
                    //deassert interfaceEnable_n to exit the array read/write
                end
            endcase
        end else begin
            flashState <= IDLE;
            serializerEnable <= 0;
            addrCycleCount <= 0;
            dmmyCycleCount <= 0;
            deserializerEnable <= 0;
        end
    end

    reg serializerEnable;
    reg[7:0] serializerByteBuffer;
    reg[7:0] mosiOut;
    reg[3:0] serializerCycleCount;
	reg internalWriteReady;

    //serialization block
    //load output data and enable SPI clock out on cycle 0
    //TODO add support for 2xIO, 4xIO SPI?
    always@(negedge serialClk) begin
        if (serializerEnable) begin
            if (serializerCycleCount == 0) begin
                internalWriteReady <= 0;
                serMclkEnable_n <= 0;
                mosiOut <= serializerByteBuffer << 1;
                MOSI <= serializerByteBuffer[7];
            end else begin
                {MOSI, mosiOut} <= {MOSI, mosiOut} << 1;
            end
            if (serializerCycleCount == 7) begin
                internalWriteReady <= 1;
                serializerCycleCount <= 0;
            end else begin 
                serializerCycleCount <= serializerCycleCount + 1;
            end
        end else begin
            mosiOut <= 0;
            serMclkEnable_n <= 1;
            internalWriteReady <= 0;
            serializerCycleCount <= 0;
            MOSI <= 0;
        end
    end

    reg deserializerEnable;

    reg[3:0] deserializerCycleCount;
    reg[7:0] deserializerBuffer;
	reg internalReadValid;

    
	//deserialization block
    //TODO add support for 2xIO, 4xIO SPI?
    always@(posedge serialClk) begin
        if (deserializerEnable) begin
            if (deserializerCycleCount == 0) begin
                internalReadValid <= 0;
            end
            deserializerBuffer <= {deserializerBuffer, MISO};
            if (deserializerCycleCount == 7) begin
                internalReadValid <= 1;
                deserializerCycleCount <= 0;
            end else begin
                deserializerCycleCount <= deserializerCycleCount + 1;
            end
        end else begin
            deserializerBuffer <= 0;
            internalReadValid <= 0;
            deserializerCycleCount <= 0;
        end
    end

	//garbage garbage stinky block rewrite please
	//TODO This will not work with quad SPI, fix it
	always@(negedge serialClk) begin
		//need to check if the command has a data phase to prevent exiting early, it is not redundant
		if (cmdHasDataPhase) begin
			if (flashState == DATA_PHASE) begin
				if (isReadCmd) begin
					cmdFinished <= (deserializerCycleCount == 7);
				end else begin
					cmdFinished <= (serializerCycleCount == 7);
				end
			end else begin
				cmdFinished <= 0;
			end
			RdDataValid <= internalReadValid && (flashState == DATA_PHASE);
			WrDataReady <= internalWriteReady && (flashState == DATA_PHASE);
		end else if (cmdHasDmmyPhase) begin
			if ((flashState == DMMY_WAIT) && (dmmyCycleCount == numOfDmmyCycles)) begin
				cmdFinished <= 1;
			end else begin
				cmdFinished <= 0;
			end
			RdDataValid <= internalReadValid && (dmmyCycleCount == numOfDmmyCycles);
			WrDataReady <= internalWriteReady && (dmmyCycleCount == numOfDmmyCycles);
		end else if (cmdHasAddrPhase) begin
			if ((flashState == ADDR_TX) && (addrCycleCount == numOfAddrCycles)) begin
				cmdFinished <= 1;
			end else begin
				cmdFinished <= 0;
			end
			RdDataValid <= internalReadValid && (addrCycleCount == numOfAddrCycles);
			WrDataReady <= internalWriteReady && (addrCycleCount == numOfAddrCycles);
		end else if (flashState == CMD_TX) begin
			cmdFinished <= (serializerCycleCount == 7);
			RdDataValid <= internalReadValid;
			WrDataReady <= internalWriteReady;
		end else begin
			cmdFinished <= 0;
			RdDataValid <= 0;
			WrDataReady <= 0;
		end
	end	

    reg cmdHasAddrPhase;
    reg cmdHasDmmyPhase;
    reg cmdHasDataPhase;
    reg isReadCmd; //1 for a data read command, 0 for a data write command.
    //combinational block for determining phases required for each command
    always@(*) begin
        case(currentCmd)
            `READ: begin
                cmdHasAddrPhase = 1;
                cmdHasDmmyPhase = 0;
                cmdHasDataPhase = 1;
                isReadCmd = 1;
            end
            `FREAD: begin
                cmdHasAddrPhase = 1;
                cmdHasDmmyPhase = 1;
                cmdHasDataPhase = 1;
                isReadCmd = 1;
            end
            `PP: begin
                cmdHasAddrPhase = 1;
                cmdHasDmmyPhase = 0;
                cmdHasDataPhase = 1;
                isReadCmd = 0;
            end
			`PE: begin
				cmdHasAddrPhase = 1;
                cmdHasDmmyPhase = 0;
                cmdHasDataPhase = 0;
                isReadCmd = 0;
			end
			`RDSR, `RDCR, `RDID: begin
				cmdHasAddrPhase = 0;
                cmdHasDmmyPhase = 0;
                cmdHasDataPhase = 1;
				isReadCmd = 1;
			end
            default: begin
                cmdHasAddrPhase = 0;
                cmdHasDmmyPhase = 0;
                cmdHasDataPhase = 0;
                isReadCmd = 0;
            end
        endcase
    end

    initial begin
        serializerCycleCount <= 0;
        serializerByteBuffer <= 0;
        deserializerBuffer <= 0;
        addrCycleCount <= 0;
        dmmyCycleCount <= 0;
        currentSPIMode <= 2'b11;
        serMclkEnable_n <= 1;
        WrDataReady <= 0;
        RdDataValid <= 0;
		internalWriteReady <= 0;
		internalReadValid <= 0;
        serializerEnable <= 0;
        mosiOut <= 0;
        currentCmd <= 0; 
        MOSI <= 0;
        fData_RD <= 0;
    end
endmodule