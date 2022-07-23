//P25Q32H command list, see datasheet page 22
`define FREAD 8'h0B //Max freq is around 120MHz
`define READ 8'h03 //Max freq allowed is around 70MHz
`define RSTEN 8'h66 //Reset Enable
`define RST 8'h99   //Soft reset
`define PP 8'h02 //page program
`define WREN 8'h06	//writing enable
`define RDSR 8'h05	//read status register
`define RDCR 8'h15	//read configuration register
`define RDID 8'h9F	//read JEDEC ID + device ID

module nano4k_spi_flash(
                            //input reset_n, //interface resets itself when interfaceEnable_n is deasserted
                            input interfaceEnable_n,
                            input interfaceClk,
                            input serialClk,
                            input [7:0] fCommand,
                            input [21:0] fAddress,
                            input [7:0] fData_WR,
                            output reg [7:0] fData_RD,
                            output reg RdDataValid,
                            output reg WrDataReady,

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

    always @(posedge interfaceClk) begin
        //TODO raise an exit flag whenever the interface is about to go IDLE?
        if (!interfaceEnable_n) begin
            //CS_n <= 0;
            case (flashState)
                IDLE: begin
                    currentCmd <= fCommand;
                    //chip expects 24-bit address but only need 22 bits to address the available 4MiB
                    currentAddr <= {2'b0, fAddress};
                    flashState <= CMD_TX;
                end
                CMD_TX: begin
                    if (WrDataReady) begin
                        if (cmdHasAddrPhase)  begin
                            flashState <= ADDR_TX;
                        end else if (cmdHasDmmyPhase) begin
                            flashState <= DMMY_WAIT;
                        end else if (cmdHasDataPhase) begin
                            flashState <= DATA_PHASE;
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
                    if (addrCycleCount == 3) begin
                        addrCycleCount <= 0;
                        if (cmdHasDmmyPhase) begin 
                            flashState <= DMMY_WAIT;
                        end else if (cmdHasDataPhase) begin
                            flashState <= DATA_PHASE;
                        end else begin
                            flashState <= IDLE;
                        end
                        serializerEnable <= 0;
                    end else begin
                        {serializerByteBuffer, currentAddr} <= {serializerByteBuffer, currentAddr} << 8;
                        serializerEnable <= 1;
                        addrCycleCount <= addrCycleCount + 1;
                    end 
                    
                end
                DMMY_WAIT: begin
                    //retransmit whatever is in the buffer to waste SPI clock cycles
                    if (dmmyCycleCount == numOfDmmyBytes) begin
                        serializerEnable <= 0;
                        dmmyCycleCount <= 0;
                        if (cmdHasDataPhase) begin
                            flashState <= DATA_PHASE;
                        end else begin
                            flashState <= IDLE;
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
                        if (RdDataValid) begin
							//doesn't work in simulation, works IRL
                            fData_RD <= deserializerBuffer;
                            //This isn't nice, but deserializer is one spi clock behind
                            //fData_RD <= {deserializerBuffer, MISO};
                        end
                    end else begin
                        serializerEnable <= 1;
                        serializerByteBuffer <= fData_WR;
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
            //CS_n <= 1;
        end
    end

    reg[1:0] addrCycleCount;
    reg[2:0] dmmyCycleCount;
    reg[2:0] numOfDmmyBytes;

    //serializer active-low clock control
    reg serMclkEnable_n;
    //deserializer active-low clock control
    wire desMclkEnable_n = !deserializerEnable;

    //CPOL=1 idle-high SPI clock
    //MCLK active when either or both serializer/deserializer clock controls are active
    assign MCLK = serialClk | (serMclkEnable_n && desMclkEnable_n);
	assign CS_n = interfaceEnable_n;

    reg serializerEnable;
    reg[7:0] serializerByteBuffer;
    reg[7:0] mosiOut;
    reg[3:0] serializerCycleCount;

    //serialization block
    //load output data and enable SPI clock out on cycle 0
    always@(negedge serialClk) begin
        if (serializerEnable) begin
            if (serializerCycleCount == 0) begin
                serMclkEnable_n <= 0;
                WrDataReady <= 0;
                mosiOut <= serializerByteBuffer << 1;
                MOSI <= serializerByteBuffer[7];
            end else begin
                {MOSI, mosiOut} <= {MOSI, mosiOut} << 1;
            end

            if (serializerCycleCount == 7) begin
                //raise ready flag just in time for interfaceClk domain to sample it
                WrDataReady <= 1;
                serializerCycleCount <= 0;
            end else begin 
                serializerCycleCount <= serializerCycleCount + 1;
            end
        end else begin
            mosiOut <= 0;
            serMclkEnable_n <= 1;
            WrDataReady <= 0;
            serializerCycleCount <= 0;
            MOSI <= 0;
        end
    end

    reg deserializerEnable;

    reg[3:0] deserializerCycleCount;
    reg[7:0] deserializerBuffer;
	//deserialization block
    always@(posedge serialClk) begin
        if (deserializerEnable) begin
            if (deserializerCycleCount == 0) begin
                RdDataValid <= 0;
            end
            deserializerBuffer <= {deserializerBuffer, MISO};

            if (deserializerCycleCount == 6) begin
                RdDataValid <= 1;
            end

            if (deserializerCycleCount == 7) begin
                deserializerCycleCount <= 0;
            end else begin
                deserializerCycleCount <= deserializerCycleCount + 1;
            end
        end else begin
            deserializerBuffer <= 0;
            RdDataValid <= 0;
            deserializerCycleCount <= 0;
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
        numOfDmmyBytes <= 1;
        serMclkEnable_n <= 1;
        WrDataReady <= 0;
        RdDataValid <= 0;
        serializerEnable <= 0;
        mosiOut <= 0;
        currentCmd <= 0; 
        MOSI <= 0;
        fData_RD <= 0;
    end
endmodule