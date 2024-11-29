module MUX2to1 #(
    parameter DATA_WIDTH = 32
)
(
    input  logic sel,    
    input  logic [DATA_WIDTH-1:0] data_in1,
    input  logic [DATA_WIDTH-1:0] data_in2,  
    output logic [DATA_WIDTH-1:0] data_out  
);

    always_comb begin
        case (sel)
            0: data_out = data_in1;  
            1: data_out = data_in2;  
            default: data_out = '0;
        endcase
    end
endmodule
