
`default_nettype none

module top (
	// 100MHz clock input
	input		CLK_OSC100,

`ifdef SRAM
	// SRAM Memory lines
	output 		RAMOE,
	output 		RAMWE,
	output 		RAMCS,
	output 		RAMLB,
	output 		RAMUB,
	output [17:0]	ADR,
	output [15:0]	DAT,
`endif

	input 		UART_RX,
	output		UART_TX,

	input		B1,
	input		B2, 

	output		LED1,
	output		LED2,
	output		LED3,
	output		LED4,

	// QUAD SPI pins
	input		QSPICSN,
	input		QSPICK,
	input [3:0]	QSPIDQ
	);

	wire clk;
	wire reset_;

	wire UART_TX;
	wire UART_RX;

	assign clk = CLK_OSC100;

	assign LED1 = 1'b0;
	assign LED2 = 1'b0;
	assign LED3 = 1'b0;
	assign LED4 = 1'b0;

	sync_reset u_sync_reset(
		.clk(clk),
		.reset_in_(1'b1),
		.reset_out_(reset_)
	);


	// The uart_tx baud rate is slightly higher than 115200.
	// This is to avoid dropping bytes when the PC sends data at a rate that's a bit faster
	// than 115200. 
	// In a normal design, one typically wouldn't use immediate loopback, so 115200 would be the 
	// right value.

	reg [7:0] count;

	always @(posedge clk)
	begin
		if (!reset_) begin
			count <= 0;
		end
		else begin
			count <= count + 1;
		end
	end

	uart_tx #(.BAUD(116000)) u_uart_tx (
		.clk		(clk),
		.reset_		(reset_),
		.tx_req		(1'b0),
		.tx_ready	(),
		.tx_data	(8'd0),
		.uart_tx	(UART_TX)
	);

	wire [7:0] result;

	icetap_top 	
		#( .NR_SIGNALS(8) ) 
	u_icetap_top
		(
		 .spi_clk		(spi_clk),
		 .spi_ss_		(spi_ss_),
		 .spi_mosi		(spi_mosi),
		 .spi_miso		(spi_miso),

		 .scan_clk		(clk),
		 .scan_reset_		(reset_),
		 .src_clk		(clk),
		 .src_reset_		(reset_)
		);

endmodule

// Local Variables:
// verilog-library-flags:("-f icetap.vc")
// End:

