`timescale 1ns / 1ps

module Top_tb;

    reg clk;
    reg resetn;

    wire signed [15:0] Sine_out;
    wire signed [16:0] Tri_out;
    wire PWM_1, PWM_2;
    wire signed [3:0] PWM_3, PWM_4;

    integer file;
    integer cycle_count;

    // Instantiate DUT
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

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock (10ns period)
    end

    // Test Sequence
    initial begin
        file = $fopen("top_output.txt", "w");
        if (file == 0) begin
            $display("Failed to open output file!");
            $finish;
        end

        resetn = 0;
        #100;
        resetn = 1;

        cycle_count = 0;

        // Run for 10,000 cycles
        while (cycle_count < 10000) begin
            @(posedge clk);
            $fwrite(file, "%0d,%0d,%0b,%0b,%0d,%0d\n", Sine_out, Tri_out, PWM_1, PWM_2, PWM_3, PWM_4);
            cycle_count = cycle_count + 1;
        end

        $fclose(file);
        $display("Simulation complete. Output written to top_output.txt");
        $finish;
    end

endmodule
