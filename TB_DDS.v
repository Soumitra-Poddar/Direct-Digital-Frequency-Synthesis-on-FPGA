`timescale 1ns / 1ps

module TB_DDS();

    reg clk = 0;
    reg resetn = 0;
    reg result_ready = 1;

    wire [15:0] sine_out;
    wire [15:0] result_out;
    wire result_valid;

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Instantiate the DUT
    DDS_Module uut (
        .clk(clk),
        .resetn(resetn),
        .result_ready(result_ready),
        .sine_out(sine_out),
        .result_out(result_out),
        .result_valid(result_valid)
    );

    // Apply reset and observe behavior
    initial begin
        $display("Starting DDS simulation...");
        $dumpfile("DDS.vcd");
        $dumpvars(0, TB_DDS);

        resetn = 0;
        #100;
        resetn = 1;

        // Run simulation for a while
        #10000000;

       $finish;
    end

    // Optional: simulate toggling result_ready
    always @(posedge clk) begin
        if ($time > 1000 && $time < 2000)
            result_ready <= 0;
        else
            result_ready <= 1;
    end

endmodule
