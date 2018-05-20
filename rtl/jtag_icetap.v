
`include "jtag_tap_defines.v"

`default_nettype none

module jtag_icetap #(
        parameter NR_SIGNALS = 1
    ) 
    (
        input   wire        clk,
        input   wire        reset_,

`ifdef JTAG_TAP_GENERIC
        input   wire        trst_,
        input   wire        tck,
        input   wire        tms,
        input   wire        tdi,
        output  wire        tdo,
        output  wire        tdo_oe,
`endif

        input   wire [NR_SIGNALS-1:0] signals_in
    );

    wire [`IR_LENGTH-1:0]  ir;

    wire        test_logic_reset, capture_dr, shift_dr, update_dr;

`ifdef JTAG_TAP_ALTERA
    wire        tck;
    wire        tdi;

    jtag_tap_altera #(
        .IR_BITS(`IR_LENGTH)
    ) 
    u_jtag_tap
    (
        .tck(tck),
        .tdi(tdi),
        .tdo(tdo2tap),
        .ir(ir),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr)
    );

`endif

`ifdef JTAG_TAP_GENERIC
    wire icetap_data_ir, icetap_config_ir;

    jtag_tap_generic u_jtag_tap
    (
        .trst_pad_i(!trst_),
        .tck_pad_i(tck),
        .tms_pad_i(tms),
        .tdi_pad_i(tdi),
        .tdo_pad_o(tdo),
        .tdo_padoe_o(tdo_oe),

        .ir_o(ir),

        .tdo_i(tdo2tap),

        .test_logic_reset_o(test_logic_reset),
        .capture_dr_o(capture_dr),
        .shift_dr_o(shift_dr),
        .update_dr_o(update_dr)
    );
`endif

    reg bypass_tdo;
    always @(posedge tck)
    begin
        bypass_tdo <= tdi;
    end

    wire scan_n_ir, extest_ir;
    assign scan_n_ir = (ir == `SCAN_N);
    assign extest_ir = (ir == `EXTEST);

    wire tdo2tap;
    assign tdo2tap = (scan_n_ir | extest_ir) ? icetap_tdo 
                                             : bypass_tdo;

    wire icetap_tdo;

    icetap_top_jtag #(
        .NR_SIGNALS(NR_SIGNALS)
    )
    u_icetap_top_jtag (
        .tck                (tck),
        .tdi                (tdi),
        .icetap_tdo         (icetap_tdo),

        .capture_dr         (capture_dr),
        .shift_dr           (shift_dr),
        .update_dr          (update_dr),

        .scan_n_ir          (scan_n_ir),
        .extest_ir          (extest_ir),

        .src_clk            (clk),
        .src_reset_         (reset_),
        .signals_in         (signals_in),

        .scan_clk           (tck),
        .scan_reset_        (!test_logic_reset)
    );


endmodule

