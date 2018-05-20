
    task jtag_clocked_reset;
        begin
            $display("%t: JTAG Clocked Reset", $time);
            tms = 1;
            repeat(5) @(negedge tck);
        end
    endtask

    task jtag_apply_tms;
        input tms_in;
        begin
            //$display("Apply TMS %d", tms_in);
            tms = tms_in;
            @(negedge tck);
        end
    endtask

    task jtag_reset_to_run_test_idle;
        begin
            $display("%t: Reset to Run-Test-Idle", $time);

            // Go to RTI
            tms = 0;
            @(negedge tck);
        end
    endtask

    task jtag_scan_vector;

        input [255:0]   vector_in;
        input integer   nr_bits;
        input           exit1;

        integer i;
        begin
            for(i=0; i<nr_bits; i=i+1) begin
                tdi = vector_in[i];

                if (i == nr_bits-1) begin
                    tms = exit1;            // Go to Exit1-*
                end
                @(negedge tck);
            end
        end
    endtask

    task jtag_scan_ir;
        input [IR_LENGTH-1:0] wanted_ir;

        integer i;
        begin
            $display("%t: Set IR 0x%02x", $time, wanted_ir);

            // Go to Select-DR-Scan
            jtag_apply_tms(1);

            // Go to Select-IR-Scan
            jtag_apply_tms(1);

            // Go to Capture-IR
            jtag_apply_tms(0);

            // Go to Shift-IR
            jtag_apply_tms(0);
            tdo_en = 1;

            // Shift vector, then go to EXIT1_IR
            jtag_scan_vector(wanted_ir, IR_LENGTH, 1);

            // Go to Update-IR
            tdo_en = 0;

            jtag_apply_tms(1);

            // Go to Run Test Idle
            jtag_apply_tms(0);
        end
    endtask

    task jtag_scan_dr;
        input [255:0]   vector_in;
        input integer   nr_bits;
        input           early_out;

        integer i;
        begin
            $display("%t: Set DR to 0x%x", $time, vector_in);

            // Go to Select-DR-Scan
            jtag_apply_tms(1);

            // CAPTURE_DR
            jtag_apply_tms(0);
    
            // SHIFT_DR
            jtag_apply_tms(0);
            tdo_en = 1;
    
            // Shift vector, then go to EXIT1_DR
            jtag_scan_vector(vector_in, nr_bits, 1);

            tdo_en = 0;

            if (early_out) begin
                // EXIT1_DR -> UPDATE_DR
                jtag_apply_tms(1);
            end
            else begin
                // EXIT1_DR -> PAUSE_DR
                jtag_apply_tms(0);

                // PAUSE_DR -> EXIT2_DR
                jtag_apply_tms(1);

                // EXIT2_DR -> UPDATE_DR
                jtag_apply_tms(1);
            end
    
            // UPDATE_DR -> RUN_TEST_IDLE
            jtag_apply_tms(0);
        end
    endtask

