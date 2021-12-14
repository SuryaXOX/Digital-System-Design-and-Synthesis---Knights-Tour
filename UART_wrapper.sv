module UART_wrapper(clr_cmd_rdy, cmd_rdy, cmd, trmt, resp, tx_done, RX, TX, clk, rst_n);


// Inputs and Outputs /////////////////////

input logic clr_cmd_rdy;
input logic trmt;
input logic [7:0] resp;
input logic RX;
input clk;
input rst_n;

output logic cmd_rdy;
output logic [15:0] cmd;
output logic tx_done;
output logic TX;

// Internal signals ///////////////////////////////////////////

logic rx_rdy;
logic [7:0] rx_data;
logic clr_rdy;
logic [7:0] data_mux;
logic selc_data_mux;
logic [7:0] data_ff;
logic set_cmd_rdy;

// Define states /////////////////////

typedef enum reg {IDLE, CMD} state_t;
state_t state, nxt_state;

// Instantiate DUT /////////////////////////////////////////////

UART iDUT(.rx_rdy(rx_rdy), .rx_data(rx_data), .clr_rx_rdy(clr_rdy), .trmt(trmt), .tx_data(resp), .tx_done(tx_done), .RX(RX), .TX(TX), .clk(clk), .rst_n(rst_n));


/// Internal logic /////////////////////////////////////////////


// This data mux will cycle the high byte once rx_rdy has been asserted once
assign data_mux = selc_data_mux ? rx_data : data_ff;

// Flip flip that will feed into mux to cycle data once rx_rdy has been asserted once
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		data_ff <= 8'h00;
	end
	else begin
		data_ff <= data_mux;
	end
end

// Set-Reset flop to assert cmd_rdy

always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		cmd_rdy <= 1'b0;
	end
	else if(set_cmd_rdy) begin
		cmd_rdy <= 1'b1;
	end
	else if(clr_cmd_rdy) begin
		cmd_rdy <= 1'b0;
	end
end

// Output cmd will take high byte from the data flip flop and the low byte from rx_data after rx_rdy has been asserted twice
assign cmd[15:8] = data_ff;
assign cmd[7:0] = rx_data;


// Infer the state machine /////////////////////////////////////


// Flip flop to infer next state
always_ff @(posedge clk, negedge rst_n) begin
  if(!rst_n)
	state <= IDLE;
  else 
	state <= nxt_state;
end


always_comb begin
	// Default outputs
	selc_data_mux = 0;
	set_cmd_rdy = 0;
	clr_rdy = 0;

	case(state)
	  IDLE : begin
		if(rx_rdy == 1'b1) begin
			clr_rdy = 1;
			nxt_state = CMD;
			selc_data_mux = 1;
		end
	  end
	  CMD : begin
		if(rx_rdy == 1'b1) begin	
			set_cmd_rdy = 1;
			clr_rdy = 1;
			nxt_state = IDLE;
		end
	  end
	  default : nxt_state = IDLE;
	endcase
end

endmodule 