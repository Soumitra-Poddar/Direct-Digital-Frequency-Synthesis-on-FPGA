`timescale 1ns / 1ps

module Multichannel_DDS_tb();

    // ========================================
    // Testbench Signals
    // ========================================
    reg clk;
    reg resetn;
    reg [8:0] addr;
    reg [23:0] data;
    reg wr_en;
    reg sync;
    
    // DDS outputs
    wire signed [15:0] sine_out_ch0;
    wire [4:0] current_channel;
    wire channel_valid;
    
    // Test control
    integer test_number = 0;
    
    // ========================================
    // DUT Instantiation
    // ========================================
    Multichannel_DDS uut (
        .clk(clk),
        .resetn(resetn),
        .addr(addr),
        .data(data),
        .wr_en(wr_en),
        .sync(sync),
        .sine_out_ch0(sine_out_ch0),
        .current_channel(current_channel),
        .channel_valid(channel_valid)
    );
    
    // ========================================
    // Clock Generation
    // ========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // ========================================
    // Test Tasks
    // ========================================

    // Task to write to a register
    task write_register(input [8:0] reg_addr, input [23:0] reg_data);
        begin
            @(posedge clk);
            addr = reg_addr;
            data = reg_data;
            wr_en = 1;
            @(posedge clk);
            wr_en = 0;
            addr = 9'h000;
            data = 24'h000000;
        end
    endtask

    // Task to wait for N cycles
    task wait_cycles(input integer cycles);
        begin
            repeat(cycles) @(posedge clk);
        end
    endtask

    // Task to reset the system
    task system_reset();
        begin
            resetn = 0;
            addr = 0;
            data = 0;
            wr_en = 0;
            sync = 0;
            wait_cycles(10);
            resetn = 1;
            wait_cycles(5);
        end
    endtask

    // Task to monitor output channels
    task monitor_channels(input integer duration, input [127:0] test_name);
        integer i;
        begin
            $display("=== %0s - Monitoring for %0d cycles ===", test_name, duration);
            for (i = 0; i < duration; i = i + 1) begin
                @(posedge clk);
                if (channel_valid) begin
                    $display("Time:%0t Channel:%0d Output:%0d", $time, current_channel, sine_out_ch0);
                end
            end
            $display("=== %0s Complete ===\n", test_name);
        end
    endtask

    // ========================================
    // Main Test Sequence
    // ========================================
    initial begin
        $display("Starting Multichannel DDS Testbench");

        // TEST 1: Reset and Init
        test_number = 1;
        $display("\n--- TEST %0d: Reset and Initialization ---", test_number);
        system_reset();
        wait_cycles(10);
        if (!channel_valid)
            $display("PASS: DDS correctly disabled after reset");
        else
            $display("FAIL: DDS should be disabled after reset");

        // TEST 2: MODE1 - PCW
        test_number = 2;
        $display("\n--- TEST %0d: MODE1 PCW with Phase Shifts ---", test_number);
        write_register(9'h000, 24'd6711);
        write_register(9'h100, 24'd0);
        write_register(9'h101, 24'd4194304);
        write_register(9'h102, 24'd8388608);
        write_register(9'h103, 24'd12582912);
        write_register(9'h1FF, 24'h000081);  // Enable=1, Mode=01
        monitor_channels(150, "MODE1 PCW Test");

        // TEST 3: MODE0 - 6x6 Configuration
        test_number = 3;
        $display("\n--- TEST %0d: MODE0 6x6 Configuration ---", test_number);
        write_register(9'h1FF, 24'h000000); wait_cycles(5);
        write_register(9'h000, 24'd5000);
        write_register(9'h001, 24'd6000);
        write_register(9'h002, 24'd7000);
        write_register(9'h003, 24'd8000);
        write_register(9'h004, 24'd9000);
        write_register(9'h005, 24'd10000);
        write_register(9'h100, 24'd0);
        write_register(9'h101, 24'd2097152);
        write_register(9'h102, 24'd4194304);
        write_register(9'h103, 24'd6291456);
        write_register(9'h104, 24'd8388608);
        write_register(9'h105, 24'd10485760);
        write_register(9'h1FF, 24'h000080);  // Mode=00
        monitor_channels(200, "MODE0 6x6 Test");

        // TEST 4: MODE2 - LFM
        test_number = 4;
        $display("\n--- TEST %0d: MODE2 LFM Test ---", test_number);
        write_register(9'h1FF, 24'h000000); wait_cycles(5);
        write_register(9'h000, 24'd5000);
        write_register(9'h001, 24'd5500);
        write_register(9'h002, 24'd6000);
        write_register(9'h003, 24'd6500);
        write_register(9'h004, 24'd7000);
        write_register(9'h005, 24'd7500);
        write_register(9'h006, 24'd8000);
        write_register(9'h007, 24'd8500);
        write_register(9'h100, 24'd0);
        write_register(9'h101, 24'd4194304);
        write_register(9'h1FF, 24'h000082);  // Mode=10
        monitor_channels(300, "MODE2 LFM Test");

        // TEST 5: MODE3 - CFS
        test_number = 5;
        $display("\n--- TEST %0d: MODE3 CFS Test ---", test_number);
        write_register(9'h1FF, 24'h000000); wait_cycles(5);
        write_register(9'h000, 24'd4000);
        write_register(9'h001, 24'd5000);
        write_register(9'h002, 24'd6000);
        write_register(9'h003, 24'd7000);
        write_register(9'h004, 24'd8000);
        write_register(9'h005, 24'd9000);
        write_register(9'h006, 24'd10000);
        write_register(9'h1FF, 24'h000083);  // Mode=11
        monitor_channels(250, "MODE3 CFS Test");

        // TEST 6: Sync Pulse Test
        test_number = 6;
        $display("\n--- TEST %0d: Sync Signal Test ---", test_number);
        write_register(9'h1FF, 24'h000081);  // Back to MODE1
        wait_cycles(50);
        $display("Applying sync pulse...");
        @(posedge clk); sync = 1;
        @(posedge clk); sync = 0;
        monitor_channels(100, "Sync Test");

        // TEST 7: Register Write Test
        test_number = 7;
        $display("\n--- TEST %0d: Register Write Verification ---", test_number);
        write_register(9'h0FF, 24'hABCDEF);
        write_register(9'h11F, 24'h123456);
        write_register(9'h1FF, 24'h000080);
        $display("Register write test completed");

        wait_cycles(50);
        $display("\n=== ALL TESTS COMPLETED ===");
        $display("Total test cases executed: %0d", test_number);
        $finish;
    end

    // ========================================
    // Timeout Protection
    // ========================================
    initial begin
        #500000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

    // ========================================
    // Waveform Dump
    // ========================================
    initial begin
        $dumpfile("multichannel_dds_tb.vcd");
        $dumpvars(0, Multichannel_DDS_tb);
    end

endmodule
