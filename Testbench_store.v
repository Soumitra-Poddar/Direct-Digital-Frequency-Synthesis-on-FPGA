`timescale 1ns / 1ps

module Testbench_store();
    reg clk;
    reg resetn;
    wire signed [15:0] Sine_out;
    wire signed [16:0] Tri_out;
    wire PWM_unipolar;
    wire signed [3:0] PWM_bipolar;

    integer outfile;

    Top uut (
        .clk(clk), 
        .resetn(resetn), 
        .Sine_out(Sine_out), 
        .Tri_out(Tri_out), 
        .PWM_unipolar(PWM_unipolar),
        .PWM_bipolar(PWM_bipolar)
    );

    always #10 clk = ~clk;

    initial begin
        clk = 0;
        resetn = 0;

        outfile = $fopen("output_data.txt", "w");
        if (outfile == 0) begin
            $display("Error opening file!");
            $finish;
        end

        #20 resetn = 1'b1;

        repeat (10000) begin
            @(posedge clk);
            $fwrite(outfile, "%0dns: Sine_out=%0d, Tri_out=%0d, PWM_unipolar=%b, PWM_bipolar=%b\n",
                    $time, Sine_out, Tri_out, PWM_unipolar, PWM_bipolar);
        end

        $fclose(outfile);
        $display("Simulation finished. Output saved to output_data.txt");
        $stop;
    end
endmodule