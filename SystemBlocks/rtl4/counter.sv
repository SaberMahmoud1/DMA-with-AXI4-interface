module counter #(
    parameter WIDTH = 8           // Parameter to set the counter width (default is 8 bits)
)(
    input  logic clk,             // Clock input
    input  logic resetn,          // Active low reset
    input  logic enable,          // Enable signal for counting
    input  logic add_enable,      // Control signal to enable adding an arbitrary value
    input  logic [WIDTH-1:0] add_value, // Arbitrary value to add when add_enable is high
    input  logic load_value_enable,       // Control signal to load a value into the counter
    input  logic [WIDTH-1:0] load_value,       // The value loaded into the counter
    output logic [WIDTH-1:0] count // Output counter value
);

    // Sequential logic for the counter
    always_ff @(posedge clk or negedge resetn) begin
        if (~resetn)
            count <= '0;                         // Reset counter to 0 on reset
        else if (load_value_enable)
            count <= load_value;                         // Load counter with zero if load_zero is high
        else if (add_enable) begin
            count <= count + add_value;      // Add the arbitrary value if add_enable is high
        end
        else if (enable) begin
            count <= count + 1;              // Otherwise, increment the counter by 1
        end
    end

endmodule
