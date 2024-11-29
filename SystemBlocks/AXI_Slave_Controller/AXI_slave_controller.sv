module AXI_slave_controller #(
    parameter  C_AXI_ADDR_WIDTH        = 11,
    parameter  C_AXI_DATA_WIDTH        = 32,
    parameter  REGFILE_ADDRWIDTH       = 9,
    parameter  REGFILE_DATAWIDTH       = 9,

    localparam  LANE_WIDTH              = 8,
    localparam  WSTRB_WIDTH             = C_AXI_DATA_WIDTH / LANE_WIDTH,
    localparam  TRANSACTION_LEN_BITS    = 8,
    localparam  TRANSACTION_SIZE_BITS   = 3,
    localparam  TRANSACTION_BURST_BITS  = 2,
    localparam  TRANSACTION_RESPONSE    = 2,
    localparam  LSB_DUE_OCTET_REF       = $clog2(C_AXI_DATA_WIDTH)-3
)
(
    input  logic AXI_aclk,
    input  logic AXI_aresetn,
    
    // Write Address Channel Signals
    input  logic [C_AXI_ADDR_WIDTH-1      :0] AXI_awaddr,
    input  logic [TRANSACTION_LEN_BITS-1  :0] AXI_awlen, 
    input  logic [TRANSACTION_SIZE_BITS-1 :0] AXI_awsize,
    input  logic [TRANSACTION_BURST_BITS-1:0] AXI_awburst,
    input  logic AXI_awvalid,
    output logic AXI_awready,

    // Write Data Channel Signals
    input  logic [C_AXI_DATA_WIDTH-1 :0] AXI_wdata,
    input  logic [WSTRB_WIDTH-1:0] AXI_wstrb, 
    input  logic AXI_wlast,
    input  logic AXI_wvalid,
    output logic AXI_wready,

    // Write Response Channel
    input  logic AXI_bready,
    output logic AXI_bvalid,
    output logic [TRANSACTION_RESPONSE-1:0] AXI_bresp,

    // Read Address Channel Signals
    input  logic [C_AXI_ADDR_WIDTH-1      :0] AXI_araddr,
    input  logic [TRANSACTION_LEN_BITS-1  :0] AXI_arlen, 
    input  logic [TRANSACTION_SIZE_BITS-1 :0] AXI_arsize,
    input  logic [TRANSACTION_BURST_BITS-1:0] AXI_arburst,
    input  logic AXI_arvalid,
    output logic AXI_arready,

    // Read response
    output logic [C_AXI_DATA_WIDTH-1 :0] AXI_rdata, 
    output logic [TRANSACTION_RESPONSE-1:0] AXI_rresp,
    output logic AXI_rlast,
    output logic AXI_rvalid,
    input  logic AXI_rready,

    // System module signals
    output logic [REGFILE_DATAWIDTH-1:0] sys_writeData,
    output logic [REGFILE_ADDRWIDTH - 1 : 0] sys_writeAddress,
    output logic sys_writeEnable,
    input  logic sys_writeReady,

    input  logic sys_readReady,
    input  logic [REGFILE_DATAWIDTH-1     :0] sys_readData,
    output logic [REGFILE_ADDRWIDTH - 1 : 0] sys_readAddress,
    output logic sys_readEnable,
    // Main FSM for the Shared Space
    output logic occupied
);

    // Instantiate the slave controller write FSM
    slave_controller_write_fsm #(
        .ADDRESS_WIDTH(C_AXI_ADDR_WIDTH),
        .DATA_WIDTH(C_AXI_DATA_WIDTH),
        .REGFILE_ADDRWIDTH(REGFILE_ADDRWIDTH),
        .REGFILE_DATAWIDTH(REGFILE_DATAWIDTH)
    ) u_slave_controller_write_fsm (
        .AXI_aclk(AXI_aclk),
        .AXI_aresetn(AXI_aresetn),

        .AXI_awaddr(AXI_awaddr),
        .AXI_awvalid(AXI_awvalid),
        .AXI_awready(AXI_awready),
        .AXI_awlen(AXI_awlen),
        .AXI_awsize(AXI_awsize),
        .AXI_awburst(AXI_awburst),

        .AXI_wdata(AXI_wdata),
        .AXI_wvalid(AXI_wvalid),
        .AXI_wready(AXI_wready),
        .AXI_wlast(AXI_wlast),
        .AXI_wstrb(AXI_wstrb),

        .AXI_bready(AXI_bready),
        .AXI_bvalid(AXI_bvalid),
        .AXI_bresp(AXI_bresp),

        .sys_writeReady(sys_writeReady),
        .sys_writeData(sys_writeData),
        .sys_writeAddress(sys_writeAddress),
        .sys_writeEnable(sys_writeEnable),

        .occupied(occupied)
    );

    // Instantiate the slave_controller_read_fsm module
    slave_controller_read_fsm #(
        .ADDRESS_WIDTH(C_AXI_ADDR_WIDTH),
        .DATA_WIDTH(C_AXI_DATA_WIDTH),
        .REGFILE_ADDRWIDTH(REGFILE_ADDRWIDTH),
        .REGFILE_DATAWIDTH(REGFILE_DATAWIDTH)
    ) u_slave_controller_read_fsm (
        .AXI_aclk(AXI_aclk),
        .AXI_aresetn(AXI_aresetn),

        .AXI_araddr(AXI_araddr),
        .AXI_arlen(AXI_arlen),
        .AXI_arsize(AXI_arsize),
        .AXI_arburst(AXI_arburst),
        .AXI_arvalid(AXI_arvalid),
        .AXI_arready(AXI_arready),

        .AXI_rdata(AXI_rdata),
        .AXI_rresp(AXI_rresp),
        .AXI_rlast(AXI_rlast),
        .AXI_rvalid(AXI_rvalid),
        .AXI_rready(AXI_rready),
        .sys_readReady(sys_readReady),
        .sys_readData(sys_readData),
        .sys_readAddress(sys_readAddress),
        .sys_readEnable(sys_readEnable)
    );

endmodule
