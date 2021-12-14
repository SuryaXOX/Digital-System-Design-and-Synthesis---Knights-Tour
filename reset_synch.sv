module reset_synch(RST_n, clk, rst_n);

input RST_n;
input clk;
output reg rst_n;

reg w1 = 0; 

always @(negedge clk) begin
  if(!RST_n) begin 
     w1 <= 0;
     rst_n <= 0;    
    
 end
  else begin
    w1 <= 1'b1;
    rst_n <= w1; 
   end
end

endmodule