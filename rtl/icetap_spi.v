
`default_nettype none

module icetap_spi 
	(
	input  			spi_clk,
	input  			spi_ss_,
	input  			spi_mosi,
	output 			spi_miso,

	input  			scan_clk,
	input  			scan_reset_,

	output 			cmd_shift_ena,
	output 			cmd_shift_update,
	output 			cmd_shift_data,

	output 			status_shift_update,
	output 			status_shift_ena,
	input  			status_shift_data,

	output 			store_mask_shift_ena,
	output 			store_mask_shift_data,

	output 			trigger_mask_shift_ena,
	output 			trigger_mask_shift_data,

	output 			data_shift_update,
	output 			data_shift_ena,
	input  			data_shift_data
	);

	/*AUTOWIRE*/
	/*AUTOREG*/

	localparam SPI_ADDR_CMD 	= 0;
	localparam SPI_ADDR_STATUS 	= 1;
	localparam SPI_ADDR_DATA 	= 2;
	localparam SPI_ADDR_STORE_MASK 	= 3;
	localparam SPI_ADDR_TRIGGER_MASK= 4;

	wire spi_clk_sync, spi_ss_sync_;

	reg [3:0] spi_bit_cntr;
	reg [7:0] spi_addr;
	reg       spi_clk_p1, spi_clk_p2;
	reg       addr_done;

	sync_dd_c u_sync_spi_clk( .clk(scan_clk), .reset_(scan_reset_), .sync_in(spi_clk),  .sync_out(spi_clk_sync) );
	sync_dd_c u_sync_spi_ss_( .clk(scan_clk), .reset_(scan_reset_), .sync_in(spi_ss_),  .sync_out(spi_ss_sync_) );

	reg spi_clk_sync_d, spi_ss_sync_d_;
	
	always @(posedge scan_clk) begin
		addr_done     <= 1'b0;

		if (spi_ss_sync_) begin
			spi_bit_cntr  <= 0;
			spi_addr      <= 0;
		end
		else if (spi_clk_sync && !spi_clk_sync_d) begin
			if (spi_bit_cntr <= 7) begin
				spi_addr     <= {spi_addr, spi_mosi };
				spi_bit_cntr <= spi_bit_cntr + 1;
				addr_done    <= (spi_bit_cntr == 7);
			end
		end

		spi_clk_sync_d <= spi_clk_sync;
		spi_ss_sync_d_ <= spi_ss_sync_;
	end

	reg cmd_shift_ena, cmd_shift_update, cmd_shift_data;
	reg status_shift_ena, status_shift_update;
	reg store_mask_shift_ena, store_mask_shift_data;
	reg trigger_mask_shift_ena, trigger_mask_shift_data ;
	reg data_shift_update, data_shift_ena;

	wire status_shift_data;

	always @(*) begin
		cmd_shift_ena           = 1'b0;
		cmd_shift_update        = 1'b0;
		cmd_shift_data          = 1'b0;

		status_shift_ena        = 1'b0;
		status_shift_update     = 1'b0;

		store_mask_shift_ena    = 1'b0;
		store_mask_shift_data   = 1'b0;

		trigger_mask_shift_ena  = 1'b0;
		trigger_mask_shift_data = 1'b0;

		data_shift_update       = 1'b0;
		data_shift_ena          = 1'b0;

		if (spi_ss_sync_ && !spi_ss_sync_d_) begin
			cmd_shift_update    = (spi_addr == SPI_ADDR_CMD);
		end	
		else if (addr_done) begin
			status_shift_update = (spi_addr == SPI_ADDR_STATUS);
			data_shift_update   = (spi_addr == SPI_ADDR_DATA);
		end
		else if (spi_clk_sync && !spi_clk_sync_d) begin
			if (spi_bit_cntr[3]) begin
				case(spi_addr)
					SPI_ADDR_CMD: begin
						cmd_shift_ena	= 1'b1;
						cmd_shift_data	= spi_mosi;
					end
					SPI_ADDR_STATUS: begin
						status_shift_ena = 1'b1;
					end
					SPI_ADDR_DATA: begin
						data_shift_ena = 1'b1;
					end
					SPI_ADDR_STORE_MASK: begin
						store_mask_shift_ena  = 1'b1;
						store_mask_shift_data = spi_mosi;
					end
					SPI_ADDR_TRIGGER_MASK: begin
						trigger_mask_shift_ena  = 1'b1;
						trigger_mask_shift_data = spi_mosi;
					end
				endcase
			end
		end
	end

	reg		spi_miso;
	always @(posedge scan_clk) begin
		case(spi_addr)
			SPI_ADDR_STATUS: spi_miso <= status_shift_data;
			SPI_ADDR_DATA:   spi_miso <= data_shift_data;
			default:         spi_miso <= 1'b0;
		endcase
	end

endmodule

