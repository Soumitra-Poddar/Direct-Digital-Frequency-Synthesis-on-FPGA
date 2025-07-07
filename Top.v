`timescale 1ns / 1ps

module Top(
    input  clk, 
    input  resetn,
    output signed [15:0] Sine_out,
    output signed [16:0] Tri_out,
    output              PWM_1,
    output              PWM_2,
    output signed [3:0] PWM_3,
    output signed [3:0] PWM_4
);

    wire        result_valid;
    wire [15:0] scaled_sine;  // Final scaled sine output from DDS

    DDS_Module inst1 (
        .clk(clk),
        .resetn(resetn),
        .result_ready(1'b1),     // Always ready in this setup
        .sine_out(),             // Raw sine not used
        .result_out(scaled_sine),
        .result_valid(result_valid)
    );
    
    TriangularWave_Module inst2 (
        .clk(clk),
        .resetn(resetn),
        .Tri_out(Tri_out)
    );
    
    PWM_Module inst3 (
        .clk(clk),
        .resetn(resetn),
        .Sine_out(scaled_sine),   // Use scaled output
        .Tri_out(Tri_out),
        .PWM_1(PWM_1),
        .PWM_2(PWM_2),
        .PWM_3(PWM_3),
        .PWM_4(PWM_4)
    );

    assign Sine_out = scaled_sine;  // Expose for observation or waveform output

endmodule
