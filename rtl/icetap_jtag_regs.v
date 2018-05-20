
`default_nettype none

module icetap_jtag_regs
    #(
        parameter NR_SIGNALS = 1
    )
    (
        input               reset_,

        // In the case come either straight from the IO pins or from the
        // virtual jtag TAP.
        input   wire        tck,
        input   wire        tdi,

        // Output of the GPIO status registers.
        // The real or the virtual JTAG TAP will select this when the GPIO
        // scan chain is selected by the TAP.
        output              icetap_tdo,

        // TAP states
        input               capture_dr,
        input               shift_dr,
        input               update_dr,

        // Current active instruction
        input               scan_n_ir,
        input               extest_ir,

        // Interface with icetap main block
        output reg          cmd_shift_ena,
        output reg          cmd_shift_update,
        output reg          cmd_shift_data,
   
        output reg          status_shift_update,
        output reg          status_shift_ena,
        input               status_shift_data,
    
        output reg          store_mask_shift_ena,
        output reg          store_mask_shift_data,
    
        output reg          trigger_mask_shift_ena,
        output reg          trigger_mask_shift_data,
    
        output reg          data_shift_update,
        output reg          data_shift_ena,
        input               data_shift_data
    );

    // Currently selected register: 0 -> config, 1 -> data
    reg [2:0] scan_n;

    always @(posedge tck) 
    begin
        if (scan_n_ir) begin
            if (shift_dr) begin
                scan_n  <= {tdi, scan_n[2:1]};
            end
        end

        if (!reset_) begin
            scan_n      <= `JTAG_REG_VOID;
        end
    end

    // COMMAND
    always @* begin
        if (extest_ir && scan_n == `JTAG_REG_CMD) begin
            cmd_shift_ena       = shift_dr;
            cmd_shift_update    = update_dr;
            cmd_shift_data      = tdi;
        end
        else begin
            cmd_shift_ena       = 1'b0;
            cmd_shift_update    = 1'b0;
            cmd_shift_data      = 1'b0;
        end
    end

    // STATUS
    always @* begin
        if (extest_ir && scan_n == `JTAG_REG_STATUS) begin
            status_shift_update  = capture_dr;
            status_shift_ena     = shift_dr;
        end
        else begin
            status_shift_ena     = 1'b0;
            status_shift_update  = 1'b0;
        end
    end

    // STORE_MASK
    always @* begin
        if (extest_ir && scan_n == `JTAG_REG_STORE_MASK) begin
            store_mask_shift_ena     = shift_dr;
            store_mask_shift_data    = tdi;
        end
        else begin
            store_mask_shift_ena     = 1'b0;
            store_mask_shift_data    = 1'b0;
        end
    end

    // TRIGGER_MASK
    always @* begin
        if (extest_ir && scan_n == `JTAG_REG_TRIGGER_MASK) begin
            trigger_mask_shift_ena     = shift_dr;
            trigger_mask_shift_data    = tdi;
        end
        else begin
            trigger_mask_shift_ena     = 1'b0;
            trigger_mask_shift_data    = 1'b0;
        end
    end

    // DATA
    always @* begin
        if (extest_ir && scan_n == `JTAG_REG_DATA) begin
            data_shift_ena     = shift_dr;
            data_shift_update  = update_dr;
        end
        else begin
            data_shift_ena     = 1'b0;
            data_shift_update  = 1'b0;
        end
    end

    assign icetap_tdo = scan_n_ir                   ? scan_n                :
                        scan_n == `JTAG_REG_STATUS  ? status_shift_data     :
                        scan_n == `JTAG_REG_DATA    ? data_shift_data       :
                                                      0;

endmodule
