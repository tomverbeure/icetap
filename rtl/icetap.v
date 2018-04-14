
// This module converts the parallel control, data and status signals to a scan-based interface, which can be used
// by SPI, JTAG etc.
module icetap_scan 
  	#(
    		parameter NR_SIGNALS            = 16,
		parameter RECORD_DEPTH		= 256,
	    	parameter COMPLEX_STORE	        = 1,
	    	parameter COMPLEX_TRIGGER       = 1
    	) 
    	(
     		// Scan chains
		input				scan_clk,
		input				scan_reset_,
		
		input				cmd_shift_ena,
		input				cmd_shift_update,
		input				cmd_shift_data,

		input				status_shift_update,
		input				status_shift_ena,
		output 				status_shift_data,

		input				store_mask_shift_ena,
		input				store_mask_shift_data,

		input				trigger_mask_shift_ena,
		input				trigger_mask_shift_data,

		input				data_shift_update,
		input				data_shift_ena,
		output 				data_shift_data,

		output [NR_SIGNALS*3-1:0]	store_mask_vec,
		output [NR_SIGNALS*3-1:0]	trigger_mask_vec,

		input				src_clk,
		input				src_reset_,

		output 				start,
		output 				store_always,
		output 				trigger_always,

		input [1:0]			state,

		input [RAM_ADDR_BITS-1:0]	start_addr, 
		input [RAM_ADDR_BITS-1:0]	trigger_addr, 
		input [RAM_ADDR_BITS-1:0]	stop_addr,

		output 				read_req_first,
		output				read_req_next,
		input [NR_SIGNALS-1:0] 		read_data
		/*AUTOARG*/);

	localparam RAM_ADDR_BITS = $clog2(RECORD_DEPTH);

	wire src_clk;
	wire src_reset_;

	/*AUTOWIRE*/
	/*AUTOREG*/
	// Beginning of automatic regs (for this module's undeclared outputs)
	reg		data_shift_data;
	reg		signals_out_req;
	// End of automatics

	reg [NR_SIGNALS*3-1:0]      store_mask_vec;
	reg [NR_SIGNALS*3-1:0]      trigger_mask_vec;

	//============================================================
	// STORE_MASK
	//============================================================
	if (COMPLEX_STORE == 1) begin
		always @(posedge scan_clk) begin
			if (store_mask_shift_ena) begin
				store_mask_vec <= { store_mask_vec, store_mask_shift_data };
		    	end
		end
	end
	else begin
		always @(*) begin
			store_mask_vec  <= {(NR_SIGNALS*3){1'b0}};
		end
	end

	//============================================================
	// TRIGGER_MASK
	//============================================================
	if (COMPLEX_TRIGGER == 1) begin
		always @(posedge scan_clk) begin
			if (trigger_mask_shift_ena) begin
				trigger_mask_vec <= { trigger_mask_vec, trigger_mask_shift_data };
			end
		end
	end
	else begin
		always @(*) begin
			trigger_mask_vec <= {(NR_SIGNALS*3){1'b0}};
		end
	end

	//============================================================
	// CMD
	//============================================================
	reg [2:0] cmd_shift_reg;

	always @(posedge scan_clk) begin
		if (!scan_reset_) begin
			cmd_shift_reg <= 0;
		end
		else begin
			if (cmd_shift_ena) begin
				cmd_shift_reg <= { cmd_shift_reg, cmd_shift_data };
			end
		end
	end

	//============================================================
	// STATUS
	//============================================================
	wire [63:0] status_vec;
	assign status_vec = { start_addr, trigger_addr, stop_addr, state };

	reg [7:0] status_scan_reg;
	reg [5:0] status_bit_cntr;
	always @(posedge scan_clk) begin
		if (!scan_reset_) begin
			status_scan_reg <= 0;
			status_bit_cntr	<= 1;
		end
		else if (status_shift_update) begin
			status_scan_reg	<= status_vec[7:0];
			status_bit_cntr <= 1;
		end
		else if (status_shift_ena) begin
			status_bit_cntr 	<= status_bit_cntr + 1;
			if (status_bit_cntr[2:0] != 0) begin
				status_scan_reg <= { status_scan_reg[6:0], 1'b0 };
			end
			else begin
				status_scan_reg <= (status_bit_cntr[5:3] == 1) ? status_vec[15:8]  : 
				                   (status_bit_cntr[5:3] == 2) ? status_vec[31:16] : 
				                   (status_bit_cntr[5:3] == 3) ? status_vec[47:32] : 0;
			end
		end
	end

	assign status_shift_data = status_scan_reg[7];

	//============================================================
	// DATA
	//============================================================


	localparam NR_DATA_BYTES = (NR_SIGNALS+7)/8;
	reg [NR_DATA_BYTES*8-1:0] data_vec;
	assign data_vec = read_data;

	localparam DATA_BIT_CNTR_BITS = $clog2(NR_DATA_BYTES*8);

	reg [DATA_BIT_CNTR_BITS-1:0] data_bit_cntr, data_bit_cntr_nxt;

	integer i;
	reg [7:0] data_scan_reg, data_scan_reg_nxt;
	always @(*) begin
		data_scan_reg_nxt = read_data;
		
		for(i=1;i<NR_DATA_BYTES;i=i+1) begin
			if (data_bit_cntr[DATA_BIT_CNTR_BITS-1:3] == i) begin
				data_scan_reg_nxt = data_vec[i*8+7:i*8];
			end
		end
	end

	assign read_req_first = data_shift_update;

	reg read_req_next;
	reg data_scan_reg_update;
	always @(*) begin
		read_req_next <= 1'b0;
		data_scan_reg_update <= 1'b0;

		if (data_shift_update) begin
			data_bit_cntr_nxt <= 0;
		end
		else if (data_shift_ena) begin
			if (data_bit_cntr[DATA_BIT_CNTR_BITS-1:3] != NR_DATA_BYTES) begin
				data_bit_cntr_nxt <= data_bit_cntr + 1;
			end
			else begin
				data_bit_cntr_nxt <= 0;
				read_req_next <= 1'b1;
			end
		end
	end
	

	// SRC_CLK clock domain

	wire cmd_update_sync;
	sync_pulse u_sync_pulse_cmd_shift_update
		(
			.src_clk	(scan_clk),
			.src_reset_	(scan_reset_),
			.pulse_in	(cmd_shift_update),
			.dst_clk	(src_clk),
			.dst_reset_	(src_reset_),
			.pulse_out	(cmd_update_sync)
		);

	reg [2:0] cmd_reg_sync;
	reg       cmd_update_sync_d;

	always @(posedge src_clk) begin
		if (cmd_update_sync && !cmd_update_sync_d) begin
			cmd_reg_sync	<= cmd_shift_reg;
		end

		if (!src_reset_) begin
			cmd_reg_sync	<= 3'd0;
		end

		cmd_update_sync_d <= cmd_update_sync;
	end

	assign start          = cmd_reg_sync[0];
	assign store_always   = cmd_reg_sync[1];
	assign trigger_always = cmd_reg_sync[2];


	wire [1:0]	state_sync;
	sync_dd_c u_sync_state[1:0] ( .clk(scan_clk), .reset_(scan_reset_), .sync_in(state), .sync_out(state_sync));

endmodule


module icetap_bram
	#(
		parameter NR_SIGNALS        = 16,
		parameter RECORD_DEPTH      = 256
	) (
		input                   	src_clk,
		input                   	src_reset_,
		input [NR_SIGNALS-1:0]  	signals_in,

		input                   	start,
 		input                   	store_always,
 		input                   	trigger_always,

                input [3*NR_SIGNALS-1:0] 	store_mask_vec,
                input [3*NR_SIGNALS-1:0] 	trigger_mask_vec,

		output [1:0]                  	state,

		output [RAM_ADDR_BITS-1:0]	start_addr,
		output [RAM_ADDR_BITS-1:0]	trigger_addr,
		output [RAM_ADDR_BITS-1:0]	stop_addr,

		input 				scan_clk,
		input 				scan_reset_,

		input                   	read_req_first,
		output                  	read_req_next,
		output [NR_SIGNALS-1:0] 	read_data
	/*AUTOARG*/);

	localparam RAM_ADDR_BITS = $clog2(RECORD_DEPTH);

	wire src_clk;
	wire src_reset_;

	reg [NR_SIGNALS-1:0]    signals_in_p1, signals_in_p2;

	always @(posedge src_clk) begin
		signals_in_p1 	<= signals_in;
		signals_in_p2 	<= signals_in_p1;
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
	for(i=0; i<NR_SIGNALS; i=i+1) begin
		assign store_trigger_vec[i] = store_mask_vec[3*i+2:3*i] == TRIGGER_HIGH    ?  signals_in_p1[i]                       :
		                              store_mask_vec[3*i+2:3*i] == TRIGGER_LOW     ? !signals_in_p1[i]                       :
		                              store_mask_vec[3*i+2:3*i] == TRIGGER_RISING  ?  signals_in_p1[i] && !signals_in_p2[i] :
		                              store_mask_vec[3*i+2:3*i] == TRIGGER_FALLING ? !signals_in_p1[i] &&  signals_in_p2[i] :
			                                                                       1'b0;

	end

	wire store_trigger;
	assign store_trigger = |store_trigger_vec || store_always;

	//============================================================
	// CAPTURE TRIGGER
	//============================================================
	wire [NR_SIGNALS-1:0]   trigger_vec;

	for(i=0; i<NR_SIGNALS; i=i+1) begin
		assign trigger_vec[i] = trigger_mask_vec[3*i+2:3*i] == TRIGGER_HIGH    ?  signals_in_p1[i]                       :
		                        trigger_mask_vec[3*i+2:3*i] == TRIGGER_LOW     ? !signals_in_p1[i]                       :
		                        trigger_mask_vec[3*i+2:3*i] == TRIGGER_RISING  ?  signals_in_p1[i] && !signals_in_p2[i] :
		                        trigger_mask_vec[3*i+2:3*i] == TRIGGER_FALLING ? !signals_in_p1[i] &&  signals_in_p2[i] :
			                                                                  1'b1;

	end

	wire trigger;
	assign trigger = &trigger_vec || trigger_always;

	//============================================================
	// SAVE TO RAM
	//============================================================
	reg [NR_SIGNALS-1:0]    store_data;

	reg [RAM_ADDR_BITS-1:0]	store_addr; 
	reg [RAM_ADDR_BITS:0]	store_addr_nxt;
	reg store_addr_wrapped, store_addr_wrapped_nxt;

	reg [RAM_ADDR_BITS-1:0]	start_addr, start_addr_nxt;
	reg [RAM_ADDR_BITS-1:0]	stop_addr, stop_addr_nxt;
	reg [RAM_ADDR_BITS-1:0]	trigger_addr, trigger_addr_nxt;

	reg incr_start_addr, incr_start_addr_nxt;
	reg store_req;
	reg start_recording, recording;

	localparam FSM_IDLE                = 3'd0;
	localparam FSM_PRE_TRIGGER         = 3'd1;
	localparam FSM_POST_TRIGGER        = 3'd2;
	localparam FSM_SCANOUT             = 3'd3;

	reg [2:0] cur_state, nxt_state;

	always @(*) begin
		nxt_state               = cur_state;

		start_addr_nxt 		= start_addr;
		trigger_addr_nxt        = trigger_addr;
		stop_addr_nxt           = stop_addr;

		start_recording 	= 1'b0;
		recording 		= 1'b0;

		case(cur_state)
			FSM_IDLE: begin
				if (start) begin
					start_recording 	= 1'b1;
					start_addr_nxt 		= 0;
					incr_start_addr_nxt 	= 1'b0;

					nxt_state               = FSM_PRE_TRIGGER;
				end
			end
			FSM_PRE_TRIGGER: begin
				recording	= 1'b1;

				if (store_addr == RECORD_DEPTH/2) begin
					incr_start_addr_nxt	= 1'b1;
				end
		
				if (store_trigger) begin
					start_addr_nxt 		= start_addr + incr_start_addr;
				end

				if (trigger) begin
					trigger_addr_nxt  = store_addr; 
					stop_addr_nxt     = store_addr - RECORD_DEPTH/2;

					nxt_state               = FSM_POST_TRIGGER;
				end
			end
			FSM_POST_TRIGGER: begin
				recording	= 1'b1;

				if (store_addr == stop_addr) begin
					nxt_state           = FSM_SCANOUT;
				end
			end
			FSM_SCANOUT: begin
			end
		endcase
	end

	always @(*) begin
		store_req		= 1'b0;
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
				store_addr_nxt          = store_addr + 1;
				store_addr_wrapped_nxt  = store_addr_nxt[RAM_ADDR_BITS];
			end
		end
	end

	always @(posedge src_clk) begin
		cur_state      	    <= nxt_state;
		store_addr          <= store_addr_nxt;
		store_addr_wrapped  <= store_addr_wrapped_nxt;
		start_addr          <= start_addr_nxt;
		trigger_addr        <= trigger_addr_nxt;
		stop_addr           <= stop_addr_nxt;
		incr_start_addr     <= incr_start_addr_nxt;

		if (!src_reset_) begin
			cur_state       <= FSM_IDLE;
			start_addr	<= 0;
			trigger_addr	<= 0;
			stop_addr	<= 0;
		end 
	end

	reg [16*8-1:0] cur_state_txt;

	always @(*) begin
		case(cur_state)
			FSM_IDLE:         cur_state_txt = "FSM_IDLE";
			FSM_PRE_TRIGGER:  cur_state_txt = "FSM_PRE_TRIGGER";
			FSM_POST_TRIGGER: cur_state_txt = "FSM_POST_TRIGGER";
			FSM_SCANOUT:      cur_state_txt = "FSM_SCANOUT";
			default:          cur_state_txt = "<UNKOWN>";
		endcase
	end

	wire [1:0] state;
	assign state = cur_state;

	reg [RAM_ADDR_BITS-1:0]	rd_addr;

	assign rd_ena = 1'b1;
	always @(posedge scan_clk) begin
		if (!scan_reset_) begin
			rd_addr <= 0;
		end
		else if (read_req_first) begin
			rd_addr	<= 0;
		end
		else if (read_req_next) begin
			rd_addr	<= rd_addr + 1;
		end
	end

	icetap_mem
	#(
		.ADDR_WIDTH(RAM_ADDR_BITS),
		.DATA_WIDTH(NR_SIGNALS)
	)
	u_mem
	(
	 	.wr_clk			(src_clk),
	 	.wr_ena			(store_req),
	 	.wr_addr		(store_addr),
	 	.wr_data		(store_data),

	 	.rd_clk			(scan_clk),
	 	.rd_ena			(rd_ena),
	 	.rd_addr		(rd_addr),
	 	.rd_data		(rd_data)
	);

endmodule


module icetap_mem
	#(
		parameter ADDR_WIDTH = 8,
		parameter DATA_WIDTH = 8
	)(
		input			wr_clk,
		input 			wr_ena,
		input [ADDR_WIDTH-1:0]	wr_addr,
		input [DATA_WIDTH-1:0]	wr_data,
		
		input 			rd_clk,
		input 			rd_ena,
		input [ADDR_WIDTH-1:0]	rd_addr,
		output [DATA_WIDTH-1:0]	rd_data
	);

	reg [DATA_WIDTH-1:0] mem[0:(2<<ADDR_WIDTH)-1];

	always @(posedge wr_clk) begin
		if (wr_ena) begin
			mem[wr_addr] <= wr_data;
		end
	end

	always @(posedge rd_clk) begin
		if (rd_ena) begin
			rd_data <= mem[rd_addr];
		end
	end

endmodule


