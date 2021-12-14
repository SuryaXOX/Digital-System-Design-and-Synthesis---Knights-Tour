
//////////////////////////////////////////////////
// 	Checks if switch to Wrapper from SM occurs //
//////////////////////////////////////////////////
task switch_SM_wrapper();
  initial begin
   

  end
endtask


// checks for moving east one square
task east_one;
	begin
		SendCmd(16'h2bf1);
		CheckPosAck(32'd80000000);	// making sure the move finishes
		//making sure the robot has stopped
		assert(frwrd===0) $display("YAY move east one square works!");
		else begin 
			$error("ERR does not work because frwrd is not 0");
			$stop();
		end
		// check xx and yy
		assert(iPHYS.xx<15'h4000 && iPHYS.xx>15'h3000) $display("YAY xx in range!");
		else begin
			$error("ERR xx not in range, it is %h", iPHYS.xx);
			$stop();
		end
		assert(iPHYS.yy<15'h3000 && iPHYS.yy>15'h2000) $display("YAY yy in range!");
		else begin
			$error("ERR yy not in range, it is %h", iPHYS.xx);
			$stop();
		end
	end
endtask


//////////////////////////////////////////////////
// 	Checks if heading updates properly      //
//////////////////////////////////////////////////
task ChkHeading();
repeat(1000000) @(posedge clk);
   begin
	logic signed [11:0] EAST_TMP;
	logic signed [11:0] WEST_TMP;
	logic signed [11:0] NORTH_TMP;
	logic signed [11:0] SOUTH_TMP;

	logic signed [11:0] EAST;
	logic signed [11:0] WEST;
	logic signed [11:0] NORTH;
	logic signed [11:0] SOUTH;

    if(iDUT.iCMD.cmd_rdy) begin
		    // Checking East
		    if(iRMT.cmd == 16'h2bf1) begin
						EAST_TMP = iDUT.iCMD.error;
						repeat(1000000) @(posedge clk);
						EAST = iDUT.iCMD.error;
						
						if(EAST < EAST_TMP) begin
									$display("Heading gets updated correctly(EAST)");
								    end
						else begin
							$display(" ERR : Heading does not get updated correctly");
							$stop();
						end
						
					    end
		    // Checking North
		    else if(iRMT.cmd == 16'h2001) begin
						NORTH_TMP = iDUT.iCMD.error;
						repeat(1000000) @(posedge clk);
						NORTH = iDUT.iCMD.error;
						
						if(NORTH < NORTH_TMP) begin
									$display("Heading gets updated correctly(NORTH)");
								    end
						else begin
							$display(" ERR : Heading does not get updated correctly");
							$stop();
						end
					    end
		    // Checking South
		    else if(iRMT.cmd == 16'h27f1) begin
						SOUTH_TMP = iDUT.iCMD.error;
						repeat(1000000) @(posedge clk);
						SOUTH = iDUT.iCMD.error;
						
						if(SOUTH < SOUTH_TMP) begin
									$display("Heading gets updated correctly(SOUTH)");
								    end
						else begin
							$display(" ERR : Heading does not get updated correctly");
							$stop();
						end
					    end
		    // Checking West
		    else if(iRMT.cmd == 16'h23f1) begin
						WEST_TMP = iDUT.iCMD.error;
						repeat(1000000) @(posedge clk);
						WEST = iDUT.iCMD.error;
						
						if(WEST < WEST_TMP) begin
									$display("Heading gets updated correctly(WEST)");
								    end
						else begin
							$display(" ERR : Heading does not get updated correctly");
							$stop();
						end
					    end
		end
      

  end
endtask

