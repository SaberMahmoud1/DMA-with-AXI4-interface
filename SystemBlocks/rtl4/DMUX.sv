module DMUX1to2 #(
    parameter DATA_WIDTH = 32
)
(
    input  logic [DATA_WIDTH-1:0] din,        
    input  logic sel,    
    output logic [DATA_WIDTH-1:0] dout1, 
    output logic [DATA_WIDTH-1:0] dout2   
);

    always_comb begin
        dout1 = {DATA_WIDTH{1'b0}};
        dout2 = {DATA_WIDTH{1'b0}};
        case (sel)
            1'b0: dout1 = din;
            1'b1: dout2 = din;
        endcase
    end

endmodule
