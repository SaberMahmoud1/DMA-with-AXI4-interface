module slave_controller_read_fsm #(
    parameter  ADDRESS_WIDTH            = 8,
    parameter  DATA_WIDTH               = 32,
    parameter  REGFILE_ADDRWIDTH        = 9,
    parameter  REGFILE_DATAWIDTH        = 9,

    localparam  TRANSACTION_LEN_BITS    = 8,
    localparam  TRANSACTION_SIZE_BITS   = 3,
    localparam  TRANSACTION_BURST_BITS  = 2,
    localparam  TRANSACTION_RESPONSE    = 2,
    localparam  LSB_DUE_OCTET_REF       = $clog2(DATA_WIDTH) - 3
)(
    input  logic AXI_aclk,
    input  logic AXI_aresetn,
    
    // Read Address Channel Signals
    input  logic [ADDRESS_WIDTH-1         :0] AXI_araddr,
    input  logic [TRANSACTION_LEN_BITS-1  :0] AXI_arlen, 
    input  logic [TRANSACTION_SIZE_BITS-1 :0] AXI_arsize,
    input  logic [TRANSACTION_BURST_BITS-1:0] AXI_arburst,
    input  logic AXI_arvalid,
    output logic AXI_arready,

    // Read response
    output logic [DATA_WIDTH-1 :0] AXI_rdata, 
    output logic [TRANSACTION_RESPONSE-1:0] AXI_rresp,
    output logic AXI_rlast,
    output logic AXI_rvalid,
    input  logic AXI_rready,

    // Interface With The System Module
    input  logic sys_readReady,
    input  logic [REGFILE_DATAWIDTH - 1 :0] sys_readData,
    output logic [REGFILE_ADDRWIDTH - 1 :0] sys_readAddress,
    output logic sys_readEnable
);
    
    // State Definitions using an Enum
    typedef enum logic [3:0] {
        IDLE          = 4'd0,     
        READ_ADDRESS  = 4'd1,
        READ_RESPONSE = 4'd2,
        LAST_TRANSFER = 4'd3
    } state_t;

    state_t current_state, next_state; // State variables

    // Command signals for reading
    logic readCMD_resp, readCMD_last, readCMD_addr, readCMD_f;

    // Register to hold the read address
    logic [ADDRESS_WIDTH-1  :0] readAddress_reg;

    logic arValid_once;
    logic initialAddr_f;
    logic [ADDRESS_WIDTH-1  :0] last_addr;
    logic [ADDRESS_WIDTH-1  :0] next_addr;

    logic [TRANSACTION_LEN_BITS-1  :0] counter;

    // Address generator instance
    address_generator #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .TRANSACTION_SIZE_BITS(TRANSACTION_SIZE_BITS),
        .TRANSACTION_BURST_BITS(TRANSACTION_BURST_BITS),
        .TRANSACTION_LEN_BITS(TRANSACTION_LEN_BITS)
    ) u_NEXT_ADDR_CALC (
        .LAST_ADDR(last_addr),
        .SIZE(AXI_arsize),
        .BURST(AXI_arburst),
        .LEN(AXI_arlen),
        .NEXT_ADDR(next_addr)
    );

    // Keep track of when the address has been valid at least once
    always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
        if (~AXI_aresetn) 
            arValid_once <= 0;
        else if (AXI_arvalid) 
            arValid_once <= 1;
        else if (next_state == IDLE) 
            arValid_once <= 0;
    end

    assign initialAddr_f = (AXI_arvalid & ~arValid_once);
    assign last_addr = (initialAddr_f) ? AXI_araddr : readAddress_reg;

    // Burst counter
    always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
        if (!AXI_aresetn) begin
            counter <= 0;
        end
        else if (next_state == READ_ADDRESS) begin
            counter <= AXI_arlen + 1;
        end 
        else if (readCMD_f) begin
            if (counter != 0)
                counter <= counter - 1;
        end
    end

    // State register
    always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
        if (~AXI_aresetn) begin
            current_state <= IDLE; // Reset to IDLE state
        end 
        else begin
            current_state <= next_state; // Transition to the next state
        end
    end

    // State transition flags
    logic all_state;
    assign all_state  = AXI_rlast & AXI_rready & AXI_arvalid & AXI_arready & sys_readReady;
    logic nrdy_state;
    assign nrdy_state = AXI_rlast & AXI_rready & (!AXI_arvalid | !AXI_arready) & sys_readReady;

    // State transition logic
    always_comb begin
        next_state = current_state; // Default to stay in current state

        case (current_state)
            IDLE: begin 
                if (AXI_arvalid & AXI_arready)
                    next_state = READ_ADDRESS;
            end
            READ_ADDRESS: begin
                if (all_state)
                    next_state = READ_ADDRESS;
                else if (nrdy_state)
                    next_state = IDLE;
                else if (AXI_rlast)
                    next_state = LAST_TRANSFER;
                else 
                    next_state = READ_RESPONSE;
            end
            READ_RESPONSE: begin
                if (all_state)
                    next_state = READ_ADDRESS;
                else if (nrdy_state)
                    next_state = IDLE;
                else if (AXI_rlast)
                    next_state = LAST_TRANSFER;
            end
            LAST_TRANSFER: begin
                if (AXI_rready) begin
                    if (AXI_arvalid & AXI_arready)
                        next_state = READ_ADDRESS;
                    else
                        next_state = IDLE;
                end
            end
            default: next_state = current_state; // In case of unexpected state
        endcase
    end

    // AXI Output logic
    always_comb begin   
        AXI_arready = 1'b0; // Default

        case (current_state)
            IDLE: AXI_arready = 1'b1;
            READ_ADDRESS,
            READ_RESPONSE,
            LAST_TRANSFER: begin
                if (counter == 0)
                    AXI_arready = 1'b1;
            end
            default: AXI_arready = 1'b0;
        endcase
    end

    assign AXI_rresp  = 2'b00; // Always respond with "OKAY"
    assign AXI_rlast  = (counter == 0) & (current_state != IDLE);
    assign AXI_rvalid = (current_state == READ_RESPONSE) | (current_state == LAST_TRANSFER);
    assign AXI_rdata  = sys_readData;

    // Read Command assertions
    assign readCMD_addr = (next_state == READ_ADDRESS) & all_state;
    assign readCMD_resp = ((next_state == READ_RESPONSE) | (current_state == READ_RESPONSE)) & sys_readReady & AXI_rready;
    assign readCMD_last = ((next_state == LAST_TRANSFER) | (current_state == LAST_TRANSFER)) & sys_readReady & AXI_rready;
    assign readCMD_f    = (readCMD_resp | readCMD_last | readCMD_addr) & !AXI_rlast;

    // Address control logic
    always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
        if (~AXI_aresetn)
            readAddress_reg <= 0; 
        else if (readCMD_f) 
            readAddress_reg <= next_addr;
        else if (AXI_arvalid) 
            readAddress_reg <= AXI_araddr;
    end
    
    // RegFile outputs
    assign sys_readAddress = (initialAddr_f) ? AXI_araddr[LSB_DUE_OCTET_REF +: REGFILE_ADDRWIDTH] : readAddress_reg[LSB_DUE_OCTET_REF +: REGFILE_ADDRWIDTH];
    assign sys_readEnable = readCMD_f;

endmodule
