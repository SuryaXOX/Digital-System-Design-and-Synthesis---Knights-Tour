module TourLogic(clk, rst_n, x_start, y_start, go, done, indx, move);



  //////////////////////////////////////
  //        Inputs and Outputs       //
  ////////////////////////////////////

  input logic clk;
  input logic rst_n;
  input logic [2:0] x_start;      // Starting x position of knight
  input logic [2:0] y_start;      // Starting y position of knight
  input logic go;

  output logic done;
  output logic [4:0] indx;        // Used to access each of the 24 final moves
  output logic [7:0] move;



  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum reg [2:0] {IDLE, INIT, FINDMOVE, CHECKVALID, INTER, BACKUP, UPDATEBOARD, DONE} state_t;
  state_t state, nxt_state;


  //////////////////////////////////////
  //       Internal signals          //
  ////////////////////////////////////
 

  logic signed [3:0] x_pos;                    // Current x position of knight, we make this 4 bits so we don't have overflow when adding the change in x
  logic signed [3:0] y_pos;                    // Current y position of knight, we make this 4 bits so we don't have overflow when adding the change in y
  logic [6:0] move_number;                     // Current move the knight is on
  logic board [4:0][4:0];                      // 5 by 5 chess board
  logic [7:0] nxt_move;
  logic [7:0] move_array [23:0];               // 24, 1 hot encoded 8 bit moves, moves are stored from index 0 (first move) to index 23 (last move)
  logic signed [3:0] x_pos_change;             // Change in x position based on nxt_move
  logic signed [3:0] y_pos_change;             // Change in y position based on nxt_move 
  logic signed [3:0] reverse_x_pos;            // Used when we need to back track
  logic signed [3:0] reverse_y_pos;
  logic signed [3:0] x_sum;
  logic signed [3:0] y_sum;
 
  // State machine outputs
  logic increment_move;
  logic decrement_move;
  logic set_start;
  logic update_position;
  logic reverse_position;
  logic initialize;
  logic reverse_board;
  logic update_board;
  logic find_reverse_pos;
  logic update_moves;
  logic zero_move;


  //////////////////////////////////////
  //        Internal logic           //
  ////////////////////////////////////

  // When move_array has been populated, indx can be used to retrieve each move 
  assign move = move_array[indx];

  assign x_sum = x_pos + x_pos_change;
  assign y_sum = y_pos + y_pos_change;
  
  // This function essentially iterates the current move to the next move by shifting all bits left by 1
  function void find_move(input [6:0] move_number, input [7:0] move_array [23:0], output [7:0] nxt_move);

	nxt_move = move_array[move_number];

	// If the next move has a one in it, then it is a valid move and we can shift the bits left
	// If there are no 1s then we set the move to the first move
	nxt_move = ( (|nxt_move) ) ? {nxt_move[6:0], 1'b0} : 8'b00000001;

  endfunction

  // This function simply rotates nxt_move by 1 bit to the left
  function void rotate_move(input [7:0] nxt_move, output [7:0] nxt_move_out);

	nxt_move_out = {nxt_move[6:0], 1'b0};

  endfunction

  // This function sets nxt_move to 2 moves previous when backtracking is needed
  function void get_backtrack_move(input [6:0] move_number, input [7:0] move_array [23:0], output [7:0] nxt_move_out);

	nxt_move_out = move_array[move_number - 3];

  endfunction
 

  // This function translates the one hot encoded move to a change in x and a change in y on the board 
  function void translate_move(input [7:0] nxt_move, output [3:0] x_pos_change, output [3:0] y_pos_change);

	if(nxt_move == 8'b00000001) begin
		x_pos_change = 4'b0001;    // Right 1 
		y_pos_change = 4'b0010;    // Up 2
	end
	else if(nxt_move == 8'b00000010) begin
		x_pos_change = 4'b1111;    // Left 1
		y_pos_change = 4'b0010;	   // Up 2
	end
	else if(nxt_move == 8'b00000100) begin
		x_pos_change = 4'b1110;    // Left 2
		y_pos_change = 4'b0001;    // Up 1
	end
	else if(nxt_move == 8'b00001000) begin
		x_pos_change = 4'b1110;    // Left 2
		y_pos_change = 4'b1111;    // Down 1
	end
	else if(nxt_move == 8'b00010000) begin
		x_pos_change = 4'b1111;    // Left 1
		y_pos_change = 4'b1110;    // Down 2
	end
	else if(nxt_move == 8'b00100000) begin
		x_pos_change = 4'b0001;    // Right 1
		y_pos_change = 4'b1110;	   // Down 2
	end
	else if(nxt_move == 8'b01000000) begin
		x_pos_change = 4'b0010;	   // Right 2
		y_pos_change = 4'b1111;	   // Down 1
	end
	else if(nxt_move == 8'b10000000) begin
		x_pos_change = 4'b0010;	   // Right 2
		y_pos_change = 4'b0001;	   // Up 1
	end

  endfunction

  ///////////////////////////////
  //       Data registers     //
  /////////////////////////////


  // Flip flop to increment and decrement move counter
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		move_number <= 7'b0000001;
	end
	else if(increment_move) begin
		move_number <= move_number + 1;
	end
	else if(decrement_move) begin
		move_number <= move_number - 1;
	end
  end

  // Flip flop to x and y position of the knight
  always_ff @(posedge clk) begin
	if(set_start) begin
		x_pos <= {1'b0, x_start};  
		y_pos <= {1'b0, y_start};
	end
	else if(update_position) begin
		x_pos <= x_sum;
		y_pos <= y_sum;
	end
	else if(reverse_position) begin
		x_pos <= x_pos + reverse_x_pos;
		y_pos <= y_pos + reverse_y_pos;
	end
  end

  // Flip flop to update the board
  always_ff @(posedge clk) begin 
	if(initialize) begin
		for(int i = 0; i < 5; i=i+1) begin
			for(int j = 0; j < 5; j=j+1) begin
				board[i][j] <= 1'b0;
			end
		end
	end
	else if(reverse_board) begin
		board[x_pos][y_pos] <= 1'b0;
	end
	else if(update_board) begin
		board[x_pos][y_pos] <= 1'b1;
	end
  end

  // Flip flop to update the move array
  always_ff @(posedge clk) begin
	if(initialize) begin
		for(int k = 0; k < 24; ++k) begin
			move_array[k] <= 8'b00000000;
		end
	end
	else if(update_moves) begin
		move_array[move_number - 2] <= nxt_move;
	end
	else if(zero_move) begin
		move_array[move_number - 2] <= 8'b00000000;
	end
  end

  // Flip flip to update reverse_x and reverse_y
  always_ff @(posedge clk) begin
	if(find_reverse_pos) begin
		reverse_x_pos <= ~x_pos_change + 1; 	 	// In order to reverse the move from the square we are currently on,   	  							
		reverse_y_pos <= ~y_pos_change + 1;		// We have to negate the previous move
	end	
  end

  ///////////////////////////////
  // Infer the state machine  //
  /////////////////////////////

  // Flip flop to infer next state
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
	  state <= IDLE;
    else 
	  state <= nxt_state;
  end


  always_comb begin
	// Default outputs
	increment_move = 0;
	decrement_move = 0;
	set_start = 0;
	update_position = 0;
	reverse_position = 0;
	done = 0;
	initialize = 0;
	reverse_board = 0;
	update_board = 0;
	find_reverse_pos = 0;
	update_moves = 0;
	zero_move = 0;
	nxt_state = state;

	case(state) 
	  IDLE : begin
		if(go) begin
			initialize = 1; // Reset the board and move array
			set_start = 1;   // Set current position of knight to the starting position input
			nxt_state = INIT;
		end
	  end
	  INIT : begin
		update_board = 1;
		increment_move = 1;
		nxt_state = FINDMOVE;
	  end
	  FINDMOVE : begin
		if(move_number == 7'b0011010) begin   // If move number is at 26, then we have completed 25 moves and can transition to done
			nxt_state = DONE;
		end
		else begin
			find_move(.move_number(move_number - 2), .move_array(move_array), .nxt_move(nxt_move));
			translate_move(.nxt_move(nxt_move), .x_pos_change(x_pos_change), .y_pos_change(y_pos_change));
			nxt_state = CHECKVALID;
		end
	  end
	  CHECKVALID : begin

 		// Check validity of move by checking the knight does not move outside the board or visit a square it has already visited

		// First if the move is all zeros, this means we have iterated through all possible moves and need to backup
		if(nxt_move == 8'b00000000) begin
			nxt_state = BACKUP;
		end
		else if(x_sum > 4 || x_sum < 0 || y_sum > 4 || y_sum < 0 || board[x_sum][y_sum] != 1'b0) begin
				
			if(nxt_move == 8'b10000000) begin
				rotate_move(.nxt_move(nxt_move), .nxt_move_out(nxt_move));
				nxt_state = BACKUP;
			end
			else begin
				rotate_move(.nxt_move(nxt_move), .nxt_move_out(nxt_move));
				translate_move(.nxt_move(nxt_move), .x_pos_change(x_pos_change), .y_pos_change(y_pos_change));
				nxt_state = CHECKVALID;
			end
		end
		else begin
			update_position = 1;
			nxt_state = UPDATEBOARD;	
		end

	  end
	  UPDATEBOARD : begin
		update_moves = 1;
		update_board = 1;
		increment_move = 1;
		nxt_state = FINDMOVE;
	  end
	  BACKUP : begin
		zero_move = 1;		
		get_backtrack_move(.move_number(move_number), .move_array(move_array), .nxt_move_out(nxt_move));
		reverse_board = 1;
		translate_move(.nxt_move(nxt_move), .x_pos_change(x_pos_change), .y_pos_change(y_pos_change));
		decrement_move = 1;
		find_reverse_pos = 1; // Updates reverse_x and reverse_y
		nxt_state = INTER;
	  end
	  INTER : begin
		reverse_position = 1;
		nxt_state = FINDMOVE;
	  end
	  DONE : begin
		done = 1;
		nxt_state = IDLE;
	  end
	  default : nxt_state = IDLE;	 
	endcase
  end

endmodule



					


