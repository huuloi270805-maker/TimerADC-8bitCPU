module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [2:0] alu_op,
    output reg  [7:0] result,
    output reg        z_flag,
    output reg        c_flag
);
    always @(*) begin
        result = 8'b0;
        c_flag = 1'b0;
        case (alu_op)
            3'b000: {c_flag, result} = a + b;          // ADD
            3'b001: {c_flag, result} = a - b;          // SUB
            3'b010: result = a & b;                    // AND
            3'b011: result = a | b;                    // OR
            3'b100: result = a ^ b;                    // XOR
            3'b101: {c_flag, result} = {a, 1'b0};      // SHL (c_flag = bit 7 cu)  -- SUA
            3'b110: begin                              // SHR (c_flag = bit 0 cu)  -- SUA
                        result = {1'b0, a[7:1]};
                        c_flag = a[0];
                    end
            3'b111: result = b;                        // Pass B (dung cho LDI)
            default: result = b;
        endcase
        z_flag = (result == 8'b0);
    end
endmodule