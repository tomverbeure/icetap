`default_nettype none
`timescale 1ns/100ps

module icetap_tb();

    initial begin
        $dumpfile("output/waves.vcd");
        $dumpvars(0);
    end
    

    reg clk;
    reg reset_;

    initial begin
        clk = 1'b0;
    end

    always begin
        #5 clk = !clk;
    end

    initial begin
        reset_ = 1'b0;
        repeat(10) @(posedge clk)
            ;
        reset_ = 1'b1;

        repeat(1000000) @(posedge clk);

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
    reg    tdo_en;

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

        .clk                (clk),
        .reset_             (reset_),

        .signals_in         (signals_in)
    );

`include "jtag_tap_defines.v"

    parameter IR_LENGTH = `IR_LENGTH;
    parameter MAX_TDO_VEC   = 64;

`include "jtag_tb_tasks.v"

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


endmodule

// Local Variables:
// verilog-library-flags:("-f icetap.vc")
// End:
