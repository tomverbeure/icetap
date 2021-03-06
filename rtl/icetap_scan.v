
`default_nettype none

// This module converts the parallel control, data and status signals to a scan-based interface, which can be used
// by SPI, JTAG etc.
module icetap_scan 
    #(
        parameter NR_SIGNALS            = 16,
        parameter RECORD_DEPTH          = 256,
        parameter COMPLEX_STORE         = 1,
        parameter COMPLEX_TRIGGER       = 1
    ) (
        // Scan interface
        input               scan_clk,
        input               scan_reset_,
        
        input               cmd_shift_ena,
        input               cmd_shift_update,
        input               cmd_shift_data,

        input               status_shift_update,
        input               status_shift_ena,
        output              status_shift_data,

        input               store_mask_shift_ena,
        input               store_mask_shift_data,

        input               trigger_mask_shift_ena,
        input               trigger_mask_shift_data,

        input               data_shift_update,
        input               data_shift_ena,
        output              data_shift_data,

        // Trigger settings
        output reg [NR_SIGNALS*3-1:0]   store_mask_vec,
        output reg [NR_SIGNALS*3-1:0]   trigger_mask_vec,

        input                       src_clk,
        input                       src_reset_,

        // Recording configuration
        output                      start,
        output                      store_always,
        output                      trigger_always,

        // Status
        input [1:0]                 state,
        input [RAM_ADDR_BITS-1:0]   start_addr, 
        input [RAM_ADDR_BITS-1:0]   trigger_addr, 
        input [RAM_ADDR_BITS-1:0]   stop_addr,

        output                      read_req_first,
        output reg                  read_req_next,
        input [NR_SIGNALS-1:0]      read_data

    );

    localparam RAM_ADDR_BITS = $clog2(RECORD_DEPTH);

    //============================================================
    // STORE_MASK
    //============================================================
    generate if (COMPLEX_STORE == 1) begin
        always @(posedge scan_clk) begin
            if (store_mask_shift_ena) begin
                store_mask_vec <= { store_mask_shift_data, store_mask_vec[NR_SIGNALS*3-1:1] };
                end
        end
    end
    else begin
        always @(*) begin
            store_mask_vec  <= {(NR_SIGNALS*3){1'b0}};
        end
    end
    endgenerate

    //============================================================
    // TRIGGER_MASK
    //============================================================
    generate if (COMPLEX_TRIGGER == 1) begin
        always @(posedge scan_clk) begin
            if (trigger_mask_shift_ena) begin
                trigger_mask_vec <= { trigger_mask_shift_data, trigger_mask_vec[NR_SIGNALS*3-1:1] };
            end
        end
    end
    else begin
        always @(*) begin
            trigger_mask_vec <= {(NR_SIGNALS*3){1'b0}};
        end
    end
    endgenerate

    //============================================================
    // CMD
    //============================================================
    reg [2:0] cmd_reg;

    always @(posedge scan_clk) begin
        if (cmd_shift_ena) begin
            cmd_reg <= { cmd_shift_data, cmd_reg[2:1] };
        end

        if (!scan_reset_) begin
            cmd_reg <= 0;
        end
    end

    //============================================================
    // STATUS
    //============================================================
    wire [63:0] status_vec;
    assign status_vec = { start_addr, trigger_addr, stop_addr, state, state_idle_sync };

    reg [7:0] status_scan_reg;      // Capture in chunks of 8 bits to reduce the amount of FFs.
    reg [5:0] status_bit_cntr;

    always @(posedge scan_clk) begin
        if (status_shift_update) begin
            status_scan_reg <= status_vec[7:0];
            status_bit_cntr <= 1;
        end
        else if (status_shift_ena) begin
            status_bit_cntr     <= status_bit_cntr + 1'b1;
            if (status_bit_cntr[2:0] != 0) begin
                status_scan_reg <= { 1'b0, status_scan_reg[7:1] };
            end
            else begin
                status_scan_reg <= (status_bit_cntr[5:3] == 1) ? status_vec[15:8]  : 
                                   (status_bit_cntr[5:3] == 2) ? status_vec[23:16] : 
                                   (status_bit_cntr[5:3] == 3) ? status_vec[31:24] : 
                                   (status_bit_cntr[5:3] == 4) ? status_vec[39:32] : 
                                   (status_bit_cntr[5:3] == 5) ? status_vec[47:40] : 
                                   (status_bit_cntr[5:3] == 6) ? status_vec[55:48] : 
                                   (status_bit_cntr[5:3] == 7) ? status_vec[63:56] : 
                                                                 8'd0;
            end
        end

        if (!scan_reset_) begin
            status_scan_reg <= 0;
            status_bit_cntr <= 1;
        end
    end

    assign status_shift_data = status_scan_reg[0];

    //============================================================
    // DATA
    //============================================================

    wire [NR_SIGNALS-1:0] data_vec;
    assign data_vec = read_data;

    reg [$clog2(NR_SIGNALS)-1:0] data_bit_cntr, data_bit_cntr_nxt;

    assign read_req_first = data_shift_update;

    always @(*) begin
        read_req_next     = 1'b0;
        data_bit_cntr_nxt = data_bit_cntr;

        if (data_shift_update) begin
            data_bit_cntr_nxt  = 0;
        end
        else if (data_shift_ena) begin
            if (data_bit_cntr != NR_SIGNALS-1) begin
                data_bit_cntr_nxt  = data_bit_cntr + 1'b1;
            end
            else begin
                data_bit_cntr_nxt  = 0;
                read_req_next  = 1'b1;
            end
        end
    end

    always @(posedge scan_clk) begin
        data_bit_cntr       <= data_bit_cntr_nxt;
    end

    assign data_shift_data = data_vec[data_bit_cntr];
    
    // SRC_CLK clock domain

    wire cmd_update_sync;
    sync_pulse u_sync_pulse_cmd_shift_update
        (
            .src_clk    (scan_clk),
            .src_reset_ (scan_reset_),
            .pulse_in   (cmd_shift_update),
            .dst_clk    (src_clk),
            .dst_reset_ (src_reset_),
            .pulse_out  (cmd_update_sync)
        );

    reg [2:0]   cmd_reg_sync;
    reg         cmd_update_sync_d;
    reg         cmd_reg_sync_0_d;

    always @(posedge src_clk) begin
        if (cmd_update_sync && !cmd_update_sync_d) begin
            cmd_reg_sync    <= cmd_reg;
        end

        if (!src_reset_) begin
            cmd_reg_sync    <= 3'd0;
        end

        cmd_update_sync_d <= cmd_update_sync;
        cmd_reg_sync_0_d  <= cmd_reg_sync[0];

    end

    assign start          = cmd_reg_sync[0] && !cmd_reg_sync_0_d;
    assign store_always   = cmd_reg_sync[1];
    assign trigger_always = cmd_reg_sync[2];

    reg state_idle;
    always @(posedge src_clk) begin
        state_idle  <= (state == 0);
    end

    wire state_idle_sync;
    sync_dd_c u_sync_state_idle( .clk(scan_clk), .reset_(scan_reset_), .sync_in(state_idle), .sync_out(state_idle_sync));

endmodule

