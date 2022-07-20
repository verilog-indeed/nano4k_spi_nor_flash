`include "nano4k_spi_nor_flash.vo"
`include "prim_sim.v"

module nano4k_spi_flash_top_tb;
    reg xtal_clk;
    wire[2:0] lightsOut;
    wire indicator;
    wire CS;
    wire mosi;
    wire mclk;

    always #10 xtal_clk <= ~xtal_clk;


    nano4k_spi_flash_top uut(
        .crystalClk(xtal_clk),
        .reset(1'b1),
        .fMiso(1'bZ),
        .ledOut(lightsOut),
        .readStrobeIndicator(indicator),
        .fChipSel(CS),
        .fMosi(mosi),
        .fMclk(mclk)
    );

    initial begin
        $dumpfile("top_sim_result.vcd");
        $dumpvars(0, nano4k_spi_flash_top_tb);
        $dumpon;

        #10 xtal_clk <= 1;
        #50000 $finish;
    end
endmodule