module charge(clk, rst_n, go, piezo, piezo_n);



  //////////////////////////////////////
  //        Inputs and Outputs       //
  ////////////////////////////////////

  parameter FAST_SIM = 1;		// used to accelerate simulation

  input logic clk;
  input logic rst_n;
  input logic go;
  
  output logic piezo;
  output logic piezo_n;

  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum reg [2:0] {IDLE, G6, C7, E7, G7, E7_2, G7_2} state_t;
  state_t state, nxt_state;


  //////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
  logic reset_freq;
  logic reset_dur;
  
  // Note that piezo and piezo_n are also outputs of the state machine 

  //////////////////////////////////////
  //       Internal signals          //
  ////////////////////////////////////

  logic [14:0] freq;                 // 15 bit Counter to keep track of the frequency of each note
  logic [24:0] duration;             // 25 bit Counter to keep track of the duration of each note
  logic G6_high;
  logic G6_reset;
  logic G6_dur;
  logic C7_high;
  logic C7_reset;
  logic C7_dur;
  logic E7_high;
  logic E7_reset;
  logic E7_dur;
  logic G7_high;
  logic G7_reset;
  logic G7_dur;
  logic E7_dur_2;
  logic G7_dur_2;
  logic [4:0] dur_incr;
  logic drive_piezo;
  logic hold;

  //////////////////////////////////////
  //        Internal logic           //
  ////////////////////////////////////

  generate if (FAST_SIM)
    assign dur_incr = 5'h10;
  else
    assign dur_incr = 5'h01;
  endgenerate

  // Frequency counter flip flop
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		freq <= 15'h0000;
	end
	else if(reset_freq) begin
		freq <= 15'h0000;
	end
	else begin
		freq <= freq + 1;
	end
  end

  // Duration counter flip flop
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		duration <= 25'h0000000;
	end
	else if(reset_dur) begin
		duration <= 25'h0000000;
	end
	else begin
		duration <= duration + dur_incr;
	end
  end


  //////////////////////////////////////
  //            G6 Note              //
  ////////////////////////////////////

  // G6 has a frequency of 1568 so one period is 31,887 clock cycles
  // With a 50% duty cycle, it should be low for 15,944 clock cycles
  // and high for 15,943 clock cycles
  assign G6_high = freq > 15'b011111001001000 ? 1 : 0;
 
  // Once the freq counter reaches 31,877 clock cycles, we reset the counter
  assign G6_reset = freq > 15'b111110010000101 ? 1 : 0;
 
  // Once we reach 2^23 clock cylces we have reached the duration for the G6 note so 
  // we transition to playing the G7 note
  assign G6_dur = duration > 25'h0800000 ? 1 : 0;

  //////////////////////////////////////
  //            C7 Note              //
  ////////////////////////////////////

  // C7 has a frequency of 2093 so one period is 23,889 clock cycles
  // With a 50% duty cycle, it should be low for 11,944 clock cycles
  // and high for 11,944 clock cycles
  assign C7_high = freq > 15'b010111010101000 ? 1 : 0;
 
  // Once the freq counter reaches 23,889 clock cycles, we reset the counter
  assign C7_reset = freq > 15'b101110101010001 ? 1 : 0;
 
  // Once we reach 2^23 clock cylces we have reached the duration for the C7 note so 
  // we transition to playing the E7 note
  assign C7_dur = duration > 25'h0800000 ? 1 : 0;

  //////////////////////////////////////
  //            E7 Note              //
  ////////////////////////////////////

  // E7 has a frequency of 2637 so one period is 18,961 clock cycles
  // With a 50% duty cycle, it should be low for 9,480 clock cycles
  // and high for 9,481 clock cycles
  assign E7_high = freq > 15'b010010100001000 ? 1 : 0;
 
  // Once the freq counter reaches 18,961 clock cycles, we reset the counter
  assign E7_reset = freq > 15'b100101000010001 ? 1 : 0;
 
  // Once we reach 2^23 clock cylces we have reached the duration for the E7 note so 
  // we transition to playing the G7 note
  assign E7_dur = duration > 25'h0800000 ? 1 : 0;

  // The second time once we reach 2^22 clock cylces we have reached the duration
  // for the second E7 note so we transition to playing the second G7 note
  assign E7_dur_2 = duration > 25'h0400000 ? 1 : 0;

  //////////////////////////////////////
  //            G7 Note              //
  ////////////////////////////////////

  // G7 has a frequency of 3136 so one period is 15,944 clock cycles
  // With a 50% duty cycle, it should be low for 7,972 clock cycles
  // and high for 7,972 clock cycles
  assign G7_high = freq > 15'b001111100100100 ? 1 : 0;
 
  // Once the freq counter reaches 15,944 clock cycles, we reset the counter
  assign G7_reset = freq > 15'b011111001001000 ? 1 : 0;
 
  // Once we reach 2^23 + 2^22 clock cylces we have reached the duration for the G7 note so 
  // we transition to playing the E7 note again
  assign G7_dur = duration > 25'h0C00000 ? 1 : 0;

  // The second time once we reach 2^24 clock cylces we have reached the duration
  // for the second G7 note so we are done playing all the notes
  assign G7_dur_2 = duration > 25'h1000000 ? 1 : 0;



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
	reset_freq = 0;
	reset_dur = 0;
	nxt_state = state;
	hold = 0;
	drive_piezo = 0;

	case(state) 
	  IDLE : begin
	  	hold = 1;
		if(go) begin
			reset_freq = 1;
			reset_dur = 1;
			nxt_state = G6;
		end
	  end
	  G6 : begin
		if(G6_dur) begin
			reset_dur = 1;
			nxt_state = C7;
		end
		else if(G6_reset) begin
			reset_freq = 1;
		end
		else if(G6_high) begin
			drive_piezo = 1;
		end
	  end
	  C7 : begin
		if(C7_dur) begin
			reset_dur = 1;
			nxt_state = E7;
		end
		else if(C7_reset) begin
			reset_freq = 1;
		end
		else if(C7_high) begin
			drive_piezo = 1;
		end
	  end
	  E7 : begin
		if(E7_dur) begin
			reset_dur = 1;
			nxt_state = G7;
		end
		else if(E7_reset) begin
			reset_freq = 1;
		end
		else if(E7_high) begin
			drive_piezo = 1;
		end
	  end
	  G7 : begin
		if(G7_dur) begin
			reset_dur = 1;
			nxt_state = E7_2;
		end
		else if(G7_reset) begin
			reset_freq = 1;
		end
		else if(G7_high) begin
			drive_piezo = 1;
		end
	  end
	  E7_2 : begin
		if(E7_dur_2) begin
			reset_dur = 1;
			nxt_state = G7_2;
		end
		else if(E7_reset) begin
			reset_freq = 1;
		end
		else if(E7_high) begin
			drive_piezo = 1;
		end
	  end
	  G7_2 : begin
		if(G7_dur_2) begin
			reset_dur = 1;
			nxt_state = IDLE;
		end
		else if(G7_reset) begin
			reset_freq = 1;
		end
		else if(G7_high) begin
			drive_piezo = 1;
		end
	  end
	  default : nxt_state = IDLE;	 
	endcase
  end

  // Set reset flop to drive piezo and piezo_n
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		piezo <= 0;
		piezo_n <= 0;
	end
	else if(hold) begin
		piezo <= 0;
		piezo_n <= 0;
	end
	else if(drive_piezo) begin
		piezo <= 1;
		piezo_n <= 0;
	end
	else begin
		piezo <= 0;
		piezo_n <= 1;
	end
  end


endmodule