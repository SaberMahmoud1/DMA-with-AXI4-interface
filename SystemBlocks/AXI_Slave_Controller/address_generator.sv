module address_generator #(
    parameter  ADDRESS_WIDTH            = 8,
    parameter  TRANSACTION_SIZE_BITS    = 3,
    parameter  TRANSACTION_BURST_BITS   = 2,
    parameter  TRANSACTION_LEN_BITS     = 8
)
(
    input  logic [ADDRESS_WIDTH-1         :0] LAST_ADDR,
    input  logic [TRANSACTION_SIZE_BITS-1 :0] SIZE, // 1b, 2b, 4b, 8b, etc.
    input  logic [TRANSACTION_BURST_BITS-1:0] BURST, // Fixed, INCR, WRAP, Reserved
    input  logic [TRANSACTION_LEN_BITS-1  :0] LEN,
    output logic [ADDRESS_WIDTH-1         :0] NEXT_ADDR
);

    logic [ADDRESS_WIDTH-1:0] wrap_mask, increment_reg;

    // Increment logic
    always_comb begin
        increment_reg = 0;
        if (BURST != 2'b00) begin
            case(SIZE)
                3'b000: increment_reg =  1;
                3'b001: increment_reg =  2;
                3'b010: increment_reg =  4;
                3'b011: increment_reg =  8;
                3'b100: increment_reg = 16;
                3'b101: increment_reg = 32;
                3'b110: increment_reg = 64;
                3'b111: increment_reg = 128;
                default: increment_reg = 0;
            endcase
        end
    end

    // Wrap mask generation logic
    always_comb begin
        wrap_mask = 0;
        if (BURST == 2'b10) begin // WRAP
            case(LEN)
                8'h01: wrap_mask = (1 << (SIZE + 1));
                8'h03: wrap_mask = (1 << (SIZE + 2));
                8'h07: wrap_mask = (1 << (SIZE + 3));
                8'h0F: wrap_mask = (1 << (SIZE + 4));
                default: wrap_mask = 0;
            endcase
            wrap_mask = wrap_mask - 1;
        end
    end

    // Address calculation logic
    always_comb begin
        NEXT_ADDR = LAST_ADDR + increment_reg;
        if (BURST != 2'b00) begin
            // Align any subsequent address
            case(SIZE)
                3'b001: NEXT_ADDR[0] = 0;
                3'b010: NEXT_ADDR[1:0] = 0;
                3'b011: NEXT_ADDR[2:0] = 0;
                3'b100: NEXT_ADDR[3:0] = 0;
                3'b101: NEXT_ADDR[4:0] = 0;
                3'b110: NEXT_ADDR[5:0] = 0;
                3'b111: NEXT_ADDR[6:0] = 0;
                default: NEXT_ADDR = LAST_ADDR + increment_reg;
            endcase
        end

        // Apply wrap-around logic
        if (BURST == 2'b10) begin // WRAP
            NEXT_ADDR = (LAST_ADDR & ~wrap_mask) | (NEXT_ADDR & wrap_mask);
        end
    end

endmodule
