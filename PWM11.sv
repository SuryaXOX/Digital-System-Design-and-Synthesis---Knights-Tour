module PWM11(clk, rst_n, duty, PWM_sig, PWM_sig_n);

input clk, rst_n;			// 50MHz clk, active low reset
input [10:0] duty;			// specifies duty cycle
output logic PWM_sig;		// PWM signla out (glitch free)
output PWM_sig_n;			// PWM signla out (glitch free)

logic [10:0] cnt;
logic pwm_cmp;

always_ff@(posedge clk, negedge rst_n)
	if(!rst_n)
		cnt <= 0;
	else
		cnt <= cnt + 1;
		
assign pwm_cmp = cnt<duty;

always_ff@(posedge clk, negedge rst_n)
	if(!rst_n)
		PWM_sig <= 0;
	else
		PWM_sig <= pwm_cmp;
	
assign PWM_sig_n = ~PWM_sig;

endmodule