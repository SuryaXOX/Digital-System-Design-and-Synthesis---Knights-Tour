module KnightsTour_tb();
  

  /////////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk, RST_n;
  reg [15:0] cmd;
  reg send_cmd;
  
  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  wire SS_n,SCLK,MOSI,MISO,INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire TX_RX, RX_TX;
  logic cmd_sent;
  logic resp_rdy;
  logic [7:0] resp;
  wire IR_en;
  wire lftIR_n,rghtIR_n,cntrIR_n;
  logic lftIR,rghtIR,cntrIR;
  logic trmt;
  logic cal_done;

  logic test_pass;
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
                   .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
				   .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
				   .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
				   .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
				   .cntrIR_n(cntrIR_n));
				  
  /////////////////////////////////////////////////////
  // Instantiate RemoteComm to send commands to DUT //
  ///////////////////////////////////////////////////
  //This is my remoteComm.  It is possible yours has a slight variation
     //in port names
  RemoteComm iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
             .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
				   
  //////////////////////////////////////////////////////
  // Instantiate model of Knight Physics (and board) //
  ////////////////////////////////////////////////////
  KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                      .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 
				   
  initial begin
      // initializing signals
    clk = 1'b0;
    RST_n = 1'b0;
    send_cmd = 1'b0;
    lftIR = 1'b0;
    cmd = 16'h0000;
    rghtIR = 1'b0;
    trmt = 1'b0;
    test_pass = 1'b0;
    @(posedge clk);
    @(negedge clk) 
    RST_n = 1'b1;
    
    init_NEMO_setup;
    calibrate;
    SendCmd(16'h0000);
    ChkPosAck(32'd2000000);

    init_PWM_test;

    test_pass = 1'b1;
    @(posedge clk);
    test_pass = 1'b0;

    east_one;

	$display("SUCCESS : All Tests Passed");
	$stop();
  end
  
  always
    #5 clk = ~clk;
  
  `include "simple_tasks_tb.sv";
  `include ""
endmodule
