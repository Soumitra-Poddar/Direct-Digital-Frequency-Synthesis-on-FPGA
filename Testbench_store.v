`timescale 1ns / 1ps

module Testbench();
    reg  clk;
    reg  resetn;
    wire signed [15:0] Sine_out;
    wire signed [16:0] Tri_out;
    wire PWM_1, PWM_2;
    wire signed [3:0] PWM_3, PWM_4;

    Top uut (
        .clk(clk),
        .resetn(resetn),
        .Sine_out(Sine_out),
        .Tri_out(Tri_out),
        .PWM_1(PWM_1),
        .PWM_2(PWM_2),
        .PWM_3(PWM_3),
        .PWM_4(PWM_4)
    );

    always #10 clk = ~clk;

    initial begin 
        clk = 1'b0;
        resetn = 1'b0;
        #20 resetn = 1'b1;

        repeat (10000) @(posedge clk);
        $finish;
    end
endmodule
