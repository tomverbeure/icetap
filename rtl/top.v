
`default_nettype none

module top (
    input       osc_clk,

    input       button1,
    input       button2,

    output      led1,
    output      led2,
    output      led3,
    output      led4,

    input       tck,
    input       tms,
    input       tdi,
    output      tdo
    );

    wire clk;
    wire reset_;

    assign led1 = count[25];
    assign led2 = count[24];
    assign led3 = count[23];
    assign led4 = count[22];

    assign clk = osc_clk;

    sync_reset u_sync_reset(
        .clk(clk),
        .reset_in_(1'b1),
        .reset_out_(reset_)
    );

    reg [25:0] count;
    initial count = 0;

    always @(posedge clk)
    begin
        if (!reset_) begin
            count <= 0;
        end
        else begin
            count <= count + 1'b1;
        end
    end

    jtag_icetap
        #( .NR_SIGNALS(16), .RECORD_DEPTH(256) )
    u_jtag_icetap
    (
        .trst_          (1'b1),
        .tck            (tck),
        .tms            (tms),
        .tdi            (tdi),
        .tdo            (tdo),

        .clk            (clk),
        .reset_         (reset_),

        .signals_in     ({ count[13:0], led1, button1 })
        );

endmodule

