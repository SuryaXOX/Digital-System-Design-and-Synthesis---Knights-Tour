module MtrDrv(lft_spd, rght_spd, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2, clk, rst_n);

input clk, rst_n;
input [10:0] lft_spd, rght_spd;
output lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;

logic [10:0] lft_add, rght_add;

assign lft_add = $signed(lft_spd) + 11'h400;
assign rght_add = $signed(rght_spd) + 11'h400;

PWM11 lftPWM_DUT(.duty(lft_add), .rst_n(rst_n), .clk(clk), .PWM_sig(lftPWM1), .PWM_sig_n(lftPWM2));
PWM11 rghtPWM_DUT(.duty(rght_add), .rst_n(rst_n), .clk(clk), .PWM_sig(rghtPWM1), .PWM_sig_n(rghtPWM2));

endmodule