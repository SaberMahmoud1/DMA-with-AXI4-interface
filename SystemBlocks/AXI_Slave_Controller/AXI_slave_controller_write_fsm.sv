module slave_controller_write_fsm #(
    parameter  ADDRESS_WIDTH            = 8,
    parameter  DATA_WIDTH               = 32,
    parameter  REGFILE_ADDRWIDTH        = 9,
    parameter  REGFILE_DATAWIDTH        = 9,

    parameter  LANE_WIDTH              = 8,
    parameter  WSTRB_WIDTH             = DATA_WIDTH / LANE_WIDTH,
    parameter  TRANSACTION_LEN_BITS    = 8, // 1, 2, 4, 8, 16, ..., 256
    parameter  TRANSACTION_SIZE_BITS   = 3, // 1, 2, 4, 8, 16, 32, 64, 128 in Bytes
    parameter  TRANSACTION_BURST_BITS  = 2, // fixed, increment, wrap
    parameter  TRANSACTION_RESPONSE    = 2,
    parameter  LSB_DUE_OCTET_REF       = $clog2(DATA_WIDTH) - 3
)
(
    input logic AXI_aclk,
    input logic AXI_aresetn,
    
    // Write Address Channel Signals
    input logic [ADDRESS_WIDTH-1         :0] AXI_awaddr,
    input logic [TRANSACTION_LEN_BITS-1  :0] AXI_awlen, 
    input logic [TRANSACTION_SIZE_BITS-1 :0] AXI_awsize,
    input logic [TRANSACTION_BURST_BITS-1:0] AXI_awburst,
    input logic AXI_awvalid,
    output logic AXI_awready,

    // Write Data Channel Signals
    input logic [DATA_WIDTH-1 :0] AXI_wdata,
    input logic [WSTRB_WIDTH-1:0] AXI_wstrb, 
    input logic AXI_wlast,
    input logic AXI_wvalid,
    output logic AXI_wready,

    // Write Response Channel
    input logic AXI_bready,
    output logic AXI_bvalid,
    output logic [TRANSACTION_RESPONSE-1:0] AXI_bresp,

    // Interface with the system modules
    // RegFile
    input logic sys_writeReady,
    output logic [REGFILE_DATAWIDTH - 1:0] sys_writeData,
    output logic [REGFILE_ADDRWIDTH - 1:0] sys_writeAddress,
    output logic sys_writeEnable,
    // Main FSM for the Shared Space
    output logic occupied
);

    // States Definition
    typedef enum logic [3:0] {
        IDLE                          = 4'd0,     
        WRITE_ADDRESS                 = 4'd1,
        WRITE_DATA_AFTER_ADDRESS      = 4'd2,
        LAST_TRANSFER_A               = 4'd3,
        WRITE_DATA                    = 4'd4,
        LAST_TRANSFER_B_NO_ADDR_READY = 4'd5,
        LAST_TRANSFER_B_WITH_ADDR     = 4'd6,
        WRITE_ADDRESS_AFTER_DATA      = 4'd7,
        BUFFERED_TO_REGFILE           = 4'd8,
        WRITE_DATA_AND_ADDRESS        = 4'd9,
        LAST_TRANSFER_C               = 4'd10,
        RESPONSE                      = 4'd11
    } state_t;

    state_t current_state, next_state; // State variables

    // Data generator signals
    logic dataGen_strt;
    logic [1:0] dataGen_addr;

    // Internal buffer signals for the WDATA before AWADDR case
    logic [DATA_WIDTH-1:0] bufferData [TRANSACTION_LEN_BITS-1:0]; // Buffer for the case of writing data before address
    logic [TRANSACTION_LEN_BITS:0] wr_ptr, rd_ptr; // FIFO rd and wr pointers
    logic bufferWrite_f, bufferRead_f; // Write and Read commands for the fifo
    logic bufferedToSystem_f; // Flag for out-of-order transactions done (data then address) to regFile
    logic [DATA_WIDTH-1:0] bufferOut;

    logic writeCMD_A, writeCMD_C, writeCMD_R, writeCMD_addrFirst, writeCMD_dataFirst, writeCMD_f; // Flags for writing to the System Modules

    logic [ADDRESS_WIDTH-1:0] writeAddress_reg; // Latch the write address for the address generator module

    logic awValid_once;
    logic initialAddr_f;
    logic [ADDRESS_WIDTH-1:0] last_addr, next_addr; // Current and next addresses calculated by the address generator

    logic [DATA_WIDTH-1:0] passThrough; // Directly take the data from the AXI bus
    
    // The address generator module
    always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
        if (~AXI_aresetn) 
            awValid_once <= 1'b0;
        else if (AXI_awvalid) 
            awValid_once <= 1'b1;
        else if (current_state == RESPONSE)
            awValid_once <= 1'b0;
    end

    assign initialAddr_f = (AXI_awvalid & ~awValid_once);
    assign last_addr = (initialAddr_f) ? AXI_awaddr : writeAddress_reg;

    address_generator #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .TRANSACTION_SIZE_BITS(TRANSACTION_SIZE_BITS),
        .TRANSACTION_BURST_BITS(TRANSACTION_BURST_BITS),
        .TRANSACTION_LEN_BITS(TRANSACTION_LEN_BITS)
    ) u_NEXT_ADDR_CALC (
        .LAST_ADDR(last_addr),
        .SIZE(AXI_awsize),
        .BURST(AXI_awburst),
        .LEN(AXI_awlen),
        .NEXT_ADDR(next_addr)
    );

    // The Data generator module
    assign dataGen_strt = ((next_state == WRITE_DATA_AFTER_ADDRESS && current_state != WRITE_DATA_AFTER_ADDRESS) ||
                           (next_state == WRITE_DATA_AND_ADDRESS && current_state != WRITE_DATA_AND_ADDRESS));
    assign dataGen_addr = last_addr[1:0];
    
    AlignedWrite u_AlignedWrite (
        .clk(AXI_aclk), 
        .rstn(AXI_aresetn), 
        .strt(dataGen_strt), 
        .enable(sys_writeEnable), 
        .addr(dataGen_addr), 
        .AXI_wstrb(AXI_wstrb), 
        .AXI_wdata(AXI_wdata), 
        .formatted_data(passThrough)
    );

    // State transition logic
    always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
        if (~AXI_aresetn)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin 
                if (AXI_awvalid && AXI_wvalid && AXI_wlast && AXI_wready)
                    next_state = RESPONSE;
                else if (AXI_awvalid && AXI_wvalid && AXI_wlast)
                    next_state = LAST_TRANSFER_C;
                else if (AXI_awvalid && AXI_wvalid)
                    next_state = WRITE_DATA_AND_ADDRESS;
                else if (AXI_awvalid)
                    next_state = WRITE_ADDRESS;
                else if (AXI_wvalid && AXI_wlast && AXI_wready)
                    next_state = WRITE_ADDRESS_AFTER_DATA;
                else if (AXI_wvalid && AXI_wlast)
                    next_state = LAST_TRANSFER_B_NO_ADDR_READY;   
                else if (AXI_wvalid)
                    next_state = WRITE_DATA;
            end
            WRITE_ADDRESS: begin
                if (AXI_wvalid && AXI_wlast && AXI_wready)
                    next_state = RESPONSE;
                else if (AXI_wvalid && AXI_wlast)
                    next_state = LAST_TRANSFER_A;
                else if (AXI_wvalid)
                    next_state = WRITE_DATA_AFTER_ADDRESS;
            end
            WRITE_DATA_AFTER_ADDRESS: begin
                if (AXI_wlast && AXI_wready)
                    next_state = RESPONSE;
                else if (AXI_wlast)
                    next_state = LAST_TRANSFER_A;
            end
            LAST_TRANSFER_A,
            LAST_TRANSFER_C: begin
                if (AXI_wready)
                    next_state = RESPONSE;
            end
            WRITE_DATA: begin
                if (AXI_awvalid && AXI_wlast && AXI_wready)
                    next_state = BUFFERED_TO_REGFILE;
                else if (AXI_awvalid && AXI_wlast)
                    next_state = LAST_TRANSFER_B_WITH_ADDR;
                else if (AXI_wready && AXI_wlast)
                    next_state = WRITE_ADDRESS_AFTER_DATA;
                else if (AXI_awvalid)
                    next_state = WRITE_DATA_AND_ADDRESS;
                else if (AXI_wlast)
                    next_state = LAST_TRANSFER_B_NO_ADDR_READY;
            end
            LAST_TRANSFER_B_NO_ADDR_READY: begin
                if (AXI_awvalid && AXI_wready)
                    next_state = BUFFERED_TO_REGFILE;
                else if (AXI_awvalid)
                    next_state = LAST_TRANSFER_B_WITH_ADDR;
                else if (AXI_wready)
                    next_state = WRITE_ADDRESS_AFTER_DATA;
            end
            LAST_TRANSFER_B_WITH_ADDR: begin
                if (AXI_wready)
                    next_state = BUFFERED_TO_REGFILE;
            end
            WRITE_ADDRESS_AFTER_DATA: begin
                if (AXI_awvalid)
                    next_state = BUFFERED_TO_REGFILE;
            end
            BUFFERED_TO_REGFILE: begin
                if (bufferedToSystem_f)
                    next_state = RESPONSE;
            end
            WRITE_DATA_AND_ADDRESS: begin
                if (AXI_wlast && AXI_wready)
                    next_state = RESPONSE;
                else if (AXI_wlast)
                    next_state = LAST_TRANSFER_C;
            end
            RESPONSE: begin
                if (AXI_bready)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // AXI Output logic
    always_comb begin   
   
        AXI_awready = 1'b0;

        case (current_state)
            IDLE,
            WRITE_DATA,
            LAST_TRANSFER_B_NO_ADDR_READY: begin
                AXI_awready = 1'b1;
            end
            default: begin
                AXI_awready = 1'b0;
            end
            endcase
    end

    assign AXI_bresp = 2'b00; // Always respond with 2'b00 = Okay
    assign AXI_bvalid = current_state == RESPONSE;
    assign AXI_wready  = sys_writeReady & (current_state != RESPONSE);    

    // Buffer data, waiting for the address
    assign bufferWrite_f = ((next_state == WRITE_DATA) | (current_state == WRITE_DATA)) & AXI_wvalid ; 
    assign bufferRead_f  = ((next_state == BUFFERED_TO_REGFILE) | (current_state == BUFFERED_TO_REGFILE) & AXI_wready); // The condition is that the system module must be ready initially

    always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
        //integer k;
        if(~AXI_aresetn) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            bufferOut <= 0;
        end
        else begin
            if(bufferWrite_f) begin
                //for(k=0; k < AXI_wstrb_WIDTH/8; k=k+1)
	                //begin
                    //    if (AXI_wstrb[k])
                    //        bufferData[wr_ptr][k*8+:8] <= AXI_wdata[k*8+:8]
                    //end
                bufferData[wr_ptr] <= AXI_wdata;
                wr_ptr <= wr_ptr + 1;
            end
            if(bufferRead_f) begin
                bufferOut <=  bufferData[rd_ptr];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

    assign bufferedToSystem_f = (wr_ptr == rd_ptr);

    /*********************************************************************************************************************************/

    // Write Command assertion 
    assign writeCMD_A  = (((next_state == WRITE_DATA_AFTER_ADDRESS) | (current_state == WRITE_DATA_AFTER_ADDRESS) | (current_state == LAST_TRANSFER_A)) & AXI_wvalid & AXI_wready);
    assign writeCMD_C  = (((next_state == WRITE_DATA_AND_ADDRESS)   | (current_state == WRITE_DATA_AND_ADDRESS)   | (current_state == LAST_TRANSFER_C)) & AXI_wvalid & AXI_wready);
    assign writeCMD_R  = ((current_state == IDLE) & (next_state == RESPONSE));
    assign writeCMD_addrFirst = writeCMD_A | writeCMD_C | writeCMD_R;
    assign writeCMD_dataFirst = ((current_state == BUFFERED_TO_REGFILE) & AXI_wready); // Must be Lagging the buffer_read_f by one clock cycle
    assign writeCMD_f = writeCMD_addrFirst | writeCMD_dataFirst;

    // Address control
    always_ff @(posedge AXI_aclk or negedge AXI_aresetn) 
        if(~AXI_aresetn)
            writeAddress_reg <= 0; 
        else if(writeCMD_f ) 
            writeAddress_reg <=  next_addr;
        else if(AXI_awvalid) 
            writeAddress_reg <= AXI_awaddr;
    
    /*********************************************************************************************************************************/

    // RegFile outputs
    assign sys_writeAddress= (initialAddr_f) ? AXI_awaddr[LSB_DUE_OCTET_REF +: REGFILE_ADDRWIDTH] : writeAddress_reg[LSB_DUE_OCTET_REF +: REGFILE_ADDRWIDTH];
    assign sys_writeEnable = writeCMD_f;
    assign sys_writeData   = (bufferRead_f) ? bufferOut : passThrough;

    /*********************************************************************************************************************************/

    // Occupied
    assign occupied = !((current_state == IDLE & next_state == IDLE) | (current_state == WRITE_DATA) | (next_state == WRITE_DATA) | (current_state == RESPONSE) | (next_state == WRITE_ADDRESS));

endmodule