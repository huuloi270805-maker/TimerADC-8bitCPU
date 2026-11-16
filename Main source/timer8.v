`timescale 1ns/1ps
// =============================================================================
// timer8.v - 8-bit timer: prescaler + counter + compare + PWM
//   period      = (PRESC+1) * (LOAD+1) clocks
//   PWM duty    = CMP / (LOAD+1)          (pwm = en & (cnt < CMP))
//   ovf_pulse   : 1 clock, when the counter wraps (cnt == LOAD -> 0)
//   cmp_pulse   : 1 clock, at the step that leaves cnt == CMP
//                 (= (CMP+1)*(PRESC+1) clocks after the timer started)
//   one-shot    : stops after the first overflow ('done' tells the register
//                 block to clear TMR_CTRL.EN)
//   en = 0      : counter and prescaler are cleared, PWM is low
// =============================================================================
module timer8 (
    input  wire       clk,
    input  wire       rst_n,      // asynchronous, active low
    input  wire       en,
    input  wire       oneshot,
    input  wire [7:0] presc,
    input  wire [7:0] load,
    input  wire [7:0] cmp,
    output reg  [7:0] cnt,
    output reg        ovf_pulse,
    output reg        cmp_pulse,
    output reg        done,       // one-shot finished (1 clock)
    output wire       pwm
);
    reg [7:0] pre;
    // ">=" instead of "==": safe if software lowers PRESC/LOAD while running
    wire step = (pre >= presc);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre       <= 8'd0;
            cnt       <= 8'd0;
            ovf_pulse <= 1'b0;
            cmp_pulse <= 1'b0;
            done      <= 1'b0;
        end else begin
            ovf_pulse <= 1'b0;
            cmp_pulse <= 1'b0;
            done      <= 1'b0;
            if (!en || done) begin           // stopped: clear everything
                pre <= 8'd0;
                cnt <= 8'd0;
            end else if (!step) begin        // not yet time for a step
                pre <= pre + 8'd1;
            end else begin                   // one timer step
                pre <= 8'd0;
                if (cnt == cmp) cmp_pulse <= 1'b1;
                if (cnt >= load) begin
                    cnt       <= 8'd0;       // wrap
                    ovf_pulse <= 1'b1;
                    if (oneshot) done <= 1'b1;
                end else begin
                    cnt <= cnt + 8'd1;
                end
            end
        end
    end

    assign pwm = en & (cnt < cmp);
endmodule
