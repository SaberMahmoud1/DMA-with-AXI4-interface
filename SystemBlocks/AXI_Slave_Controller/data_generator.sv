module AlignedWrite (
    input  logic        clk,
    input  logic        rstn, 
    input  logic        enable, 
    input  logic        strt,  
    input  logic [1:0]  addr,
    input  logic [3:0]  AXI_wstrb,
    input  logic [31:0] AXI_wdata,
    output logic [31:0] formatted_data
);

    logic [31:0] aligned_data;
    logic [31:0] valid_data;
    logic [31:0] formatted_data_reg;

    // Determine byte offset within the 32-bit word
    logic [1:0] byte_offset;
    assign byte_offset = addr[1:0];

    // Determine when to re-align
    logic re_align;
    assign re_align = ((byte_offset == 2'b00) | strt);

    always_comb begin

        valid_data = 32'd0;

        unique case (AXI_wstrb)

            4'b0001: valid_data[7:0] = AXI_wdata[7:0];
            4'b0010: valid_data[15:8]  = AXI_wdata[15:8];
            4'b0100: valid_data[23:16] = AXI_wdata[23:16];
            4'b1000: valid_data[31:24] = AXI_wdata[31:24];

            4'b0011: begin valid_data[7:0] = AXI_wdata[7:0]; valid_data[15:8]  = AXI_wdata[15:8]; end
            4'b0101: begin valid_data[7:0] = AXI_wdata[7:0]; valid_data[15:8]  = AXI_wdata[23:16]; end
            4'b1001: begin valid_data[7:0] = AXI_wdata[7:0]; valid_data[15:8]  = AXI_wdata[31:24]; end

            4'b0110: begin valid_data[7:0] = AXI_wdata[15:8]; valid_data[15:8] = AXI_wdata[23:16]; end
            4'b1010: begin valid_data[7:0] = AXI_wdata[15:8]; valid_data[15:8] = AXI_wdata[31:24]; end

            4'b1100: begin valid_data[7:0]  = AXI_wdata[23:16]; valid_data[15:8] = AXI_wdata[31:24]; end

            4'b1111: begin valid_data[7:0] = AXI_wdata[7:0]; valid_data[15:8] = AXI_wdata[15:8]; valid_data[23:16]  = AXI_wdata[23:16]; valid_data[31:24] = AXI_wdata[31:24]; end

            default: valid_data = 32'b0; // Should not happen
            
        endcase

        // Shift data according to the offset
        aligned_data = valid_data << (byte_offset * 8);

    end

    always_ff @( posedge clk or negedge rstn) begin 
        if(~rstn)
            formatted_data_reg <= 0;
        else if(re_align)
            formatted_data_reg <= aligned_data;
        else if(enable)
            formatted_data_reg <= formatted_data_reg | aligned_data;
    end

    assign formatted_data = (re_align) ? aligned_data : aligned_data | formatted_data_reg;

endmodule
