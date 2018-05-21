`default_nettype none
`timescale 1ns/100ps

module icetap_tb();

    reg clk;
    reg reset_;

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
        repeat(10) @(posedge clk);
        reset_  = 1;

        repeat(10000) @(posedge clk);
        $display("%t: Simulation complete...", $time);
        $finish;
    end

    wire uart_rx;
    wire uart_tx;

    localparam NR_SIGNALS   = 16;
    localparam RECORD_DEPTH = 512;

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

    reg     trst_;
    reg     tck;
    reg     tms;
    reg     tdi;
    wire    tdo;
    wire    tdo_oe;

    jtag_icetap
    #(
        .NR_SIGNALS(NR_SIGNALS),
        .RECORD_DEPTH(RECORD_DEPTH)
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

    task jtag_fetch_idcode;
        begin
            //============================================================
            // Select IDCODE register
            //============================================================
            jtag_scan_ir(`IDCODE);
            jtag_scan_dr(32'd0, 32, 1);
        end
    endtask

    task jtag_set_scan_n;
        input  [`JTAG_SCAN_N_LENGTH-1:0] register;
        begin
            jtag_scan_ir(`SCAN_N);
            jtag_scan_dr(register, `JTAG_SCAN_N_LENGTH, 1);
        end
    endtask

    reg [NR_SIGNALS*3-1:0] trigger_mask;
    reg [NR_SIGNALS-1:0]   trigger_value;

    reg                             status_state_idle;
    reg [1:0]                       status_state;
    reg [$clog2(RECORD_DEPTH)-1:0]  status_stop_addr;
    reg [$clog2(RECORD_DEPTH)-1:0]  status_trigger_addr;
    reg [$clog2(RECORD_DEPTH)-1:0]  status_start_addr;

    integer i;

    initial begin
        tck     = 0;
        tdi     = 0;
        tms     = 0;
        trst_   = 0;

        @(posedge reset_);

        trst_   = 1;
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

        jtag_scan_ir(`BYPASS);

        //============================================================
        // Fetch IDCODE
        //============================================================
        jtag_fetch_idcode;

        //============================================================
        // STORE_MASK
        //============================================================
        $display("store-mask");
        jtag_set_scan_n(`JTAG_REG_STORE_MASK);
        jtag_scan_ir(`EXTEST);
        jtag_scan_dr('h01, NR_SIGNALS * 3, 0);

        //============================================================
        // TRIGGER_MASK
        //============================================================
        $display("trigger-mask");
        jtag_set_scan_n(`JTAG_REG_TRIGGER_MASK);
        jtag_scan_ir(`EXTEST);

        trigger_value = 'h1c00;
        trigger_mask = 0;
        for(i=0;i<NR_SIGNALS;++i) begin
            trigger_mask = trigger_mask | (trigger_value[i] ? 3'd1 : 3'd2) << (i*3);
        end
        jtag_scan_dr(trigger_mask, NR_SIGNALS * 3, 0);

        //============================================================
        // Start!
        //============================================================
        $display("command");
        jtag_set_scan_n(`JTAG_REG_CMD);
        jtag_scan_ir(`EXTEST);
        jtag_scan_dr(3'h1, 3, 1);
        jtag_spin_run_test_idle(10);    // Spin cycles to make sure command gets through synchronizer

        //============================================================
        // Wait until idle
        //============================================================
        $display("status polling");
        jtag_set_scan_n(`JTAG_REG_STATUS);
        jtag_scan_ir(`EXTEST);

        status_state_idle = 0;
        while (status_state_idle != 1) begin
            jtag_scan_dr(64'h0, 64, 1);
            { status_start_addr, status_trigger_addr, status_stop_addr, status_state, status_state_idle } = captured_tdo_vec;
            $display("Status: %d", status_state);
            $display("start_addr  : %08x", status_start_addr);
            $display("trigger_addr: %08x", status_trigger_addr);
            $display("stop_addr   : %08x", status_stop_addr);
        end 


        repeat(10000) @(posedge clk);
        $finish;

    end


    reg [MAX_TDO_VEC-1:0]   captured_tdo_vec;
    initial begin: CAPTURE_TDO
        integer bit_cntr;

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

