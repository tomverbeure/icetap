
`default_nettype none

module icetap_bram
    #(
        parameter NR_SIGNALS        = 16,
        parameter RECORD_DEPTH      = 256
    ) (
        input                       src_clk,
        input                       src_reset_,
        input [NR_SIGNALS-1:0]      signals_in,

        input                       start,
        input                       store_always,
        input                       trigger_always,

        input [3*NR_SIGNALS-1:0]    store_mask_vec,
        input [3*NR_SIGNALS-1:0]    trigger_mask_vec,

        output     [1:0]                state,
        output reg [RAM_ADDR_BITS-1:0]  start_addr,
        output reg [RAM_ADDR_BITS-1:0]  trigger_addr,
        output reg [RAM_ADDR_BITS-1:0]  stop_addr,

        input                       scan_clk,
        input                       scan_reset_,

        input                       read_req_first,
        input                       read_req_next,
        output [NR_SIGNALS-1:0]     read_data
    );

    localparam RAM_ADDR_BITS = $clog2(RECORD_DEPTH);

    reg [NR_SIGNALS-1:0]    signals_in_p1, signals_in_p2;

    always @(posedge src_clk) begin
        signals_in_p1   <= signals_in;
        signals_in_p2   <= signals_in_p1;
    end

    localparam TRIGGER_DONT_CARE = 3'd0;
    localparam TRIGGER_HIGH      = 3'd1;
    localparam TRIGGER_LOW       = 3'd2;
    localparam TRIGGER_RISING    = 3'd3;
    localparam TRIGGER_FALLING   = 3'd4;

    //============================================================
    // STORE TRIGGER
    //============================================================
    wire [NR_SIGNALS-1:0] store_trigger_vec;

    genvar i;
    generate for(i=0; i<NR_SIGNALS; i=i+1) begin : store_mask_loop
        assign store_trigger_vec[i] = store_mask_vec[3*i+2:3*i] == TRIGGER_HIGH    ?  signals_in_p1[i]                       :
                                      store_mask_vec[3*i+2:3*i] == TRIGGER_LOW     ? !signals_in_p1[i]                       :
                                      store_mask_vec[3*i+2:3*i] == TRIGGER_RISING  ?  signals_in_p1[i] && !signals_in_p2[i] :
                                      store_mask_vec[3*i+2:3*i] == TRIGGER_FALLING ? !signals_in_p1[i] &&  signals_in_p2[i] :
                                                                                   1'b0;

    end
    endgenerate

    wire store_trigger;
    assign store_trigger = |store_trigger_vec || store_always;

    //============================================================
    // CAPTURE TRIGGER
    //============================================================
    wire [NR_SIGNALS-1:0]   trigger_vec;

    generate for(i=0; i<NR_SIGNALS; i=i+1) begin :trigger_mask_loop
        assign trigger_vec[i] = trigger_mask_vec[3*i+2:3*i] == TRIGGER_HIGH    ?  signals_in_p1[i]                       :
                                trigger_mask_vec[3*i+2:3*i] == TRIGGER_LOW     ? !signals_in_p1[i]                       :
                                trigger_mask_vec[3*i+2:3*i] == TRIGGER_RISING  ?  signals_in_p1[i] && !signals_in_p2[i] :
                                trigger_mask_vec[3*i+2:3*i] == TRIGGER_FALLING ? !signals_in_p1[i] &&  signals_in_p2[i] :
                                                                              1'b1;

    end
    endgenerate

    wire trigger;
    assign trigger = &trigger_vec || trigger_always;

    //============================================================
    // SAVE TO RAM
    //============================================================
    reg [NR_SIGNALS-1:0]    store_data;

    reg [RAM_ADDR_BITS-1:0] store_addr; 
    reg [RAM_ADDR_BITS:0]   store_addr_nxt;             // Deliberately 1 bit larger!
    reg store_addr_wrapped, store_addr_wrapped_nxt;

    reg [RAM_ADDR_BITS-1:0] start_addr_nxt;
    reg [RAM_ADDR_BITS-1:0] stop_addr_nxt;
    reg [RAM_ADDR_BITS-1:0] trigger_addr_nxt;

    reg incr_start_addr, incr_start_addr_nxt;
    reg store_req;
    reg start_recording, recording;

    localparam FSM_IDLE                = 2'd0;
    localparam FSM_PRE_TRIGGER         = 2'd1;
    localparam FSM_POST_TRIGGER        = 2'd2;

    reg [1:0] cur_state, nxt_state;

    always @(*) begin
        nxt_state               = cur_state;

        start_addr_nxt          = start_addr;
        trigger_addr_nxt        = trigger_addr;
        stop_addr_nxt           = stop_addr;

        start_recording         = 1'b0;
        recording               = 1'b0;
        incr_start_addr_nxt     = 1'b0;

        case(cur_state)
            FSM_IDLE: begin
                if (start) begin
                    start_recording         = 1'b1;
                    start_addr_nxt          = 0;

                    nxt_state               = FSM_PRE_TRIGGER;
                end
            end
            FSM_PRE_TRIGGER: begin
                recording   = 1'b1;

                if (store_addr == RECORD_DEPTH/2) begin
                    incr_start_addr_nxt = 1'b1;
                end
        
                if (store_trigger) begin
                    start_addr_nxt      = start_addr + incr_start_addr;
                end

                if (trigger) begin
                    trigger_addr_nxt  = store_addr; 
                    stop_addr_nxt     = store_addr - RECORD_DEPTH/2 -1;

                    nxt_state               = FSM_POST_TRIGGER;
                end
            end
            FSM_POST_TRIGGER: begin
                recording   = 1'b1;

                if (store_trigger && store_addr == stop_addr) begin
                    nxt_state           = FSM_IDLE;
                end
            end
        endcase
    end

    always @(*) begin
        store_req               = 1'b0;
        store_addr_nxt          = store_addr;
        store_addr_wrapped_nxt  = store_addr_wrapped;
        store_data              = signals_in_p1;

        if (start_recording) begin
                store_addr_nxt          = 0;
                store_addr_wrapped_nxt  = 1'b0;
        end
        else if (recording) begin
            if (store_trigger) begin
                store_req               = 1'b1;
                store_addr_nxt          = store_addr + 1'b1;
                store_addr_wrapped_nxt  = store_addr_nxt[RAM_ADDR_BITS];
            end
        end
    end

    always @(posedge src_clk) begin
        cur_state           <= nxt_state;
        store_addr          <= store_addr_nxt[RAM_ADDR_BITS-1:0];
        store_addr_wrapped  <= store_addr_wrapped_nxt;
        start_addr          <= start_addr_nxt;
        trigger_addr        <= trigger_addr_nxt;
        stop_addr           <= stop_addr_nxt;
        incr_start_addr     <= incr_start_addr_nxt;

        if (!src_reset_) begin
            cur_state       <= FSM_IDLE;
            start_addr      <= 0;
            trigger_addr    <= 0;
            stop_addr       <= 0;
        end 
    end

`ifndef SYNTHESIS
    reg [16*8-1:0] cur_state_txt;

    always @(*) begin
        case(cur_state)
            FSM_IDLE:         cur_state_txt = "FSM_IDLE";
            FSM_PRE_TRIGGER:  cur_state_txt = "FSM_PRE_TRIGGER";
            FSM_POST_TRIGGER: cur_state_txt = "FSM_POST_TRIGGER";
            default:          cur_state_txt = "<UNKOWN>";
        endcase
    end
`endif

    assign state = cur_state;

    reg [RAM_ADDR_BITS-1:0] rd_addr;

    wire rd_ena;
    assign rd_ena = 1'b1;
    always @(posedge scan_clk) begin
        if (read_req_first) begin
            rd_addr <= 0;
        end
        else if (read_req_next) begin
            rd_addr <= rd_addr + 1'b1;
        end

        if (!scan_reset_) begin
            rd_addr <= 0;
        end
    end

    wire [NR_SIGNALS-1:0] rd_data;
    icetap_mem
    #(
        .ADDR_WIDTH(RAM_ADDR_BITS),
        .DATA_WIDTH(NR_SIGNALS)
    )
    u_mem
    (
        .wr_clk         (src_clk),
        .wr_ena         (store_req),
        .wr_addr        (store_addr),
        .wr_data        (store_data),

        .rd_clk         (scan_clk),
        .rd_ena         (rd_ena),
        .rd_addr        (rd_addr),
        .rd_data        (rd_data)
    );

    assign read_data = rd_data;

endmodule

