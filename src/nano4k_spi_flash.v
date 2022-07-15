//P25Q32H command list, see datasheet page 22
`define FREAD 8'h0B
`define READ 8'h03
`define RSTEN 8'h66
`define RST 8'h99
`define PP 8'h02

module nano4k_spi_flash(
                        input reset_n,
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
                        output reg CS_n
                        );
    reg[7:0] currentCmd;
    reg[7:0] writeBuffer;
    reg[23:0] currentAddr;
    reg[3:0] flashState;
    //Flash interface states
    localparam IDLE = 0;
    localparam CMD_RECEIVED = 1;
    localparam CMD_SENT = 2;
    localparam ADDR_TX = 3;
    localparam DMMY_WAIT = 4;
    localparam DATA_PHASE = 5;

    always @(posedge interfaceClk) begin
        //TODO raise an exit flag whenever the interface is about to go IDLE?
        if (!interfaceEnable_n) begin
            CS_n <= 0;
            case (flashState)
                IDLE: begin
                    currentCmd <= fCommand;
                    //chip expects 24-bit address but only need 22 bits to address the available 4MiB
                    currentAddr <= {2'b0, fAddress};
                    flashState <= CMD_RECEIVED;
                end
                CMD_RECEIVED: begin
                    serializerEnable <= 1;
                    serializerByteBuffer <= currentCmd;
                    mclkEnable_n <= 0; //activate MCLK
                    flashState <= CMD_SENT;
                end
                CMD_SENT: begin
                    if (WrDataReady) begin
                        serializerEnable <= 0;
                        //command transmitted, disable MCLK
                        mclkEnable_n <= 1; 
                        if (cmdHasAddrPhase) 
                            flashState <= ADDR_TX;
                        else if (cmdHasDmmyPhase)
                            flashState <= DMMY_WAIT;
                        else if (cmdHasDataPhase)
                            flashState <= DATA_PHASE;
                        else 
                            flashState <= IDLE;
                    end
                end
                ADDR_TX: begin
                    if (addrCycleCount == 3) begin
                        addrCycleCount <= 0;
                        serializerEnable <= 0;
                        mclkEnable_n <= 1;

                        if (cmdHasDmmyPhase) 
                            flashState <= DMMY_WAIT;
                        else if (cmdHasDataPhase)
                            flashState <= DATA_PHASE;
                        else
                            flashState <= IDLE;
                    end else if (WrDataReady) begin
                        {serializerByteBuffer, currentAddr} <= {serializerByteBuffer, currentAddr} << 8;
                        mclkEnable_n <= 0;
                        serializerEnable <= 1;
                        addrCycleCount <= addrCycleCount + 1;
                    end
                end
                DMMY_WAIT: begin
                    if (dmmyCycleCount == numOfDmmyBytes) begin
                        serializerEnable <= 0;
                        dmmyCycleCount <= 0;
                        mclkEnable_n <= 1;
                        if (cmdHasDataPhase)
                            flashState <= DATA_PHASE;
                        else
                            flashState <= IDLE;
                    end else if (WrDataReady) begin
                        //waste MCLK cycles, data sent/received is Don't Care
                        serializerEnable <= 1;
                        mclkEnable_n <= 0;
                        dmmyCycleCount <= dmmyCycleCount + 1;
                    end
                end
                DATA_PHASE: begin
                    mclkEnable_n <= 0;
                    if (isReadCmd) begin
                        deserializerEnable <= 1;
                        fData_RD <= deserializerBuffer;
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
            mclkEnable_n <= 1;
            CS_n <= 1;
        end
    end

    reg[1:0] addrCycleCount;
    reg[2:0] dmmyCycleCount;
    reg[2:0] numOfDmmyBytes;

    reg mclkEnable_n;

    //CPOL=1 idle-high SPI clock
    assign MCLK = serialClk + mclkEnable_n;

    reg serializerEnable;
    reg[7:0] serializerByteBuffer;
    reg[7:0] mosiOut;
    reg[3:0] serializerCycleCount;
    //serialization block
    always@(negedge MCLK) begin
        if (serializerEnable) begin
            if (serializerCycleCount == 8) begin
                //should be held at 1 as long as the serializer is idle?
                serializerCycleCount <= 0;
                WrDataReady <= 1;
            end else begin
                if (serializerCycleCount == 0) begin
                    mosiOut <= serializerByteBuffer;
                end
                //shifting bits out starting with MSB
                {MOSI, mosiOut} <= {MOSI, mosiOut} << 1; 
                serializerCycleCount <= serializerCycleCount + 1;
                WrDataReady <= 0;
            end
        end else begin
            WrDataReady <= 0;
            serializerCycleCount <= 0;
        end
    end

    reg deserializerEnable;

    reg[3:0] deserializerCycleCount;
    reg[7:0] deserializerBuffer;
	//deserialization block
    always@(posedge MCLK) begin
        if (deserializerEnable) begin
            if (deserializerCycleCount == 8) begin
                deserializerCycleCount <= 0;
                RdDataValid <= 1;
            end else begin
                deserializerBuffer <= {deserializerBuffer, MISO} << 1;
                deserializerCycleCount <= deserializerCycleCount + 1;
                RdDataValid <= 0;
            end
        end else begin
            RdDataValid <= 0;
            deserializerCycleCount <= 0;
        end
    end

    reg cmdHasAddrPhase;
    reg cmdHasDmmyPhase;
    reg cmdHasDataPhase;
    reg isReadCmd; //1 for a data read command, 0 for a data write command.
    //combinational block for determining phases required for each command
    always@(currentCmd) begin
        case(currentCmd)
            `FREAD | `READ: begin
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
        addrCycleCount <= 0;
        dmmyCycleCount <= 0;
        numOfDmmyBytes <= 1;
        mclkEnable_n <= 1;
        WrDataReady <= 0;
        RdDataValid <= 0;
        serializerEnable <= 0;
    end
endmodule