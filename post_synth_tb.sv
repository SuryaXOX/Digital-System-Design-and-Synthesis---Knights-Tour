`timescale 1ns/1ps
module post_synth_tb();
  

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
    cntrIR = 0;
    cal_done = 0;
    @(posedge clk);
    @(negedge clk) 
    RST_n = 1'b1;

    // sending the command, and checking if it indeed has been sent
    send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;

    // waiting for cmd_sent
    fork
        begin: timeout
            repeat(2000000) @(posedge clk);
            $display("ERR: timed out waiting for cmd_sent to assert");
            $stop();
        end
        // waiting for cmd_sent
        begin
            @(posedge cmd_sent);
	 $display("SUCCESS : Command sent!!");
            disable timeout;
        end
    join

  // checking for positive acknowledgement
    fork
	  // waiting for Positive Acknowledge
	  begin: timeout1
	        repeat(10000000) @(posedge clk);
		$display("ERR: timed out waiting for Positive Acknowledge");
		$stop();
	  end
	  begin
	        while (resp !== 8'hA5) @(posedge clk);
	 		$display("SUCCESS : Received Positive acknowledge for %h!!", cmd);
                	disable timeout1;
	  end
    begin
      @(posedge resp_rdy) $display ("response is ready");
      $display(resp);
    end
    join

	$display("SUCCESS : All Tests Passed");
	$stop();
  end

  always
    #5 clk = ~clk;
  
endmodule
