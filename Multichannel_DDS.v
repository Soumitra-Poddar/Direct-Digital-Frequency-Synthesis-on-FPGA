`timescale 1ns / 1ps

module Multichannel_DDS(
    // System signals
    input clk,
    input resetn,
    
    // External interface (address mapped)
    input [8:0] addr,           // 9-bit address bus
    input [23:0] data,          // 24-bit data bus
    input wr_en,                // Write enable
    input sync,                 // Sync signal
    
    // DDS outputs
    output reg signed [15:0] sine_out_ch0,  // Channel 0 output (for backward compatibility)
    output reg [4:0] current_channel,       // Current active channel indicator
    output reg channel_valid                // Output valid flag
);

    // ===========================================
    // Address Map Constants
    // ===========================================
    localparam FREQ_REG_BASE    = 9'h000;   // 0x000-0x0FF: Frequency Registers (256)
    localparam PHASE_REG_BASE   = 9'h100;   // 0x100-0x11F: Phase Registers (32) 
    localparam INSTR_REG_ADDR   = 9'h1FF;   // 0x1FF: Instruction Register
    
    // ===========================================
    // Mode Constants
    // ===========================================
    localparam MODE0 = 2'b00;   // 6x6 = 36 channels
    localparam MODE1 = 2'b01;   // 1x32 PCW with phase shifts
    localparam MODE2 = 2'b10;   // 1x32 LFM with phase shifts
    localparam MODE3 = 2'b11;   // 1x32 CFS with phase shifts
    
    // ===========================================
    // Register Arrays
    // ===========================================
    reg [23:0] freq_regs [0:255];           // 256 frequency registers
    reg [23:0] phase_regs [0:31];           // 32 phase registers
    reg [7:0] instruction_reg;              // Instruction register
    
    // ===========================================
    // DDS Core Logic
    // ===========================================
    reg [23:0] accumulators [0:31];         // 32 phase accumulators
    reg [4:0] channel_counter;              // Channel multiplexer counter
    reg [7:0] lfm_step_counter;             // LFM step counter (0-255)
    reg [2:0] cfs_code_counter;             // CFS code counter (0-6)
    
    // ===========================================
    // Control Signals Extraction
    // ===========================================
    wire [1:0] mode = instruction_reg[1:0];
    wire dds_enable = instruction_reg[7];
    wire [2:0] cfs_codes = instruction_reg[4:2];
    
    // ===========================================
    // Address Decoding
    // ===========================================
    wire freq_reg_sel = (addr >= FREQ_REG_BASE) && (addr <= (FREQ_REG_BASE + 8'hFF));
    wire phase_reg_sel = (addr >= PHASE_REG_BASE) && (addr <= (PHASE_REG_BASE + 8'h1F));
    wire instr_reg_sel = (addr == INSTR_REG_ADDR);
    
    // ===========================================
    // Current DDS Parameters
    // ===========================================
    reg [23:0] current_fcw;
    reg [23:0] current_phase_offset;
    wire [23:0] current_phase;
    wire [9:0] sine_addr;
    wire signed [15:0] sine_data;
    
    // Phase calculation with offset
    assign current_phase = accumulators[channel_counter] + current_phase_offset;
    assign sine_addr = current_phase[23:14];  // Use top 10 bits for ROM address
    
    // ===========================================
    // Sine ROM Instance
    // ===========================================
    SineROM sine_rom_inst (
        .clka(clk),
        .ena(dds_enable),
        .addra(sine_addr),
        .douta(sine_data)
    );
    
    // ===========================================
    // Register Write Logic
    // ===========================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Initialize frequency registers
            for (integer i = 0; i < 256; i = i + 1) begin
                freq_regs[i] <= 24'd6711;  // Default FCW
            end
            
            // Initialize phase registers
            for (integer i = 0; i < 32; i = i + 1) begin
                phase_regs[i] <= 24'd0;
            end
            
            instruction_reg <= 8'h80;  // Enable DDS, Mode 0
            
        end else if (wr_en) begin
            if (freq_reg_sel) begin
                freq_regs[addr[7:0]] <= data;
            end else if (phase_reg_sel) begin
                phase_regs[addr[4:0]] <= data;
            end else if (instr_reg_sel) begin
                instruction_reg <= data[7:0];
            end
        end
    end
    
    // ===========================================
    // FCW Selection Logic
    // ===========================================
    always @(*) begin
        case (mode)
            MODE0: begin // 6x6 mode - 6 frequencies, 6 phases each
                current_fcw = freq_regs[channel_counter / 6];  // 6 channels per frequency
            end
            
            MODE1: begin // PCW mode - single frequency
                current_fcw = freq_regs[0];
            end
            
            MODE2: begin // LFM mode - stepped frequency
                current_fcw = freq_regs[lfm_step_counter];
            end
            
            MODE3: begin // CFS mode - coded frequencies
                current_fcw = freq_regs[cfs_code_counter];
            end
            
            default: current_fcw = freq_regs[0];
        endcase
    end
    
    // ===========================================
    // Phase Offset Selection Logic  
    // ===========================================
    always @(*) begin
        case (mode)
            MODE0: begin // 6x6 mode
                current_phase_offset = phase_regs[channel_counter % 6];  // Cycle through 6 phases
            end
            
            MODE1, MODE2, MODE3: begin // All other modes use individual phase per channel
                current_phase_offset = phase_regs[channel_counter];
            end
            
            default: current_phase_offset = 24'd0;
        endcase
    end
    
    // ===========================================
    // Channel Control and Accumulator Updates
    // ===========================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Reset all accumulators
            for (integer i = 0; i < 32; i = i + 1) begin
                accumulators[i] <= 24'd0;
            end
            
            channel_counter <= 5'd0;
            lfm_step_counter <= 8'd0;
            cfs_code_counter <= 3'd0;
            current_channel <= 5'd0;
            channel_valid <= 1'b0;
            sine_out_ch0 <= 16'sd0;
            
        end else if (dds_enable) begin
            
            // Update current channel accumulator
            accumulators[channel_counter] <= accumulators[channel_counter] + current_fcw;
            
            // Capture output for current channel
            current_channel <= channel_counter;
            channel_valid <= 1'b1;
            
            // Store channel 0 output for backward compatibility
            if (channel_counter == 5'd0) begin
                sine_out_ch0 <= sine_data;
            end
            
            // Channel sequencing logic
            case (mode)
                MODE0: begin // 6x6 mode - 36 channels total
                    if (channel_counter >= 5'd35) begin
                        channel_counter <= 5'd0;
                    end else begin
                        channel_counter <= channel_counter + 1'b1;
                    end
                end
                
                MODE1: begin // PCW mode - 32 channels
                    if (channel_counter >= 5'd31) begin
                        channel_counter <= 5'd0;
                    end else begin
                        channel_counter <= channel_counter + 1'b1;
                    end
                end
                
                MODE2: begin // LFM mode - 32 channels with stepped frequency
                    if (channel_counter >= 5'd31) begin
                        channel_counter <= 5'd0;
                        // Step through LFM frequencies
                        if (lfm_step_counter >= 8'd255) begin
                            lfm_step_counter <= 8'd0;
                        end else begin
                            lfm_step_counter <= lfm_step_counter + 1'b1;
                        end
                    end else begin
                        channel_counter <= channel_counter + 1'b1;
                    end
                end
                
                MODE3: begin // CFS mode - 32 channels with 7 coded frequencies
                    if (channel_counter >= 5'd31) begin
                        channel_counter <= 5'd0;
                        // Cycle through 7 CFS codes
                        if (cfs_code_counter >= 3'd6) begin
                            cfs_code_counter <= 3'd0;
                        end else begin
                            cfs_code_counter <= cfs_code_counter + 1'b1;
                        end
                    end else begin
                        channel_counter <= channel_counter + 1'b1;
                    end
                end
            endcase
            
        end else begin
            channel_valid <= 1'b0;
        end
    end
    
    // ===========================================
    // Sync Signal Handling
    // ===========================================
    reg sync_d1, sync_d2;
    wire sync_pulse = sync_d1 & ~sync_d2;  // Rising edge detection
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sync_d1 <= 1'b0;
            sync_d2 <= 1'b0;
        end else begin
            sync_d1 <= sync;
            sync_d2 <= sync_d1;
        end
    end
    
    // Reset counters on sync pulse
    always @(posedge clk) begin
        if (sync_pulse && dds_enable) begin
            channel_counter <= 5'd0;
            lfm_step_counter <= 8'd0;
            cfs_code_counter <= 3'd0;
        end
    end

endmodule

// ===========================================
// Backward Compatible Single Channel DDS
// ===========================================
module DDS_Module(
    input clk,
    input resetn,
    output signed [15:0] Sine_out
);

    // Internal signals for multichannel DDS
    wire [4:0] current_channel;
    wire channel_valid;
    
    // Instantiate multichannel DDS with default configuration
    Multichannel_DDS mch_dds_inst (
        .clk(clk),
        .resetn(resetn),
        .addr(9'h000),          // Default address
        .data(24'd0),           // Default data
        .wr_en(1'b0),           // No writes
        .sync(1'b0),            // No sync
        .sine_out_ch0(Sine_out),
        .current_channel(current_channel),
        .channel_valid(channel_valid)
    );

endmodule
