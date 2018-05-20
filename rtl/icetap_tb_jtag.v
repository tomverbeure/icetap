`default_nettype none
`timescale 1ns/100ps

module icetap_tb();

    reg clk;
    reg reset_;
    reg trst_;

    initial begin
        clk = 1'b0;
    end

    always begin
        #5 clk = !clk;
    end

    initial begin
        $display("%t: Start of simulation!", $time);
        $dumpfile("output/waves.vcd");
        $dumpvars(0);

        reset_  = 0;
        trst_   = 0;
        repeat(10) @(posedge clk);
        reset_  = 1;
        trst_   = 1;

        repeat(10000) @(posedge clk);
        $display("%t: Simulation complete...", $time);
        $finish;
    end

    wire uart_rx;
    wire uart_tx;

    localparam NR_SIGNALS = 8;

    reg [NR_SIGNALS-1:0]    signals_in;

    always @(posedge clk)
    begin
        if (!reset_) begin
            signals_in  <= 0;
        end
        else begin
            signals_in  <= signals_in + 1;
        end
    end

    reg     tck;
    reg     tms;
    reg     tdi;
    wire    tdo;
    wire    tdo_oe;

    jtag_icetap
    #(
     .NR_SIGNALS(NR_SIGNALS) 
    ) 
    u_jtag_icetap
    (
        .tck                (tck),
        .tms                (tms),
        .tdi                (tdi),
        .tdo                (tdo),
        .tdo_oe             (tdo_oe),

        .clk                (clk),
        .reset_             (reset_),

        .signals_in         (signals_in)
    );

`include "jtag_tap_defines.v"

    parameter IR_LENGTH = `IR_LENGTH;
    parameter MAX_TDO_VEC   = 64;

`include "jtag_tb_tasks.v"


    initial begin
        tck     = 0;
        tdi     = 0;
        tms     = 0;

        @(posedge trst_);

        jtag_clocked_reset();

        jtag_reset_to_run_test_idle();

        //============================================================
        // Default IR should be IDCODE. Shift it out...
        //============================================================

        // SELECT_DR_SCAN
        jtag_apply_tms(1);

        // CAPTURE_DR
        jtag_apply_tms(0);

        // SHIFT_DR
        jtag_apply_tms(0);

        // Scan out IDCODE
        jtag_scan_vector(32'h0, 32, 1);

        // EXIT1_DR -> UPDATE_DR
        jtag_apply_tms(1);

        // UPDATE_DR -> RUN_TEST_IDLE
        jtag_apply_tms(0);

        $display("%t: IDCODE scanned out: %x", $time, captured_tdo_vec[31:0]);

        //============================================================
        // Select IR 0xa
        //============================================================
        jtag_scan_ir(4'b1111);
        jtag_scan_ir(4'ha);

        //============================================================
        // Select IDCODE register
        //============================================================
        jtag_scan_ir(`IDCODE);
        jtag_scan_dr(32'd0, 32, 1);

        //============================================================
        // GPIOs
        //============================================================
        // All GPIOs output
        $display("CONFIG - SCAN_N");
        jtag_scan_ir(`SCAN_N);
        jtag_scan_dr(1'b0, 1, 0);
        $display("CONFIG - EXTEST WR");
        jtag_scan_ir(`EXTEST);
        jtag_scan_dr(4'b1111, 4, 0);

        // capture_dr without update_dr (to read back the value)
        $display("CONFIG - EXTEST RD");
        jtag_scan_dr(4'b0000, 4, 0);

        // Set GPIO output values
        $display("DATA - SCAN_N");
        jtag_scan_ir(`SCAN_N);
        jtag_scan_dr(1'b1, 1, 0);
        $display("DATA - EXTEST");
        jtag_scan_ir(`EXTEST);

        jtag_scan_dr(4'b1111, 4, 1);
        jtag_scan_dr(4'b1000, 4, 0);
        jtag_scan_dr(4'b1001, 4, 1);
        jtag_scan_dr(4'b1010, 4, 0);
        jtag_scan_dr(4'b1011, 4, 0);
        jtag_scan_dr(4'b1100, 4, 0);
        jtag_scan_dr(4'b1101, 4, 0);
        jtag_scan_dr(4'b1110, 4, 0);
        jtag_scan_dr(4'b1111, 4, 0);
        jtag_scan_dr(4'b1000, 4, 0);

    end


    reg [MAX_TDO_VEC-1:0]   captured_tdo_vec;
    initial begin: CAPTURE_TDO
        integer                 bit_cntr;

        forever begin
            while(!tdo_oe) begin
                @(posedge tck);
            end
            bit_cntr = 0;
            captured_tdo_vec = {MAX_TDO_VEC{1'bz}};
            while(tdo_oe) begin
                captured_tdo_vec[bit_cntr] = tdo;
                bit_cntr = bit_cntr + 1;
                @(posedge tck);
            end
            $display("%t: TDO_CAPTURED: %b", $time, captured_tdo_vec);
            @(posedge tck);
        end
    end



endmodule

`ifdef BLAH
    reg [7:0] miso_byte;

    initial begin
        spi_ss_     <= 1'b1;
        spi_clk     <= 1'b0;
        spi_mosi    <= 1'b0;
        @(posedge reset_);

        repeat(100) @(posedge clk);

        // STORE MASK
        spi_xfer_start;
        spi_xfer_data(8'h03, miso_byte);
        spi_xfer_data(8'h00, miso_byte);
        spi_xfer_data(8'h00, miso_byte);
        spi_xfer_data(8'h01, miso_byte);
        spi_xfer_end;

        // TRIGGER MASK
        spi_xfer_start;
        spi_xfer_data(8'h04, miso_byte);
        spi_xfer_data(8'h00, miso_byte);
        spi_xfer_data(8'h00, miso_byte);
        spi_xfer_data(8'h48, miso_byte);
        spi_xfer_end;

        // CMD
        spi_xfer_start;
        spi_xfer_data(8'h00, miso_byte);
        // start, !store_always, !trigger_always
        spi_xfer_data(8'h01, miso_byte);
        spi_xfer_end;

        repeat(5) begin
            $display("--- Status");
            spi_xfer_start;
            spi_xfer_data(8'h01, miso_byte);
            spi_xfer_data(8'h00, miso_byte);
            $display("%02x", miso_byte);
            spi_xfer_data(8'h00, miso_byte);
            $display("%02x", miso_byte);
            spi_xfer_data(8'h00, miso_byte);
            $display("%02x", miso_byte);
            spi_xfer_data(8'h00, miso_byte);
            $display("%02x", miso_byte);
            spi_xfer_end;
        end

        $display("--- Data");
        spi_xfer_start;
        spi_xfer_data(8'h02, miso_byte);
        repeat(16) begin
            spi_xfer_data(8'h00, miso_byte);
            $display("%02x", miso_byte);
        end

        repeat(1000) @(posedge clk);
        $finish;
    end
`endif
