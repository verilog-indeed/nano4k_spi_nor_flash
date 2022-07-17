`include "nano4k_spi_flash.v"
`timescale 1 ns/10 ps // time-unit = 1 ns, precision = 10 ps

module nano4k_spi_flash_tb;
    reg i_clock;
    reg s_clock;
    reg i_enable_n;
    reg[7:0] cmd;
    reg[21:0] addr;
    reg[7:0] wr_data;
    wire[7:0] rd_data;
    wire readStrobe;
    wire writeStrobe;

    reg spiMiso;
    wire spiMosi;
    wire spiClk;
    wire chipSelect;

    always #80 i_clock <= ~i_clock;
    always #10 s_clock <= ~s_clock; //8 x i_clock

    nano4k_spi_flash dut(
        .interfaceClk(i_clock),
        .serialClk(s_clock),
        .interfaceEnable_n(i_enable_n),
        .fCommand(cmd),
        .fAddress(addr),
        .fData_WR(wr_data),
        .fData_RD(rd_data),
        .RdDataValid(readStrobe),
        .WrDataReady(writeStrobe),

        .MISO(spiMiso),
        .MOSI(spiMosi),
        .MCLK(spiClk),
        .CS_n(chipSelect)
    );

    initial begin
        $dumpfile("sim_result.vcd");
        $dumpvars(0, nano4k_spi_flash_tb);
        $dumpon;

        #0 i_clock = 1;
        #0 s_clock = 1;
        #0 i_enable_n = 1;
        #0 cmd = `RSTEN;
        #0 spiMiso = 0;
        #300 i_enable_n = 0;
        #1500 i_enable_n = 1;
        #1500 cmd = `FREAD;
        #1500 addr = 22'h3A5;
        #1740 i_enable_n = 0;
        #1650 spiMiso = 1;
        #15 spiMiso = 0;
        #10 spiMiso = 1;
        #20 spiMiso = 0;
        #100 spiMiso = 1;
        #2990 i_enable_n = 1;
        #5400 $finish;
    end
endmodule