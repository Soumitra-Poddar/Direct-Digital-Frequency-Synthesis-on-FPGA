`timescale 1ns / 1ps

module DDS_Module (
    input  wire         clk,
    input  wire         resetn,
    input  wire         result_ready,
    output wire [15:0]  sine_out,
    output wire [15:0]  result_out,
    output wire         result_valid
);
    // DDS Parameters
    reg [23:0] FCW = 24'd6771;
    reg [11:0] K_INT = 12'd2305;
    
    // DDS Accumulator
    reg [23:0] accumulator;
    wire [9:0] sine_addr = accumulator[23:14];
    
    always @(posedge clk or negedge resetn)
        if (!resetn) accumulator <= 0;
        else         accumulator <= accumulator + FCW;
    
    // ROM Outputs
    wire [15:0] sine_rom_out;
    wire [31:0] k_rom_out;
    
    // Stage 1: Read from ROMs
    reg [15:0] sine_stage1;
    reg [31:0] kval_stage1;
    reg        valid_stage1;
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sine_stage1 <= 0;
            kval_stage1 <= 0;
            valid_stage1 <= 0;
        end else begin
            sine_stage1 <= sine_rom_out;
            kval_stage1 <= k_rom_out;
            valid_stage1 <= 1;
        end
    end
    
    // K-value delay pipeline to match Fixed_to_Float latency
    // Adjust DELAY_STAGES based on your Fixed_to_Float latency
    parameter DELAY_STAGES = 4;  // Typical latency for Fixed_to_Float
    
    reg [31:0] kval_pipe [DELAY_STAGES-1:0];
    reg        valid_pipe [DELAY_STAGES-1:0];
    
    integer i;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (i = 0; i < DELAY_STAGES; i = i + 1) begin
                kval_pipe[i] <= 0;
                valid_pipe[i] <= 0;
            end
        end else begin
            kval_pipe[0] <= kval_stage1;
            valid_pipe[0] <= valid_stage1;
            for (i = 1; i < DELAY_STAGES; i = i + 1) begin
                kval_pipe[i] <= kval_pipe[i-1];
                valid_pipe[i] <= valid_pipe[i-1];
            end
        end
    end
    
    wire [31:0] kval_delayed = kval_pipe[DELAY_STAGES-1];
    wire        valid_delayed = valid_pipe[DELAY_STAGES-1];
    
    // Stage 2: Fixed to Float
    wire [31:0] float_sine;
    wire f2f_valid, f2f_ready;
    wire mult_a_ready, mult_b_ready;
    
    Fixed_to_Float f2f (
        .aclk(clk),
        .s_axis_a_tvalid(valid_stage1 && f2f_ready),  // Clean valid signal
        .s_axis_a_tready(f2f_ready),
        .s_axis_a_tdata({{16{sine_stage1[15]}}, sine_stage1}),
        .s_axis_a_tuser(1'b0),
        .s_axis_a_tlast(1'b0),
        .m_axis_result_tvalid(f2f_valid),
        .m_axis_result_tready(mult_a_ready),
        .m_axis_result_tdata(float_sine),
        .m_axis_result_tuser(),
        .m_axis_result_tlast()
    );
    
    // Stage 3: Float Multiply (Now with synchronized inputs)
    wire [31:0] mult_result;
    wire mult_valid, mult_ready;
    
    Float_Multiply mult (
        .aclk(clk),
        .s_axis_a_tvalid(f2f_valid),
        .s_axis_a_tready(mult_a_ready),
        .s_axis_a_tdata(float_sine),
        .s_axis_a_tuser(1'b0),
        .s_axis_a_tlast(1'b0),
        .s_axis_b_tvalid(valid_delayed),  // Now synchronized!
        .s_axis_b_tready(mult_b_ready),
        .s_axis_b_tdata(kval_delayed),    // Delayed K-value
        .s_axis_b_tuser(1'b0),
        .s_axis_b_tlast(1'b0),
        .m_axis_result_tvalid(mult_valid),
        .m_axis_result_tready(mult_ready),
        .m_axis_result_tdata(mult_result),
        .m_axis_result_tuser(),
        .m_axis_result_tlast()
    );
    
    assign mult_ready = ff2f_ready;
    
    // Stage 4: Float to Fixed
    wire [15:0] fixed_result;
    wire ff2f_valid, ff2f_ready;
    
    Float_to_Fixed ff2f (
        .aclk(clk),
        .s_axis_a_tvalid(mult_valid),
        .s_axis_a_tready(ff2f_ready),
        .s_axis_a_tdata(mult_result),
        .s_axis_a_tuser(1'b0),
        .s_axis_a_tlast(1'b0),
        .m_axis_result_tvalid(ff2f_valid),
        .m_axis_result_tready(result_ready),
        .m_axis_result_tdata(fixed_result),
        .m_axis_result_tuser(),
        .m_axis_result_tlast()
    );
    
    // Output Register for result_valid
    reg result_valid_reg;
    always @(posedge clk or negedge resetn)
        if (!resetn) result_valid_reg <= 0;
        else         result_valid_reg <= ff2f_valid;
    
    // ROM Instantiations
    SineROM sine_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(sine_addr),
        .douta(sine_rom_out)
    );
    
    k_values k_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(K_INT),
        .douta(k_rom_out)
    );
    
    // Output Assignments
    assign sine_out     = sine_rom_out;
    assign result_out   = fixed_result;
    assign result_valid = result_valid_reg;

endmodule