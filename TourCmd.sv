module TourCmd(clk,rst_n,start_tour,move,mv_indx,
               cmd_UART,cmd,cmd_rdy_UART,cmd_rdy,
			   clr_cmd_rdy,send_resp,resp);

   input clk,rst_n;			// 50MHz clock and asynch active low reset
   input start_tour;			// from done signal from TourLogic
   input [7:0] move;			// encoded 1-hot move to perform
   output logic [4:0] mv_indx;	// "address" to access next move
   input [15:0] cmd_UART;	// cmd from UART_wrapper
   input cmd_rdy_UART;		// cmd_rdy from UART_wrapper
   output [15:0] cmd;		// multiplexed cmd to cmd_proc
   output logic cmd_rdy;			// cmd_rdy signal to cmd_proc
   input clr_cmd_rdy;		// from cmd_proc (goes to UART_wrapper too)
   input send_resp;			// lets us know cmd_proc is done with command
   output [7:0] resp;		// either 0xA5 (done) or 0x5A (in progress)
   
   // intermediate signals
   logic idle_sel;			// mux to choose between UART_Wrapper and SM, 0 means it's from UART
   logic direction;			// 0 means vertical, 1 means horizontal
   logic [15:0] cmd_SM;		// decomposed cmd from tourlogic's move and the SM of this block
   logic cmd_rdy_SM;		// cmd_rdy from this block' SM
   logic zero_mv_indx;		// from state machine...
   logic inc_mv_indx;		//	... to decide whether to zero or increment mv_indx
   

   /**************** 
   **STATE MACHINE** 
   *****************/
	typedef enum reg [2:0] {IDLE, VERT1, VERT2, HORZ1, HORZ2} state_t;
	state_t state, nxt_state;
   
   // state flop
	always_ff @ (posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			state <= IDLE;
		end
		else
			state <= nxt_state;
	end

   // state transition logic
	always_comb begin
		idle_sel = 1;
		nxt_state = state;
		cmd_rdy_SM = 0;
		direction = 0;
		zero_mv_indx = 1'b0;
		inc_mv_indx = 1'b0;

		case(state) 
			IDLE: begin
				if(~start_tour)
					idle_sel = 0;
				else begin
					idle_sel = 1'b1;
					zero_mv_indx = 1'b1;
					nxt_state = VERT1;
				end
			end

			VERT1: begin
					idle_sel = 1'b1;
					direction = 0;
					if(clr_cmd_rdy)
						nxt_state = VERT2;
					else 
						cmd_rdy_SM = 1;
				end

			VERT2: begin
					idle_sel = 1'b1;
					direction = 0;
					if(send_resp)
						nxt_state = HORZ1;
				end
				
			HORZ1: begin
					idle_sel = 1'b1;
					direction = 1;
					if(clr_cmd_rdy)
						nxt_state = HORZ2;
					else
						cmd_rdy_SM = 1;
			end
				
			HORZ2: begin
					idle_sel = 1'b1;
					direction = 1;
					if(send_resp & mv_indx == 5'd23)
						nxt_state = IDLE;
					else if(send_resp & mv_indx != 5'd23) begin
						nxt_state = VERT1;
						inc_mv_indx = 1'b1;
					end
					else if(~send_resp)
						nxt_state = HORZ2;
			end
				
			default: begin
				direction = 0;
				zero_mv_indx = 1'b1;
				inc_mv_indx = 1'b0;
				cmd_rdy_SM = 1'b0;
				nxt_state = IDLE;
			end

		endcase
	end

   // counter till 24
   always_ff @(posedge clk, negedge rst_n) begin
      if (!rst_n) mv_indx <= 5'd0;
      else
         if (zero_mv_indx) mv_indx <= 5'd0;
         else if (inc_mv_indx) mv_indx <= mv_indx + 1;
   end

   // decomposing the move
   always_comb begin
      case(move)
		8'b00000001: begin
			case(direction)
				1'b0: begin cmd_SM[15:12]=4'b0010;	cmd_SM[11:4]=8'h00;	cmd_SM[3:0]=4'h2; end
				1'b1: begin cmd_SM[15:12]=4'b0011;	cmd_SM[11:4]=8'hBF;	cmd_SM[3:0]=4'h1; end
			endcase
			end

		8'b00000010: begin
			case(direction)
				1'b0: begin cmd_SM[15:12]=4'b0010;	cmd_SM[11:4]=8'h00; cmd_SM[3:0]=4'h2; end
				1'b1: begin cmd_SM[15:12]=4'b0011;	cmd_SM[11:4]=8'h3F; cmd_SM[3:0]=4'h1; end
			endcase
			end

		8'b00000100: begin
			case(direction)
				1'b0: begin cmd_SM[15:12]=4'b0010;	cmd_SM[11:4]=8'h00; cmd_SM[3:0]=4'h1; end
				1'b1: begin cmd_SM[15:12]=4'b0011;	cmd_SM[11:4]=8'h3F; cmd_SM[3:0]=4'h2; end
			endcase
			end

		8'b00001000: begin
			case(direction)
				1'b0: begin cmd_SM[15:12]=4'b0010;	cmd_SM[11:4]=8'h7F; cmd_SM[3:0]=4'h1; end
				1'b1: begin cmd_SM[15:12]=4'b0011;	cmd_SM[11:4]=8'h3F; cmd_SM[3:0]=4'h2; end
			endcase
			end

		8'b00010000: begin
			case(direction)
				1'b0: begin cmd_SM[15:12]=4'b0010;	cmd_SM[11:4]=8'h7F; cmd_SM[3:0]=4'h2; end
				1'b1: begin cmd_SM[15:12]=4'b0011;	cmd_SM[11:4]=8'h3F; cmd_SM[3:0]=4'h1; end
			endcase
			end
		8'b00100000: begin
			case(direction)
				1'b0: begin cmd_SM[15:12]=4'b0010;	cmd_SM[11:4]=8'h7F; cmd_SM[3:0]=4'h2; end
				1'b1: begin cmd_SM[15:12]=4'b0011;	cmd_SM[11:4]=8'hBF; cmd_SM[3:0]=4'h1; end
			endcase
			end

		8'b01000000: begin
			case(direction)
				1'b0: begin cmd_SM[15:12]=4'b0010;	cmd_SM[11:4]=8'h7F; cmd_SM[3:0]=4'h1; end
				1'b1: begin cmd_SM[15:12]=4'b0011;	cmd_SM[11:4]=8'hBF; cmd_SM[3:0]=4'h2; end
			endcase
			end

		8'b10000000: begin
			case(direction)
				1'b0: begin cmd_SM[15:12]=4'b0010;	cmd_SM[11:4]=8'h00; cmd_SM[3:0]=4'h1; end
				1'b1: begin cmd_SM[15:12]=4'b0011;	cmd_SM[11:4]=8'hBF; cmd_SM[3:0]=4'h2; end
			endcase
			end

      endcase
   end

   // resp selector between A5 and 5A
   assign resp = (!idle_sel && mv_indx==5'd23) ? 8'hA5 : 8'h5A;


   // muxes to decide between UART_wrapper or SM
   assign cmd = idle_sel ? cmd_SM : cmd_UART;
   assign cmd_rdy = idle_sel ? cmd_rdy_SM : cmd_rdy_UART;
  
endmodule