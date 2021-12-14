module cmd_proc(clk,rst_n,cmd,cmd_rdy,clr_cmd_rdy,send_resp,strt_cal,
                cal_done,heading,heading_rdy,lftIR,cntrIR,rghtIR,error,
				frwrd,moving,tour_go,fanfare_go);
				
  parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
				
  input clk,rst_n;					// 50MHz clock and asynch active low reset
  input [15:0] cmd;					// command from BLE
  input logic cmd_rdy;					// command ready
  output logic clr_cmd_rdy;			// mark command as consumed
  output logic send_resp;			// command finished, send_response via UART_wrapper/BT
  output logic strt_cal;			// initiate calibration of gyro
  input cal_done;					// calibration of gyro done
  input signed [11:0] heading;		// heading from gyro
  input heading_rdy;				// pulses high 1 clk for valid heading reading
  input lftIR;						// nudge error +
  input cntrIR;						// center IR reading (have I passed a line)
  input rghtIR;						// nudge error -
  output logic signed [11:0] error;	// error to PID (heading - desired_heading)
  output logic [9:0] frwrd;			// forward speed register
  output logic moving;				// asserted when moving (allows yaw integration)
  output logic tour_go;				// pulse to initiate TourCmd block
  output logic fanfare_go;			// kick off the "Charge!" fanfare on piezo

  
  logic signed [11:0] err_nudge;
  logic [2:0] sq_count, cmd_mult;
  logic cntrIR_f;
  logic [9:0] inc;
  logic [9:0] dec;
  logic signed [11:0] desired_heading;
  logic inc_frwrd, dec_frwrd, zero, move_cmd, move_done, clr_frwrd, max_spd;
  logic rise_edge;
  logic flop;
  logic [3:0] op;
  logic [4:0] X_coord;
  logic [4:0] Y_coord;
  // FOR MTR DRIVE DO NOT TOUCH!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  logic [10:0] lft_spd, rght_spd;
  ///////////////////////////////////////////////////////////////////
  

  ////////////////////////////
  // Defining the States    //
  ////////////////////////////
  typedef enum reg [3:0]{IDLE, CAL, UPDATE, MOVE, SLOW} state_t;
  state_t state, nxt_state;
	
  ////////////////////////////
  // Resetting the states   //
  //////////////////////////// 
  always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) begin 
	state <= IDLE;
		end
  else state <= nxt_state;

  ////////////////////////////////////
  //      Forward Register          //
  ////////////////////////////////////
  always_ff@ (negedge clk, negedge rst_n) begin
	if(!rst_n)
		frwrd <= 10'h0;
	else if(clr_frwrd) 
		frwrd <= 10'h0;
	else if(inc_frwrd & heading_rdy & !max_spd)
		frwrd <= frwrd + inc;
	else if(dec_frwrd & heading_rdy & !zero) 
		frwrd <= frwrd - dec;
  end		
	
  generate
	  if(FAST_SIM) begin
	  	assign inc = 10'h20;
		assign dec = 10'h40;
	  end
	else begin
		assign inc = 10'h04;
		assign dec = 10'h08;
	end
	  endgenerate
  
  assign max_spd = (&frwrd[9:8]) ? 1 : 0;

  assign zero = (~(|frwrd[9:0])) ? 1'b1 : 1'b0;
 
  ////////////////////////////////////
  //      Counting Squares          //
  ////////////////////////////////////
	// rising edge detector
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) cntrIR_f <= 1'b0;
		else cntrIR_f <= cntrIR;
	end
	assign rise_edge = cntrIR & ~cntrIR_f;

	// counter flop
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) sq_count <= 3'h0;
		else if (move_cmd) sq_count <= 3'h0;
		else if (rise_edge) sq_count <= sq_count + 1;
	end

	// cmd flop
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n) cmd_mult <= 3'h0;
		else if (move_cmd) cmd_mult <= {cmd[1:0], 1'b0};		// multiplying by 2 because robot passes over two strips to move one square
	
	// comparing to set move_done
	assign move_done = (cmd_mult==sq_count) ? 1 : 0;


  ////////////////////////////////////
  //      	PID	            //
  ////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) desired_heading <= 12'h0;
	 	else if(move_cmd) begin
			desired_heading <= {cmd[11:4],cmd[7:4]};
	end
  end

  generate
	  if (FAST_SIM) begin
		  assign err_nudge = lftIR ? 12'h1ff : (rghtIR ? 12'he00 : 12'h000);	// should these numbers be signed?
	  end
	  else begin
		  assign err_nudge = lftIR ? 12'h05f : (rghtIR ? 12'hfa1 : 12'h000);
	  end
	  endgenerate

  assign error =  heading - desired_heading + err_nudge;

  ////////////////////////////////////
  //      Command Processing        //
  ////////////////////////////////////
  
  assign op = cmd[15:12];

  assign X_coord = (op == 0100) ? cmd[7:4] : 0;
  assign Y_coord = (op == 0100) ? cmd[3:0] : 0;

  

  ////////////////////////////////////
  //        State Machine           //
  ////////////////////////////////////



  always_ff @(posedge clk, negedge rst_n) begin  
	if(!rst_n)
	    state <= IDLE;
	else
	    state <= nxt_state;
  end 

  always_comb begin

    strt_cal = 0;
	clr_frwrd = 0;
	move_cmd = 0;
	send_resp = 0;
	tour_go = 0;
	fanfare_go = 0;
	moving = 0;
	clr_cmd_rdy = 0;
	inc_frwrd = 0;
	dec_frwrd = 0;
	nxt_state = state;

    case(state)

		MOVE: begin
					if(move_done && !cmd[12])
						nxt_state = SLOW;
					else if(move_done && cmd[12]) begin
						nxt_state = SLOW;
						fanfare_go = 1;
					end
					if(!move_done) begin
						moving = 1;
						inc_frwrd = 1;
						nxt_state = MOVE;
					end
				end
				
		UPDATE: begin
					if (error > $signed(12'hFD0) && error < $signed(12'h030)) begin
						nxt_state = MOVE;
						moving = 1;
						clr_frwrd = 1;
					end
					else begin
						nxt_state = UPDATE;
						moving = 1;
						clr_frwrd = 1;			
					end
				end
				
		SLOW: begin

					if (frwrd == 0) begin
									send_resp = 1;
									nxt_state =IDLE;
					end
					else begin
									moving = 1;
									nxt_state = SLOW;
									dec_frwrd = 1;
					end
				end
				
		CAL: begin
					if(cal_done) begin
						send_resp = 1;
						nxt_state = IDLE;
						end
					else 
						nxt_state = CAL;
				
				end
				
				
		IDLE : begin
				if(cmd_rdy) begin
						if(cmd[15:12] == 4'b0100)
							begin
								clr_cmd_rdy = 1;
								tour_go = 1;
								nxt_state = IDLE;
							end
						else if(cmd[15:12] == 4'b0000)
							begin
								strt_cal = 1;
								clr_cmd_rdy = 1;
								nxt_state = CAL;
							end
						else if(cmd[15:13] == 3'b001)
							begin
								move_cmd = 1;
								nxt_state = UPDATE;
							end

						end
				else begin
						nxt_state = IDLE;

					end
					


			end
			
		default: begin

			nxt_state = IDLE;

end

endcase

  end

endmodule
  

