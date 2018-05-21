
`default_nettype none

module sync_pulse(
	input 	        src_clk,
	input 	        src_reset_,
	input 	        pulse_in,
	input 	        dst_clk,
	input 	        dst_reset_,
	output 	wire    pulse_out
	);

	reg pulse_in_active;

	always @(posedge src_clk) begin
		if (!src_reset_) begin
			pulse_in_active	<= 1'b0;
		end
		else if (pulse_in) begin
			pulse_in_active <= pulse_in;
		end
		else if (pulse_out_active_src) begin
			pulse_in_active <= 1'b0;
		end
	end

	wire pulse_out_active;
	sync_dd_c u_sync_pulse_in_active_sync( .clk(dst_clk), .reset_(dst_reset_), .sync_in(pulse_in_active), .sync_out(pulse_out_active) );

	reg pulse_out_active_d;
	always @(posedge dst_clk) begin
		pulse_out_active_d <= pulse_out_active;
	end

	assign pulse_out = pulse_out_active && !pulse_out_active_d;

	wire pulse_out_active_src;
	sync_dd_c u_sync_pulse_out_active_sync( .clk(src_clk), .reset_(src_reset_), .sync_in(pulse_out_active), .sync_out(pulse_out_active_src) );

endmodule
