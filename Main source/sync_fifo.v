`timescale 1ns/1ps
// =============================================================================
// sync_fifo.v - synchronous FIFO, first-word-fall-through, 8 entries
//   push when full  -> result is dropped, 'overflow' pulses (same clock)
//   pop  when empty -> ignored
//   dout shows the oldest entry (0 when empty) so a read needs no wait state
// =============================================================================
module sync_fifo #(
    parameter WIDTH = 10,
    parameter AW    = 3                 // depth = 2**AW = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             push,
    input  wire [WIDTH-1:0] din,
    input  wire             pop,
    output wire [WIDTH-1:0] dout,
    output wire [AW:0]      level,
    output wire             empty,
    output wire             full,
    output wire             overflow    // push while full (dropped)
);
    localparam DEPTH = (1 << AW);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW-1:0]    wptr, rptr;
    reg [AW:0]      count;

    assign empty    = (count == 0);
    assign full     = (count == DEPTH);
    assign level    = count;
    assign dout     = empty ? {WIDTH{1'b0}} : mem[rptr];
    assign overflow = push & full;

    wire do_push = push & ~full;
    wire do_pop  = pop  & ~empty;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr  <= {AW{1'b0}};
            rptr  <= {AW{1'b0}};
            count <= {(AW+1){1'b0}};
        end else begin
            if (do_push) begin
                mem[wptr] <= din;
                wptr      <= wptr + 1'b1;
            end
            if (do_pop) rptr <= rptr + 1'b1;
            case ({do_push, do_pop})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
