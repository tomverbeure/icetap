
// External interfaces:
// config registers:
//      - store_mask[NR_SIGNALS * 2 or 3]: depends on store modes supported
//      - trigger_mask[NR_SIGNALS * 2 or 3]: depends on trigger modes supported
//      - trigger pre/post/middle[2]
// command registers:
//      - start 
//      - stop
//      - scanout ?
// read data:
//      - start address
//      - trigger_address
//      - stop address
//      - all data in one big blob

`default_nettype none

module icetap_top_jtag #(
        parameter NR_SIGNALS            = 16,
        parameter RECORD_DEPTH          = 256,
        parameter COMPLEX_STORE         = 1,
        parameter COMPLEX_TRIGGER       = 1
    ) (
        input                   reset_,
        input                   tck,
        input                   tdi,
        output                  icetap_tdo,

        input                   capture_dr,
        input                   shift_dr,
        input                   update_dr,

        input                   scan_n_ir,
        input                   extest_ir,
                                                
        input                   scan_clk,
        input                   scan_reset_,
        
        input                   src_clk,
        input                   src_reset_,

        input [NR_SIGNALS-1:0]  signals_in
    );

        localparam RAM_ADDR_BITS = $clog2(RECORD_DEPTH);

        wire            cmd_shift_ena;
        wire            cmd_shift_update;
        wire            cmd_shift_data;

        wire            status_shift_ena;
        wire            status_shift_update;
        wire            status_shift_data;

        wire            data_shift_update;
        wire            data_shift_ena;
        wire            data_shift_data;

        wire            store_mask_shift_ena;
        wire            store_mask_shift_data;

        wire            trigger_mask_shift_ena;
        wire            trigger_mask_shift_data;

        // Convert SPI into generic scan interface
        icetap_jtag_regs u_icetap_jtag_regs (
            .reset_                         (reset_),
            .tck                            (tck),
            .tdi                            (tdi),
            .icetap_tdo                     (icetap_tdo),

            .capture_dr                     (capture_dr),
            .shift_dr                       (shift_dr),
            .update_dr                      (update_dr),
                                                
            .cmd_shift_ena                  (cmd_shift_ena),
            .cmd_shift_update               (cmd_shift_update),
            .cmd_shift_data                 (cmd_shift_data),

            .status_shift_update            (status_shift_update),
            .status_shift_ena               (status_shift_ena),
            .status_shift_data              (status_shift_data),

            .store_mask_shift_ena           (store_mask_shift_ena),
            .store_mask_shift_data          (store_mask_shift_data),

            .trigger_mask_shift_ena         (trigger_mask_shift_ena),
            .trigger_mask_shift_data        (trigger_mask_shift_data),

            .data_shift_update              (data_shift_update),
            .data_shift_ena                 (data_shift_ena),
            .data_shift_data                (data_shift_data)
         );
   
        wire [NR_SIGNALS*3-1:0]     store_mask_vec;
        wire [NR_SIGNALS*3-1:0]     trigger_mask_vec;
        
        wire                        store_always;
        wire                        trigger_always;

        wire                        start;
        wire [1:0]                  state;

        wire [RAM_ADDR_BITS-1:0]    start_addr;
        wire [RAM_ADDR_BITS-1:0]    trigger_addr;
        wire [RAM_ADDR_BITS-1:0]    stop_addr;

        wire                        read_req_first;
        wire                        read_req_next;
        wire [NR_SIGNALS-1:0]       read_data;

        // Convert scan chains into parallel signals to control the actual icetap
        icetap_scan 
        #(
          .NR_SIGNALS                           (NR_SIGNALS),
          .COMPLEX_STORE                        (COMPLEX_STORE),
          .COMPLEX_TRIGGER                      (COMPLEX_TRIGGER)
          )
        u_scan
        (
            // Scan Interface
            .scan_clk                               (scan_clk),
            .scan_reset_                            (scan_reset_),

            .cmd_shift_ena                          (cmd_shift_ena),
            .cmd_shift_update                       (cmd_shift_update),
            .cmd_shift_data                         (cmd_shift_data),

            .status_shift_update                    (status_shift_update),
            .status_shift_ena                       (status_shift_ena),
            .status_shift_data                      (status_shift_data),

            .store_mask_shift_ena                   (store_mask_shift_ena),
            .store_mask_shift_data                  (store_mask_shift_data),

            .trigger_mask_shift_ena                 (trigger_mask_shift_ena),
            .trigger_mask_shift_data                (trigger_mask_shift_data),

            .data_shift_update                      (data_shift_update),
            .data_shift_ena                         (data_shift_ena),
            .data_shift_data                        (data_shift_data),

            .src_clk                                (src_clk),
            .src_reset_                             (src_reset_),

            // Configuration
            .store_mask_vec                         (store_mask_vec),
            .trigger_mask_vec                       (trigger_mask_vec),
            .store_always                           (store_always),
            .trigger_always                         (trigger_always),

            // Command
            .start                                  (start),

            // Status
            .state                                  (state),
            .start_addr                             (start_addr),
            .trigger_addr                           (trigger_addr),
            .stop_addr                              (stop_addr),

            // Recorded Data
            .read_req_first                         (read_req_first),
            .read_req_next                          (read_req_next),
            .read_data                              (read_data)
        );

        icetap_bram 
        #(
            // Parameters
            .NR_SIGNALS                             (NR_SIGNALS),
            .RECORD_DEPTH                           (RECORD_DEPTH)
          )
        u_icetap_bram
        (
            .src_clk                                (src_clk),
            .src_reset_                             (src_reset_),

            .store_mask_vec                         (store_mask_vec),
            .trigger_mask_vec                       (trigger_mask_vec),
            .store_always                           (store_always),
            .trigger_always                         (trigger_always),

            .start                                  (start),

            .state                                  (state),
            .start_addr                             (start_addr),
            .trigger_addr                           (trigger_addr),
            .stop_addr                              (stop_addr),

            .signals_in                             (signals_in),

            .read_req_first                         (read_req_first),
            .read_req_next                          (read_req_next),
            .read_data                              (read_data)
         );
        
endmodule

// Local Variables:
// verilog-library-flags:("-f icetap.vc")
// End:

