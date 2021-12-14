module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, wrt_data, done, rd_data);


// Inputs and Outputs //////////////////////////////

input logic clk, rst_n, wrt, MISO;
input logic [15:0] wrt_data;

output logic SS_n, SCLK, MOSI, done;
output logic [15:0] rd_data;


// Internal Signals ///////////////////////////////

logic smpl;
logic shft;
logic ld_SCLK;
logic init;
logic set_done;
logic [4:0] SCLK_div;
logic MISO_smpl;
logic [15:0] shft_reg;
logic [3:0] bit_cntr;
logic done15;
logic shft_dec;
logic smpl_dec;
logic SCLK_high;


// Define states /////////////////////////////////

typedef enum reg [1:0] {IDLE, FRT_PRCH, TRANS, BCK_PRCH} state_t;
state_t state, nxt_state;

// Infer internal logic //////////////////////////


// Shift register contains the data we are reading
assign rd_data = shft_reg;

// Logic for SCLK counter 
always_ff @(posedge clk) begin
	if(ld_SCLK) begin
		SCLK_div <= 5'b10111;
	end
	else begin
		SCLK_div <= SCLK_div + 1;
	end
end

assign SCLK = SCLK_high ? 1'b1 : SCLK_div[4];


// Logic for MISO
always_ff @(posedge clk) begin
	if(smpl) begin
		MISO_smpl <= MISO;
	end
end


// Logic for shift register and MOSI 
always_ff @(posedge clk) begin
	if(init) begin
		shft_reg <= wrt_data;
	end
	else if(shft) begin
		shft_reg <= {shft_reg[14:0], MISO_smpl};
	end
end

assign MOSI = shft_reg[15];

// Counter for how many times we have shifted the shift register
always_ff @(posedge clk) begin
	if(init) begin
		bit_cntr <= 4'b0000;
	end
	else if(shft) begin
		bit_cntr <= bit_cntr + 1;
	end
end

// Flip flop to determine SS_n
always @(posedge clk, negedge rst_n) begin
	
  if(!rst_n) begin
	SS_n <= 1;
  end
  else if(set_done == 1) begin
	SS_n <= 1;
  end
  else if(init == 1) begin
	SS_n <= 0;
  end
  else if(set_done == 0 && init == 0) begin
	SS_n <= SS_n;
  end

end

// Flip flop to determine done
always_ff @(posedge clk, negedge rst_n) begin
	
  if(!rst_n) begin
	done <= 0;
  end
  else if(set_done == 1) begin
	done <= 1;
  end
  else if(init == 1) begin
	done <= 0;
  end
  else if(set_done == 0 && init == 0) begin
	done <= done;
  end

end

assign done15 = &bit_cntr;

// Falling edge and rising edge coming 
assign smpl_dec = SCLK_div === 5'b01111 ? 1 : 0;
assign shft_dec = SCLK_div === 5'b11111 ? 1 : 0;


// Infer the state machine ////////////////////////////////

// Flip flop to infer next state
always_ff @(posedge clk, negedge rst_n) begin
  if(!rst_n)
	state <= IDLE;
  else 
	state <= nxt_state;
end

always_comb begin
	// Default outputs
	smpl = 0;
	shft = 0;
	ld_SCLK = 0;
	init = 0;
	set_done = 0;
	SCLK_high = 0;
	nxt_state = state;

	case(state) 
	  IDLE : begin
		SCLK_high = 1;
		if(wrt) begin
			init = 1;
			ld_SCLK = 1;
			nxt_state = FRT_PRCH;
		end
	  end
	  FRT_PRCH : begin
		if(shft_dec) begin
			nxt_state = TRANS;
		end
	  end
	  TRANS : begin
		if(smpl_dec) begin
			smpl = 1;
		end
		else if(done15) begin
			nxt_state = BCK_PRCH;
		end
		else if(shft_dec) begin
			shft = 1;
		end
	  end
	  BCK_PRCH : begin
		if(smpl_dec) begin
			smpl = 1;
		end
		else if(shft_dec) begin
			shft = 1;
			set_done = 1;
			nxt_state = IDLE;
			ld_SCLK = 1;
		end
	  end
	  default : nxt_state = IDLE;	 
	endcase
end


endmodule



	