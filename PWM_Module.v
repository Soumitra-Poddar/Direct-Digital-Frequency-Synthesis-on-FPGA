`timescale 1ns / 1ps

module PWM_Module(
    input  clk,
    input  resetn,
    input  signed [15:0] Sine_out,
    input  signed [16:0] Tri_out,
    output reg PWM_1,
    output reg PWM_2,
    output reg signed [3:0] PWM_3
);

    localparam DEADTIME_CYCLES = 5;
    
    reg [3:0] dt_cnt_1 = 0;
    reg [3:0] dt_cnt_2 = 0;
    reg [3:0] dt_cnt_3 = 0;
    
    reg last_cmp = 0;
    reg last_sign = 0;
  
    wire signed [16:0] Sine_out_ext = {{1{Sine_out[15]}}, Sine_out};
    wire cmp = (Sine_out_ext >= Tri_out);
    wire sine_sign = Sine_out[15];
    
    wire desired_PWM_1 = cmp;
    wire desired_PWM_2 = ~cmp;
    wire signed [3:0] desired_PWM_3 = cmp ? (sine_sign ? -4'sd5 : 4'sd5) : 4'sd0;
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            PWM_1 <= 0;
            PWM_2 <= 0;
            PWM_3 <= 0;
            dt_cnt_1 <= 0;
            dt_cnt_2 <= 0;
            dt_cnt_3 <= 0;
            last_cmp <= 0;
            last_sign <= 0;
        end else begin
            if (cmp != last_cmp) begin
                dt_cnt_1 <= DEADTIME_CYCLES;
                PWM_1 <= 0;
            end else if (dt_cnt_1 != 0) begin
                dt_cnt_1 <= dt_cnt_1 - 1;
                PWM_1 <= 0;
            end else begin
                PWM_1 <= desired_PWM_1;
            end
            
            if (cmp != last_cmp) begin
                dt_cnt_2 <= DEADTIME_CYCLES;
                PWM_2 <= 0;
            end else if (dt_cnt_2 != 0) begin
                dt_cnt_2 <= dt_cnt_2 - 1;
                PWM_2 <= 0;
            end else begin
                PWM_2 <= desired_PWM_2;
            end
            
            if (sine_sign != last_sign) begin
                dt_cnt_3 <= DEADTIME_CYCLES;
                PWM_3 <= 0;
            end else if (dt_cnt_3 != 0) begin
                dt_cnt_3 <= dt_cnt_3 - 1;
                PWM_3 <= 0;
            end else begin
                PWM_3 <= desired_PWM_3;
            end
            
            last_cmp <= cmp;
            last_sign <= sine_sign;
        end
    end

endmodule
