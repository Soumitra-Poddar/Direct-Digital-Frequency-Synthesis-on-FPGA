`timescale 1ns / 1ps

module TriangularWave_Module (
    input  clk,
    input  resetn,
    output signed [16:0] Tri_out
    );
    
    reg  [23:0] Accm;
    reg  [23:0] FCW;
    reg  signed [16:0] Tri_reg;
    
    wire [16:0] ramp_val;
    wire direction;
    
    assign Tri_out = Tri_reg;
    assign direction = Accm[23];
    assign ramp_val = Accm[22:6];
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            Accm    <= 24'd0;
            FCW     <= 24'd21845;
            Tri_reg <= 17'sd0;
        end else begin
            Accm <= Accm + FCW;
            if (direction == 1'b0) begin
                Tri_reg <= $signed(ramp_val) - 17'sd65536;
            end else begin
                Tri_reg <= 17'sd65535 - $signed(ramp_val);
            end
        end
    end
endmodule