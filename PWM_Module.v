`timescale 1ns / 1ps

module PWM_Module(
    input  clk,
    input  resetn,
    input  signed [15:0] Sine_out,
    input  signed [16:0] Tri_out,
    output reg PWM_unipolar,
    output reg signed [3:0] PWM_bipolar
);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            PWM_unipolar <= 1'b0;
            PWM_bipolar  <= 1'b0;
        end else begin
            PWM_unipolar <= (Sine_out >= Tri_out[15:0]) ? 1'b1 : 1'b0;
            PWM_bipolar  <= (Sine_out >= Tri_out[15:0]) ? 4'b0101 : 4'b1011;
        end
    end  
endmodule