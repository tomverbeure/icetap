/******************************************************************************
*                                                                             *
* Copyright 2016 myStorm Copyright and related                                *
* rights are licensed under the Solderpad Hardware License, Version 0.51      *
* (the “License”); you may not use this file except in compliance with        *
* the License. You may obtain a copy of the License at                        *
* http://solderpad.org/licenses/SHL-0.51. Unless required by applicable       *
* law or agreed to in writing, software, hardware and materials               *
* distributed under this License is distributed on an “AS IS” BASIS,          *
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or             *
* implied. See the License for the specific language governing                *
* permissions and limitations under the License.                              *
*                                                                             *
******************************************************************************/
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

//	uart_rx #(.BAUD(115200)) u_uart_rx (
//		.clk (clk),
//		.reset_(reset_),
//		.rx_req(rx2tx_req),
//		.rx_ready(rx2tx_ready),
//		.rx_data(rx2tx_data),
//		.uart_rx(UART_RX)
//	);

	// The uart_tx baud rate is slightly higher than 115200.
	// This is to avoid dropping bytes when the PC sends data at a rate that's a bit faster
	// than 115200. 
	// In a normal design, one typically wouldn't use immediate loopback, so 115200 would be the 
	// right value.
	uart_tx #(.BAUD(116000)) u_uart_tx (
		.clk		(clk),
		.reset_		(reset_),
		.tx_req		(1'b0),
		.tx_ready	(),
		.tx_data	(8'd0),
		.uart_tx	(UART_TX)
	);


endmodule
