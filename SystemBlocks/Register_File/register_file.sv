module register_file #(
    parameter DATA_WIDTH = 32,          // Width of the data
    parameter ADDR_WIDTH = 8            // Width of the address
)(
    input clk,
    input resetn,

    /*************************************************************************/
    // Slave interface (1write port and 1read port)
    input write_enable,                 // Write enable signal
    input [DATA_WIDTH-1:0] datain,      // Data input
    input [ADDR_WIDTH-1:0] writeAddr,   // Write address
    
    input read_enable,                  // Read enable signal
    input [ADDR_WIDTH-1:0] readAddr,    // Read address
    output reg [DATA_WIDTH-1:0] dataout,// Data output

    output writeReady,              // Write ready signal
    output readReady,               // Read ready signal

    /*************************************************************************/
    // Main FSM interface (2read ports)

    input  read_enable2,
    input  [ADDR_WIDTH-1:0] readAddr2,
    output reg [DATA_WIDTH-1:0] dataout2,


    input  read_enable3,
    input  [ADDR_WIDTH-1:0] readAddr3,
    output reg [DATA_WIDTH-1:0] dataout3
);

    // Memory for the register file
    reg [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    // Write process
    always_ff @(posedge clk) begin
        if (write_enable) begin
            mem[writeAddr] <= datain;  // Write data to memory
        end
    end

    // Read process for port 1
    always_ff @(posedge clk or negedge resetn) begin
        if (~resetn) begin
            dataout <= 0;
        end else if (read_enable) begin
            dataout <= mem[readAddr];  // Read data from memory
        end
    end
    
    // Read process for port 2
    always_ff @(posedge clk or negedge resetn) begin
        if (~resetn) begin
            dataout2 <= 0;
        end else if (read_enable2) begin
            dataout2 <= mem[readAddr2];  // Read data from memory
        end
    end

    // Read process for port 3
    always_ff @(posedge clk or negedge resetn) begin
        if (~resetn) begin
            dataout3 <= 0;
        end else if (read_enable3) begin
            dataout3 <= mem[readAddr3];  // Read data from memory
        end
    end

    assign writeReady = 1;
    assign readReady = 1;

endmodule
