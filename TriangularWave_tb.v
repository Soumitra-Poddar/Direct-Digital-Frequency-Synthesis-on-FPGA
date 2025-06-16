`timescale 1ns / 1ps

module TriangularWave_tb();
    reg  clk;
    reg  resetn;
    wire signed [16:0] Tri_out;
    
    TriangularWave_Module uut2 (
        .clk(clk),
        .resetn(resetn),
        .Tri_out(Tri_out)
        );
        
        always #10 clk = ~clk;
    
    initial begin 
        clk    = 1'b0;
        resetn = 1'b0;
        end 
        
        initial
        #10 resetn = 1'b1;
        
endmodule