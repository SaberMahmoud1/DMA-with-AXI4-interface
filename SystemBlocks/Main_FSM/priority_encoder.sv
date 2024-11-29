module priority_encoder (
    input  logic [31:0] in,    // 32-bit input
    output logic [4:0] out     // 5-bit output
);

    always_comb begin
        out = 5'b00000; // Default output

        for (logic[4:0] i = 31; i > 0; i = i - 1) begin
            if (in[i]) begin
                out = i;
            end
        end
    end

endmodule
