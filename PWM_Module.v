`timescale 1ns / 1ps

module PWM_Module(
    input  clk,
    input  resetn,
    input  signed [15:0] Sine_out,
    input  signed [16:0] Tri_out,
    output reg PWM_1,
    output reg PWM_2,
    output reg signed [3:0] PWM_3,
    output reg signed [3:0] PWM_4
);

    localparam DEADTIME_CYCLES = 5;
    localparam DT_WIDTH = 4;

    reg [DT_WIDTH-1:0] dt_cnt_1 = 0;
    reg [DT_WIDTH-1:0] dt_cnt_2 = 0;
    reg [DT_WIDTH-1:0] dt_cnt_3 = 0;
    reg [DT_WIDTH-1:0] dt_cnt_4 = 0;

    reg last_cmp = 0;
    reg last_sign = 0;
    reg signed [3:0] last_PWM_4_actual = 0;

    wire signed [16:0] Sine_out_ext = {{1{Sine_out[15]}}, Sine_out};

    wire cmp = (Sine_out_ext >= Tri_out);
    wire sine_sign = Sine_out[15];

    wire cmp_edge = (cmp != last_cmp);
    wire sign_edge = (sine_sign != last_sign);

    wire desired_PWM_1 = cmp;
    wire desired_PWM_2 = ~cmp;
    wire signed [3:0] desired_PWM_3 = cmp ? (sine_sign ? -4'sd5 : 4'sd5) : 4'sd0;
    wire signed [3:0] desired_PWM_4 = cmp ? 4'sd5 : -4'sd5;
    wire pwm4_transition = (desired_PWM_4 != last_PWM_4_actual);

    wire dt_active_1 = (dt_cnt_1 != 0);
    wire dt_active_2 = (dt_cnt_2 != 0);
    wire dt_active_3 = (dt_cnt_3 != 0);
    wire dt_active_4 = (dt_cnt_4 != 0);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            PWM_1 <= 1'b0;
            PWM_2 <= 1'b0;
            PWM_3 <= 4'sd0;
            PWM_4 <= 4'sd0;

            dt_cnt_1 <= 0;
            dt_cnt_2 <= 0;
            dt_cnt_3 <= 0;
            dt_cnt_4 <= 0;

            last_cmp <= 1'b0;
            last_sign <= 1'b0;
            last_PWM_4_actual <= 4'sd0;

        end else begin
            if (cmp_edge) begin
                dt_cnt_1 <= DEADTIME_CYCLES;
                PWM_1 <= 1'b0;
            end else if (dt_active_1) begin
                dt_cnt_1 <= dt_cnt_1 - 1;
                PWM_1 <= 1'b0;
            end else begin
                PWM_1 <= desired_PWM_1;
            end

            if (cmp_edge) begin
                dt_cnt_2 <= DEADTIME_CYCLES;
                PWM_2 <= 1'b0;
            end else if (dt_active_2) begin
                dt_cnt_2 <= dt_cnt_2 - 1;
                PWM_2 <= 1'b0;
            end else begin
                PWM_2 <= desired_PWM_2;
            end

            // PWM_3: Deadtime on sign change
            if (sign_edge) begin
                dt_cnt_3 <= DEADTIME_CYCLES;
                PWM_3 <= 4'sd0;
            end else if (dt_active_3) begin
                dt_cnt_3 <= dt_cnt_3 - 1;
                PWM_3 <= 4'sd0;
            end else begin
                PWM_3 <= desired_PWM_3;
            end

            if (pwm4_transition && !dt_active_4) begin
                dt_cnt_4 <= DEADTIME_CYCLES;
                PWM_4 <= 4'sd0;
            end else if (dt_active_4) begin
                dt_cnt_4 <= dt_cnt_4 - 1;
                PWM_4 <= 4'sd0;
            end else begin
                PWM_4 <= desired_PWM_4;
            end

            last_cmp <= cmp;
            last_sign <= sine_sign;

            if (!dt_active_4)
                last_PWM_4_actual <= desired_PWM_4;
        end
    end
endmodule
