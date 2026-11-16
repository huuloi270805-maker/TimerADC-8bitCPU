module control_unit (
    input  wire [3:0] opcode,
    output reg  [2:0] alu_op,
    output reg        alu_src_imm,
    output reg        ra_is_rd,
    output reg        rb_is_rd,
    output reg        uses_a,
    output reg        uses_b,
    output reg        reg_we,
    output reg        mem_to_reg,
    output reg        mem_we,
    output reg        flag_we,
    output reg        jump,
    output reg        br_z,
    output reg        br_nz,
    output reg        halt
);
    always @(*) begin
        alu_op      = 3'b000;
        alu_src_imm = 1'b0;
        ra_is_rd    = 1'b0;
        rb_is_rd    = 1'b0;
        uses_a      = 1'b0;
        uses_b      = 1'b0;
        reg_we      = 1'b0;
        mem_to_reg  = 1'b0;
        mem_we      = 1'b0;
        flag_we     = 1'b0;
        jump        = 1'b0;
        br_z        = 1'b0;
        br_nz       = 1'b0;
        halt        = 1'b0;

        case (opcode)
            4'h0: begin end // NOP
            4'h1: begin alu_op = 3'b000; uses_a = 1'b1; uses_b = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end // ADD
            4'h2: begin alu_op = 3'b001; uses_a = 1'b1; uses_b = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end // SUB
            4'h3: begin alu_op = 3'b010; uses_a = 1'b1; uses_b = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end // AND
            4'h4: begin alu_op = 3'b011; uses_a = 1'b1; uses_b = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end // OR
            4'h5: begin alu_op = 3'b100; uses_a = 1'b1; uses_b = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end // XOR
            4'h6: begin alu_op = 3'b101; uses_a = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end             // SHL
            4'h7: begin alu_op = 3'b110; uses_a = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end             // SHR
            4'h8: begin alu_op = 3'b111; alu_src_imm = 1'b1; reg_we = 1'b1; end                        // LDI (SUA: chuyen thang hang so, truoc la 000)
            4'h9: begin alu_op = 3'b000; alu_src_imm = 1'b1; ra_is_rd = 1'b1; uses_a = 1'b1; reg_we = 1'b1; flag_we = 1'b1; end // ADDI
            4'hA: begin alu_op = 3'b000; uses_a = 1'b1; reg_we = 1'b1; mem_to_reg = 1'b1; end          // LD
            4'hB: begin alu_op = 3'b000; uses_a = 1'b1; uses_b = 1'b1; rb_is_rd = 1'b1; mem_we = 1'b1; end // ST
            4'hC: begin jump = 1'b1; end                                                             // JMP
            4'hD: begin br_z = 1'b1; end                                                             // BZ
            4'hE: begin br_nz = 1'b1; end                                                            // BNZ
            4'hF: begin halt = 1'b1; end                                                             // HLT
            default: begin end
        endcase
    end
endmodule