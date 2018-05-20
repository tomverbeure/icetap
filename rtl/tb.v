
`default_nettype none

`timescale 1ns/100ps

module tb();

	initial begin
		$dumpfile("output/waves.vcd");
		$dumpvars(0);
	end
	
	reg clk;
	reg reset;

	initial begin
		clk = 1'b0;
	end

	initial begin
		reset = 1'b1;
		repeat(10) @(posedge clk)
			;
		reset = 1'b0;

		repeat(1000000) @(posedge clk);

		$finish;
	end

	always begin
		#5 clk = !clk;
	end

	wire uart_rx;
	wire uart_tx;

	top u_top
		(
		 .CLK_OSC100		(clk),
		 .UART_RX		(uart_rx),
		 .UART_TX		(uart_tx),

`ifdef SRAM
		 .RAMOE			(RAMOE),
		 .RAMWE			(RAMWE),
		 .RAMCS			(RAMCS),
		 .RAMLB			(RAMLB),
		 .RAMUB			(RAMUB),
		 .ADR			(ADR[17:0]),
		 .DAT			(DAT[15:0]),
`endif

		/*AUTOINST*/
		 // Outputs
		 .LED1			(LED1),
		 .LED2			(LED2),
		 .LED3			(LED3),
		 .LED4			(LED4),
		 // Inputs
		 .B1			(B1),
		 .B2			(B2),
		 .QSPICSN		(QSPICSN),
		 .QSPICK		(QSPICK),
		 .QSPIDQ		(QSPIDQ[3:0]));

	reg tb_tx_req;
	wire tb_tx_ready;
	reg [7:0] tb_tx_data;

	uart_tx u_uart_tx (
		.clk (clk),
		.reset_(!reset),
		.tx_req(tb_tx_req),
		.tx_ready(tb_tx_ready),
		.tx_data(tb_tx_data),
		.uart_tx(uart_rx)
	);

	initial begin
		tb_tx_req 	= 1'b0;
		@(negedge reset);

		repeat(1000) @(posedge clk);

		@(posedge clk);
		tb_tx_req 	= 1'b1;
		tb_tx_data 	= "H";

		@(posedge tb_tx_ready);
		@(posedge clk);

		tb_tx_data 	= "e";

		@(posedge tb_tx_ready);
		@(posedge clk);
		tb_tx_req 	= 1'b0;

		repeat(100000) @(posedge clk);

		$finish;
	end


endmodule

// Local Variables:
// verilog-library-flags:("-f icetap.vc")
// End:
