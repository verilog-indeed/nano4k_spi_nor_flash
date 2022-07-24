module gw_gao(
    fMclk,
    fChipSel,
    fMiso,
    fMosi,
    \dut/fData_RD[7] ,
    \dut/fData_RD[6] ,
    \dut/fData_RD[5] ,
    \dut/fData_RD[4] ,
    \dut/fData_RD[3] ,
    \dut/fData_RD[2] ,
    \dut/fData_RD[1] ,
    \dut/fData_RD[0] ,
    \dut/fData_WR[7] ,
    \dut/fData_WR[6] ,
    \dut/fData_WR[5] ,
    \dut/fData_WR[4] ,
    \dut/fData_WR[3] ,
    \dut/fData_WR[2] ,
    \dut/fData_WR[1] ,
    \dut/fData_WR[0] ,
    \dut/flashState[3] ,
    \dut/flashState[2] ,
    \dut/flashState[1] ,
    \dut/flashState[0] ,
    \testStateCounter[21] ,
    \testStateCounter[20] ,
    \testStateCounter[19] ,
    \testStateCounter[18] ,
    \testStateCounter[17] ,
    \testStateCounter[16] ,
    \testStateCounter[15] ,
    \testStateCounter[14] ,
    \testStateCounter[13] ,
    \testStateCounter[12] ,
    \testStateCounter[11] ,
    \testStateCounter[10] ,
    \testStateCounter[9] ,
    \testStateCounter[8] ,
    \testStateCounter[7] ,
    \testStateCounter[6] ,
    \testStateCounter[5] ,
    \testStateCounter[4] ,
    \testStateCounter[3] ,
    \testStateCounter[2] ,
    \testStateCounter[1] ,
    \testStateCounter[0] ,
    \dut/RdDataValid ,
    \dut/WrDataReady ,
    crystalClk,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input fMclk;
input fChipSel;
input fMiso;
input fMosi;
input \dut/fData_RD[7] ;
input \dut/fData_RD[6] ;
input \dut/fData_RD[5] ;
input \dut/fData_RD[4] ;
input \dut/fData_RD[3] ;
input \dut/fData_RD[2] ;
input \dut/fData_RD[1] ;
input \dut/fData_RD[0] ;
input \dut/fData_WR[7] ;
input \dut/fData_WR[6] ;
input \dut/fData_WR[5] ;
input \dut/fData_WR[4] ;
input \dut/fData_WR[3] ;
input \dut/fData_WR[2] ;
input \dut/fData_WR[1] ;
input \dut/fData_WR[0] ;
input \dut/flashState[3] ;
input \dut/flashState[2] ;
input \dut/flashState[1] ;
input \dut/flashState[0] ;
input \testStateCounter[21] ;
input \testStateCounter[20] ;
input \testStateCounter[19] ;
input \testStateCounter[18] ;
input \testStateCounter[17] ;
input \testStateCounter[16] ;
input \testStateCounter[15] ;
input \testStateCounter[14] ;
input \testStateCounter[13] ;
input \testStateCounter[12] ;
input \testStateCounter[11] ;
input \testStateCounter[10] ;
input \testStateCounter[9] ;
input \testStateCounter[8] ;
input \testStateCounter[7] ;
input \testStateCounter[6] ;
input \testStateCounter[5] ;
input \testStateCounter[4] ;
input \testStateCounter[3] ;
input \testStateCounter[2] ;
input \testStateCounter[1] ;
input \testStateCounter[0] ;
input \dut/RdDataValid ;
input \dut/WrDataReady ;
input crystalClk;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire fMclk;
wire fChipSel;
wire fMiso;
wire fMosi;
wire \dut/fData_RD[7] ;
wire \dut/fData_RD[6] ;
wire \dut/fData_RD[5] ;
wire \dut/fData_RD[4] ;
wire \dut/fData_RD[3] ;
wire \dut/fData_RD[2] ;
wire \dut/fData_RD[1] ;
wire \dut/fData_RD[0] ;
wire \dut/fData_WR[7] ;
wire \dut/fData_WR[6] ;
wire \dut/fData_WR[5] ;
wire \dut/fData_WR[4] ;
wire \dut/fData_WR[3] ;
wire \dut/fData_WR[2] ;
wire \dut/fData_WR[1] ;
wire \dut/fData_WR[0] ;
wire \dut/flashState[3] ;
wire \dut/flashState[2] ;
wire \dut/flashState[1] ;
wire \dut/flashState[0] ;
wire \testStateCounter[21] ;
wire \testStateCounter[20] ;
wire \testStateCounter[19] ;
wire \testStateCounter[18] ;
wire \testStateCounter[17] ;
wire \testStateCounter[16] ;
wire \testStateCounter[15] ;
wire \testStateCounter[14] ;
wire \testStateCounter[13] ;
wire \testStateCounter[12] ;
wire \testStateCounter[11] ;
wire \testStateCounter[10] ;
wire \testStateCounter[9] ;
wire \testStateCounter[8] ;
wire \testStateCounter[7] ;
wire \testStateCounter[6] ;
wire \testStateCounter[5] ;
wire \testStateCounter[4] ;
wire \testStateCounter[3] ;
wire \testStateCounter[2] ;
wire \testStateCounter[1] ;
wire \testStateCounter[0] ;
wire \dut/RdDataValid ;
wire \dut/WrDataReady ;
wire crystalClk;
wire tms_pad_i;
wire tck_pad_i;
wire tdi_pad_i;
wire tdo_pad_o;
wire tms_i_c;
wire tck_i_c;
wire tdi_i_c;
wire tdo_o_c;
wire [9:0] control0;
wire gao_jtag_tck;
wire gao_jtag_reset;
wire run_test_idle_er1;
wire run_test_idle_er2;
wire shift_dr_capture_dr;
wire update_dr;
wire pause_dr;
wire enable_er1;
wire enable_er2;
wire gao_jtag_tdi;
wire tdo_er1;

IBUF tms_ibuf (
    .I(tms_pad_i),
    .O(tms_i_c)
);

IBUF tck_ibuf (
    .I(tck_pad_i),
    .O(tck_i_c)
);

IBUF tdi_ibuf (
    .I(tdi_pad_i),
    .O(tdi_i_c)
);

OBUF tdo_obuf (
    .I(tdo_o_c),
    .O(tdo_pad_o)
);

GW_JTAG  u_gw_jtag(
    .tms_pad_i(tms_i_c),
    .tck_pad_i(tck_i_c),
    .tdi_pad_i(tdi_i_c),
    .tdo_pad_o(tdo_o_c),
    .tck_o(gao_jtag_tck),
    .test_logic_reset_o(gao_jtag_reset),
    .run_test_idle_er1_o(run_test_idle_er1),
    .run_test_idle_er2_o(run_test_idle_er2),
    .shift_dr_capture_dr_o(shift_dr_capture_dr),
    .update_dr_o(update_dr),
    .pause_dr_o(pause_dr),
    .enable_er1_o(enable_er1),
    .enable_er2_o(enable_er2),
    .tdi_o(gao_jtag_tdi),
    .tdo_er1_i(tdo_er1),
    .tdo_er2_i(1'b0)
);

gw_con_top  u_icon_top(
    .tck_i(gao_jtag_tck),
    .tdi_i(gao_jtag_tdi),
    .tdo_o(tdo_er1),
    .rst_i(gao_jtag_reset),
    .control0(control0[9:0]),
    .enable_i(enable_er1),
    .shift_dr_capture_dr_i(shift_dr_capture_dr),
    .update_dr_i(update_dr)
);

ao_top_0  u_la0_top(
    .control(control0[9:0]),
    .trig0_i({\testStateCounter[21] ,\testStateCounter[20] ,\testStateCounter[19] ,\testStateCounter[18] ,\testStateCounter[17] ,\testStateCounter[16] ,\testStateCounter[15] ,\testStateCounter[14] ,\testStateCounter[13] ,\testStateCounter[12] ,\testStateCounter[11] ,\testStateCounter[10] ,\testStateCounter[9] ,\testStateCounter[8] ,\testStateCounter[7] ,\testStateCounter[6] ,\testStateCounter[5] ,\testStateCounter[4] ,\testStateCounter[3] ,\testStateCounter[2] ,\testStateCounter[1] ,\testStateCounter[0] }),
    .data_i({fMclk,fChipSel,fMiso,fMosi,\dut/fData_RD[7] ,\dut/fData_RD[6] ,\dut/fData_RD[5] ,\dut/fData_RD[4] ,\dut/fData_RD[3] ,\dut/fData_RD[2] ,\dut/fData_RD[1] ,\dut/fData_RD[0] ,\dut/fData_WR[7] ,\dut/fData_WR[6] ,\dut/fData_WR[5] ,\dut/fData_WR[4] ,\dut/fData_WR[3] ,\dut/fData_WR[2] ,\dut/fData_WR[1] ,\dut/fData_WR[0] ,\dut/flashState[3] ,\dut/flashState[2] ,\dut/flashState[1] ,\dut/flashState[0] ,\testStateCounter[21] ,\testStateCounter[20] ,\testStateCounter[19] ,\testStateCounter[18] ,\testStateCounter[17] ,\testStateCounter[16] ,\testStateCounter[15] ,\testStateCounter[14] ,\testStateCounter[13] ,\testStateCounter[12] ,\testStateCounter[11] ,\testStateCounter[10] ,\testStateCounter[9] ,\testStateCounter[8] ,\testStateCounter[7] ,\testStateCounter[6] ,\testStateCounter[5] ,\testStateCounter[4] ,\testStateCounter[3] ,\testStateCounter[2] ,\testStateCounter[1] ,\testStateCounter[0] ,\dut/RdDataValid ,\dut/WrDataReady }),
    .clk_i(crystalClk)
);

endmodule
