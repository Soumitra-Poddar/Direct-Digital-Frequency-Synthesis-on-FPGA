`timescale 1ns / 1ps

module Top(
    input  clk, 
    input  resetn,
    output signed [15:0] Sine_out,
    output signed [16:0] Tri_out,
    output PWM_1, PWM_2,
    output signed [3:0] PWM_3
);

    DDS_Module inst1 (
        .clk(clk),
        .resetn(resetn),
        .Sine_out(Sine_out)
    );
    
    TriangularWave_Module inst2 (
        .clk(clk),
        .resetn(resetn),
        .Tri_out(Tri_out)
    );
    
    PWM_Module inst3 (
        .clk(clk),
        .resetn(resetn),
        .Sine_out(Sine_out),
        .Tri_out(Tri_out),
        .PWM_1(PWM_1),
        .PWM_2(PWM_2),
        .PWM_3(PWM_3)
    );
    
endmodule