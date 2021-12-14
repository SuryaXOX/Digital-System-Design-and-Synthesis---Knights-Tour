/////////////////////////////////////////////
// 	Checks for Positive Acknowledge    //
/////////////////////////////////////////////
task ChkPosAck(input [31:0] timetowait);
  begin
      fork
	  // waiting for Positive Acknowledge
	  begin: timeout1
	        repeat(timetowait) @(negedge clk);
		$display("ERR: timed out waiting for Positive Acknowledge");
		$stop();
	  end
	  begin
	        while (resp !== 8'hA5) @(negedge clk);
                disable timeout1;
	  end
	  
	  join
   
  end
endtask

/////////////////////////////////////////////
// 	Checks if PWM's running fine       //
/////////////////////////////////////////////
task init_PWM_test;
  begin
    logic lft, lft_n, rght, rght_n;
   fork
     begin:period
      repeat(2048) @(posedge clk);
     end
     begin
       fork
        @(posedge lftPWM1) lft=1'b1;
        @(posedge lftPWM2) lft_n=1'b1;
        @(posedge rghtPWM1) rght=1'b1;
        @(posedge rghtPWM2) rght_n=1'b1;
       join
       if(lft & lft_n & rght & rght_n) $display("PWM is running");
       else begin
         $display ("PWM is not running properly"); 
         $stop();
       end
     end
   join
  end
endtask


/////////////////////////////////////////////
// 	Checks if NEMO_setup is asserted   //
/////////////////////////////////////////////
task init_NEMO_setup;
  begin

	fork  
	  // waiting for NEMO_setup to get asserted
	  begin: timeout2
	        repeat(2000000) @(posedge clk);
		$display("ERR: timed out waiting for NEMO_setup to get asserted");
		$stop();
	  end
	  begin
	        @(posedge iPHYS.iNEMO.NEMO_setup);
	 $display("SUCCESS : NEMO_setupis asserted");
          disable timeout2;
	  end
	join	

  end
endtask


/////////////////////////////////////////////
// 	Task for Calibration   		   //
/////////////////////////////////////////////
task calibrate;
  begin
	SendCmd(16'h0000); // send calibrate command
        fork
        // waiting for cal_done
        begin: timeout1
            repeat(1000000) @(posedge clk);
            $display("ERR: timed out waiting for cal_done to assert");
            $stop();
        end
        // waiting for cal_done
        begin
            @(posedge iDUT.iNEMO.cal_done);
	          $display("SUCCESS : Cal done is asserted");
            disable timeout1;
        end
        // waiting for resp_rdy
        begin: timeout2
            repeat(1000000) @(posedge clk);
            $display("ERR: timed out waiting for resp_rdy to assert");
            $stop();
        end
        // waiting for resp_rdy
        begin
            @(posedge resp_rdy);
            $display("SUCCESS : resp_rdy is asserted");
            disable timeout2;
        end
    join


  end
endtask



/////////////////////////////////////////////
// 	Task for Sending Command	   //
/////////////////////////////////////////////
task SendCmd(input [15:0] cmd2send);
  begin
	  cmd = cmd2send;
	  send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;

    // waiting for cmd_sent
    fork
        begin: timeout
            repeat(100000) @(posedge clk);
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
  end
endtask


/////////////////////////////////////////////////////////////////////
// Task that waits for signal rise for the specfied timeout period //
/////////////////////////////////////////////////////////////////////
task automatic wait4sig(ref sig, input int clks2wait);
  begin
	fork
	  begin: timeout
	    repeat(clks2wait) @(posedge clk);
	    $display("ERR: timed out waiting for sig in wait4sig");
	    $stop();
	  end
	  begin
	    @(posedge sig); // signal of interest asserted
	    disable timeout;
	  end
	join
  end
endtask



