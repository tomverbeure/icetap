
`default_nettype none

module sync_reset(
	input 	wire    clk,
	input 	wire    reset_in_, 
	output	wire    reset_out_
	);

	reg	    reset_in_p1_;
	reg	    reset_in_p2_;

	always @(posedge clk or negedge reset_in_)
	begin
		if (!reset_in_) begin
			reset_in_p1_ 	<= 1'b0;
			reset_in_p2_ 	<= 1'b0;
		end
		else begin
			reset_in_p1_ 	<= reset_in_;
			reset_in_p2_ 	<= reset_in_p1_;
		end
	end

	assign reset_out_ = reset_in_p2_;

endmodule
