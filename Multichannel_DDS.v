`timescale 1ns / 1ps

module Multichannel_DDS(
    input clk,
    input resetn,
    input [8:0] addr,
    input [23:0] data,
    input wr_en,
    input sync,
    output reg signed [15:0] sine_out_ch0,
    output reg [4:0] current_channel,
    output reg channel_valid
);

    localparam FREQ_REG_BASE  = 9'h000;
    localparam PHASE_REG_BASE = 9'h100;
    localparam INSTR_REG_ADDR = 9'h1FF;

    localparam MODE0 = 2'b00;
    localparam MODE1 = 2'b01;
    localparam MODE2 = 2'b10;
    localparam MODE3 = 2'b11;

    reg [23:0] freq_regs [0:255];
    reg [23:0] phase_regs [0:31];
    reg [7:0] instruction_reg;

    reg [23:0] accumulators [0:31];
    reg [4:0] channel_counter;
    reg [7:0] lfm_step_counter;
    reg [2:0] cfs_code_counter;

    wire [1:0] mode = instruction_reg[1:0];
    wire dds_enable = instruction_reg[7];

    wire freq_reg_sel  = (addr >= FREQ_REG_BASE)  && (addr <= 9'h0FF);
    wire phase_reg_sel = (addr >= PHASE_REG_BASE) && (addr <= 9'h11F);
    wire instr_reg_sel = (addr == INSTR_REG_ADDR);

    reg [23:0] current_fcw;
    reg [23:0] current_phase_offset;
    wire [23:0] current_phase;
    wire [9:0] sine_addr;
    wire signed [15:0] sine_data;

    assign current_phase = accumulators[channel_counter] + current_phase_offset;
    assign sine_addr = current_phase[23:14];

    SineROM sine_rom_inst (
        .clka(clk),
        .ena(dds_enable),
        .addra(sine_addr),
        .douta(sine_data)
    );

    integer i;
    integer j;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (i = 0; i < 256; i = i + 1)
                freq_regs[i] <= 24'd6711;
            for (j = 0; j < 32; j = j + 1)
                phase_regs[j] <= 24'd0;
            instruction_reg <= 8'h80;
        end else if (wr_en) begin
            if (freq_reg_sel)
                freq_regs[addr[7:0]] <= data;
            else if (phase_reg_sel)
                phase_regs[addr[4:0]] <= data;
            else if (instr_reg_sel)
                instruction_reg <= data[7:0];
        end
    end

    always @(*) begin
        case (mode)
            MODE0: current_fcw = freq_regs[channel_counter / 6];
            MODE1: current_fcw = freq_regs[0];
            MODE2: current_fcw = freq_regs[lfm_step_counter];
            MODE3: current_fcw = freq_regs[cfs_code_counter];
            default: current_fcw = freq_regs[0];
        endcase
    end

    always @(*) begin
        case (mode)
            MODE0: current_phase_offset = phase_regs[channel_counter % 6];
            MODE1,
            MODE2,
            MODE3: current_phase_offset = phase_regs[channel_counter];
            default: current_phase_offset = 24'd0;
        endcase
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (i = 0; i < 32; i = i + 1)
                accumulators[i] <= 24'd0;
            channel_counter <= 5'd0;
            lfm_step_counter <= 8'd0;
            cfs_code_counter <= 3'd0;
            current_channel <= 5'd0;
            channel_valid <= 1'b0;
            sine_out_ch0 <= 16'sd0;
        end else if (dds_enable) begin
            accumulators[channel_counter] <= accumulators[channel_counter] + current_fcw;
            current_channel <= channel_counter;
            channel_valid <= 1'b1;
            if (channel_counter == 5'd0)
                sine_out_ch0 <= sine_data;

            case (mode)
                MODE0:
                    channel_counter <= (channel_counter == 5'd35) ? 5'd0 : channel_counter + 1'b1;
                MODE1:
                    channel_counter <= (channel_counter == 5'd31) ? 5'd0 : channel_counter + 1'b1;
                MODE2: begin
                    if (channel_counter == 5'd31) begin
                        channel_counter <= 5'd0;
                        lfm_step_counter <= (lfm_step_counter == 8'd255) ? 8'd0 : lfm_step_counter + 1'b1;
                    end else
                        channel_counter <= channel_counter + 1'b1;
                end
                MODE3: begin
                    if (channel_counter == 5'd31) begin
                        channel_counter <= 5'd0;
                        cfs_code_counter <= (cfs_code_counter == 3'd6) ? 3'd0 : cfs_code_counter + 1'b1;
                    end else
                        channel_counter <= channel_counter + 1'b1;
                end
            endcase
        end else begin
            channel_valid <= 1'b0;
        end
    end

    reg sync_d1, sync_d2;
    wire sync_pulse = sync_d1 & ~sync_d2;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sync_d1 <= 1'b0;
            sync_d2 <= 1'b0;
        end else begin
            sync_d1 <= sync;
            sync_d2 <= sync_d1;
        end
    end

    always @(posedge clk) begin
        if (sync_pulse && dds_enable) begin
            channel_counter <= 5'd0;
            lfm_step_counter <= 8'd0;
            cfs_code_counter <= 3'd0;
        end
    end

endmodule
/*
module DDS_Module(
    input clk,
    input resetn,
    output signed [15:0] Sine_out
);

    wire [4:0] current_channel;
    wire channel_valid;

    Multichannel_DDS mch_dds_inst (
        .clk(clk),
        .resetn(resetn),
        .addr(9'h000),
        .data(24'd0),
        .wr_en(1'b0),
        .sync(1'b0),
        .sine_out_ch0(Sine_out),
        .current_channel(current_channel),
        .channel_valid(channel_valid)
    );

endmodule
*/
