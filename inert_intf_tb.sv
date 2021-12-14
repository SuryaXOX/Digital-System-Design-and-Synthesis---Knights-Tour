module inert_intf_tb();

  //////////////////////////////////////
  //             Inputs              //
  ////////////////////////////////////

  logic strt_cal, moving, lftIR, rghtIR, clk, rst_n;


  //////////////////////////////////////
  //             Outputs             //
  ////////////////////////////////////
 
  logic [11:0] heading;
  logic rdy, cal_done;
  
  //////////////////////////////////////
  //          Internal signals       //
  ////////////////////////////////////

  logic INT, SS_n, SCLK, MOSI_iSPI, MISO_iSPI, MOSI, MISO;


  ////////////////////////////////////////////////////////////
  // Instantiate inertial interface                        //
  //////////////////////////////////////////////////////////
  inert_intf iINR(.clk(clk), .rst_n(rst_n), .lftIR(lftIR), .rghtIR(rghtIR), .moving(moving), .heading(heading), .strt_cal(strt_cal), .cal_done(cal_done), .rdy(rdy), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .INT(INT));


  ////////////////////////////////////////////////////////////
  // Instantiate SPI_iNEMO2                                //
  //////////////////////////////////////////////////////////

  SPI_iNEMO2 iSPI2(.INT(INT), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));


  ////////////////////////////////////////////////////////////
  // Implement Test Cases                                  //
  //////////////////////////////////////////////////////////



  initial begin

	clk = 0;
	moving = 1;
	lftIR = 0;
	rghtIR = 0;

	rst_n = 0;

	@(posedge clk);	
	@(negedge clk);

	rst_n = 1;
	
	// Now we wait for the NEMO_setup signal in the ISP2 DUT to be asserted
	fork
	  begin: timeout1
	    repeat(2000000) @(negedge clk);
		$display("ERR: timed out");
		$stop();
	  end
	  begin
	    while (iSPI2.NEMO_setup !== 1) @(negedge clk);
        disable timeout1;
	  end
	join	


	// Assert strt_cal for one clock cycle
	strt_cal = 1;
	@(posedge clk);	
	@(negedge clk);
	strt_cal = 0;
	

	// Wait for cal_done to be asserted 
	fork
	  begin: timeout2
	    repeat(2000000) @(negedge clk);
		$display("ERR: timed out");
		$stop();
	  end
	  begin
	    while (!cal_done) @(negedge clk);
        disable timeout2;
	  end
	join	


	repeat(8000000) @(posedge clk);

	$display("YAHOO!!!!!!.. Test cases passed. Check waveform for correct functionality");
	$stop();

  end

  always 
  #5 clk = ~clk;
  
endmodule 