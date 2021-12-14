module inert_intf(clk,rst_n,lftIR,rghtIR,moving,heading,strt_cal,cal_done,rdy,SS_n,SCLK,
                  MOSI,MISO,INT);
				  
  parameter FAST_SIM = 1;		// used to accelerate simulation
 
  input clk, rst_n;
  input MISO;					// SPI input from inertial sensor
  input INT;					// goes high when measurement ready
  input strt_cal;				// from comand config.  Indicates we should start calibration
  input logic lftIR;
  input logic rghtIR;
  input logic moving; 

  output signed [11:0] heading;	// fusion corrected angles
  output cal_done;						// indicates calibration is done
  output rdy;						// goes high for 1 clock when new outputs available
  output SS_n,SCLK,MOSI;				// SPI outputs


  //////////////////////////////////////////////////////////////
  // Declare any needed internal signals that connect blocks //
  ////////////////////////////////////////////////////////////
  wire signed [15:0] yaw_rt;	// feeds inertial_integrator
  logic INT_FF1;
  logic INT_FF2;
  logic [15:0] timer;
  logic [15:0] holding;
  logic [15:0] inert_data;
  logic done;
  logic vld_f;


  //////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
  logic C_Y_L;
  logic C_Y_H;
  logic wrt;
  logic vld;
  logic [15:0] cmd;


  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////

   // Double flop the INT signal
   always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		INT_FF1 <= 0;
	end
	else begin
		INT_FF1 <= INT;
	end
   end

   always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		INT_FF2 <= 0;
	end
	else begin
		INT_FF2 <= INT_FF1;
	end
   end

  // Create timer 
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		timer <= 16'h0000;
	end
	else begin
		timer <= timer + 1;
	end
   end

  // Create holding register to store yaw_L and yaw_H
  always_ff @(posedge clk) begin
	if(C_Y_L) begin
		holding[7:0] <= inert_data[7:0];
	end
  end

  always_ff @(posedge clk) begin
	if(C_Y_H) begin
		holding[15:8] <= inert_data[7:0];
	end
  end  


 always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		vld_f <= 0;
	end
	else begin
		vld_f <= vld;
	end
 end
  // Holding register feeds into yaw_rt
  assign yaw_rt = holding;  


  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum reg [2:0] {INIT1, INIT2, INIT3, WAIT, YAW_L, WRITE_YAW_L, YAW_H, VLD} state_t;
  state_t state, nxt_state;
  
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),
                 .wrt(wrt),.done(done),.rd_data(inert_data),.wrt_data(cmd));
				  
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and acceleration info and produces ptch,roll, & yaw readings //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal), .cal_done(cal_done),
                                       .vld(vld_f), .yaw_rt(yaw_rt), .lftIR(lftIR), .rghtIR(rghtIR), .moving(moving), .rdy(rdy), .heading(heading));
	
  ///////////////////////////////
  // Infer the state machine  //
  /////////////////////////////

  // Flip flop to infer next state
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
	  state <= INIT1;
    else 
	  state <= nxt_state;
  end

  always_comb begin
      	// Default outputs
	C_Y_L = 0;
	C_Y_H = 0;
	wrt = 0;
	cmd = 16'h0000;
	vld = 0;
	nxt_state = state;

	case(state) 
	  INIT1 : begin
		cmd = 16'h0D02;
		if(&timer) begin
			wrt = 1;
			nxt_state = INIT2;
		end
	  end
	  INIT2 : begin
		cmd = 16'h1160;
		if(done) begin
			wrt = 1;
			nxt_state = INIT3;
		end
	  end
	  INIT3 : begin
		cmd = 16'h1440;
		if(done) begin
			wrt = 1;
			nxt_state = WAIT;	
		end
	  end
	  WAIT : begin
		cmd = 16'hA600;
		if(INT_FF2) begin
			wrt = 1;
			nxt_state = YAW_L;
		end
	  end
	  YAW_L : begin
		cmd = 16'hA700;
		if(done) begin
			cmd = 16'hA700;
			C_Y_L = 1;
			wrt = 1;
			nxt_state = YAW_H;
		end
	  end
	  YAW_H : begin
		if(done) begin
			C_Y_H = 1;
			vld = 1;
			nxt_state = WAIT;
		end
	  end
	  default : nxt_state = INIT1;	 
	endcase
  end
  
endmodule
	  