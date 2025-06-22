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
    
    // Task to write a register
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
    
    // Task to wait for specific number of clock cycles
    task wait_cycles(input integer cycles);
        begin
            repeat(cycles) @(posedge clk);
        end
    endtask
    
    // Task to initialize system
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
    
    // Task to monitor channels for a specific duration
    task monitor_channels(input integer duration, input string test_name);
        integer i;
        begin
            $display("=== %s - Monitoring for %0d cycles ===", test_name, duration);
            for (i = 0; i < duration; i++) begin
                @(posedge clk);
                if (channel_valid) begin
                    $display("Time:%0t Channel:%0d Output:%0d", $time, current_channel, sine_out_ch0);
                end
            end
            $display("=== %s Complete ===\n", test_name);
        end
    endtask
    
    // ========================================
    // Main Test Sequence
    // ========================================
    initial begin
        $display("Starting Multichannel DDS Testbench");
        
        // ========================================
        // TEST 1: Basic Reset and Initialization
        // ========================================
        test_number = 1;
        $display("\n--- TEST %0d: Reset and Initialization ---", test_number);
        system_reset();
        
        // Check if DDS is initially disabled
        wait_cycles(10);
        if (!channel_valid) begin
            $display("PASS: DDS correctly disabled after reset");
        end else begin
            $display("FAIL: DDS should be disabled after reset");
        end
        
        // ========================================
        // TEST 2: MODE1 - PCW with 4 Phase Shifts
        // ========================================
        test_number = 2;
        $display("\n--- TEST %0d: MODE1 PCW with Phase Shifts ---", test_number);
        
        // Configure frequency register
        write_register(9'h000, 24'd6711);  // Base frequency
        
        // Configure 4 phase registers with different phase shifts
        write_register(9'h100, 24'd0);       // 0° phase shift
        write_register(9'h101, 24'd4194304); // ~90° phase shift (2^22)
        write_register(9'h102, 24'd8388608); // ~180° phase shift (2^23)
        write_register(9'h103, 24'd12582912);// ~270° phase shift (3*2^22)
        
        // Enable DDS in MODE1 (PCW)
        write_register(9'h1FF, 24'h000081);  // Enable=1, Mode=01
        
        // Monitor channels
        monitor_channels(150, "MODE1 PCW Test");
        
        // ========================================
        // TEST 3: MODE0 - 6x6 Configuration
        // ========================================
        test_number = 3;
        $display("\n--- TEST %0d: MODE0 6x6 Configuration ---", test_number);
        
        // Disable DDS first
        write_register(9'h1FF, 24'h000000);  // Disable DDS
        wait_cycles(5);
        
        // Configure 6 different frequencies
        write_register(9'h000, 24'd5000);   // Freq 0
        write_register(9'h001, 24'd6000);   // Freq 1  
        write_register(9'h002, 24'd7000);   // Freq 2
        write_register(9'h003, 24'd8000);   // Freq 3
        write_register(9'h004, 24'd9000);   // Freq 4
        write_register(9'h005, 24'd10000);  // Freq 5
        
        // Configure 6 phase shifts
        write_register(9'h100, 24'd0);       // Phase 0
        write_register(9'h101, 24'd2097152); // Phase 1
        write_register(9'h102, 24'd4194304); // Phase 2
        write_register(9'h103, 24'd6291456); // Phase 3
        write_register(9'h104, 24'd8388608); // Phase 4
        write_register(9'h105, 24'd10485760);// Phase 5
        
        // Enable DDS in MODE0 (6x6)
        write_register(9'h1FF, 24'h000080);  // Enable=1, Mode=00
        
        // Monitor channels (should see 36 channels total)
        monitor_channels(200, "MODE0 6x6 Test");
        
        // ========================================
        // TEST 4: MODE2 - LFM (Linear Frequency Modulation)
        // ========================================
        test_number = 4;
        $display("\n--- TEST %0d: MODE2 LFM Test ---", test_number);
        
        // Disable DDS
        write_register(9'h1FF, 24'h000000);
        wait_cycles(5);
        
        // Configure stepped frequencies for LFM (first 8 steps)
        write_register(9'h000, 24'd5000);   // Step 0
        write_register(9'h001, 24'd5500);   // Step 1
        write_register(9'h002, 24'd6000);   // Step 2
        write_register(9'h003, 24'd6500);   // Step 3
        write_register(9'h004, 24'd7000);   // Step 4
        write_register(9'h005, 24'd7500);   // Step 5
        write_register(9'h006, 24'd8000);   // Step 6
        write_register(9'h007, 24'd8500);   // Step 7
        
        // Configure some phase registers
        write_register(9'h100, 24'd0);       // Phase 0
        write_register(9'h101, 24'd4194304); // Phase 1
        
        // Enable DDS in MODE2 (LFM)
        write_register(9'h1FF, 24'h000082);  // Enable=1, Mode=10
        
        // Monitor LFM operation
        monitor_channels(300, "MODE2 LFM Test");
        
        // ========================================
        // TEST 5: MODE3 - CFS (Coded Frequency Signal)
        // ========================================
        test_number = 5;
        $display("\n--- TEST %0d: MODE3 CFS Test ---", test_number);
        
        // Disable DDS
        write_register(9'h1FF, 24'h000000);
        wait_cycles(5);
        
        // Configure 7 coded frequencies
        write_register(9'h000, 24'd4000);   // Code 0
        write_register(9'h001, 24'd5000);   // Code 1
        write_register(9'h002, 24'd6000);   // Code 2
        write_register(9'h003, 24'd7000);   // Code 3
        write_register(9'h004, 24'd8000);   // Code 4
        write_register(9'h005, 24'd9000);   // Code 5
        write_register(9'h006, 24'd10000);  // Code 6
        
        // Enable DDS in MODE3 (CFS)
        write_register(9'h1FF, 24'h000083);  // Enable=1, Mode=11
        
        // Monitor CFS operation
        monitor_channels(250, "MODE3 CFS Test");
        
        // ========================================
        // TEST 6: Sync Signal Test
        // ========================================
        test_number = 6;
        $display("\n--- TEST %0d: Sync Signal Test ---", test_number);
        
        // Continue with MODE1 for sync test
        write_register(9'h1FF, 24'h000081);  // MODE1
        wait_cycles(50);
        
        $display("Applying sync pulse...");
        @(posedge clk);
        sync = 1;
        @(posedge clk);
        sync = 0;
        
        // Monitor after sync
        monitor_channels(100, "Sync Test");
        
        // ========================================
        // TEST 7: Register Write/Read Verification
        // ========================================
        test_number = 7;
        $display("\n--- TEST %0d: Register Write Verification ---", test_number);
        
        // Test writing to edge addresses
        write_register(9'h0FF, 24'hABCDEF);  // Last frequency register
        write_register(9'h11F, 24'h123456);  // Last phase register
        write_register(9'h1FF, 24'h000080);  // Instruction register
        
        $display("Register write test completed");
        
        // ========================================
        // End of Tests
        // ========================================
        wait_cycles(50);
        $display("\n=== ALL TESTS COMPLETED ===");
        $display("Total test cases executed: %0d", test_number);
        $finish;
    end
    
    // ========================================
    // Timeout Protection
    // ========================================
    initial begin
        #500000;  // 500us timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end
    
    // ========================================
    // Optional: Waveform File Generation
    // ========================================
    initial begin
        $dumpfile("multichannel_dds_tb.vcd");
        $dumpvars(0, Multichannel_DDS_tb);
    end

endmodule
