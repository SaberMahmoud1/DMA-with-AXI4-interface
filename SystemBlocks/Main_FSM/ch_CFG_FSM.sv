module ch_CFG_FSM
#(
    parameter REGFILE_ADDR_WIDTH = 8,
    parameter REGFILE_DATA_WIDTH = 32
)
(
    input wire AXI_aclk,
    input wire AXI_aresetn,

    // CPU interface
    input  CPU_interrupt_CFG,
    output logic  CPU_interrupt_ch_done,
    output logic CPU_interrupt_end,

    // Arbiter Interface with rd_ch_CFG
    output wire arbSample,
    output wire [5:0] arbCurrentChannelSample,
    output wire [3:0] arbChannelPriority,
    output wire [31:0] arbChannelTransferSize,
    output wire arbitrate,
    input wire arbWriteTransactionsDone,

    // Arbiter Interface with wr_ch_CFG
    input  logic [5:0]  ch_id,
    input  logic ch_done,

    // Channel FSM Interface with rd_ch_CFG
    output  logic [31:0] chActiveChannels,
    output  logic  chValidChannels,
    output  logic  req1,
    output  logic  req2,
    input  logic  give1,
    input  logic  give2,

    // RegFile interface with rd_ch_CFG
    output wire regFile_readEnable,
    output wire [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr,
    input wire [REGFILE_DATA_WIDTH-1:0] regFile_readData,

    output wire regFile_readEnable2,
    output wire [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr2,
    input wire [REGFILE_DATA_WIDTH-1:0] regFile_readData2,

    // RegFile interface with wr_ch_CFG
    output logic regFile_writeEnable,
    output logic [REGFILE_ADDR_WIDTH-1 : 0] regFile_writeAddr,
    output logic [REGFILE_DATA_WIDTH-1 : 0] regFile_writeData,

    // AXI_SLAVE_INTERFACE with wr_ch_CFG
    input  logic regFile_writeReady
);

    // Instantiate the wr_ch_CFG module
    wr_ch_CFG #(
    .REGFILE_ADDR_WIDTH(REGFILE_ADDR_WIDTH),
    .REGFILE_DATA_WIDTH(REGFILE_DATA_WIDTH)
    ) wr_ch_CFG_inst (
    .AXI_aclk(AXI_aclk),
    .AXI_aresetn(AXI_aresetn),

    // CPU interface
    .CPU_interrupt_end(CPU_interrupt_end),
    .CPU_interrupt_ch_done(CPU_interrupt_ch_done),

    // Arbiter Interface
    .ch_id(ch_id),
    .ch_done(ch_done),

    // rd_ch_CFG FSM Interface
    .ActiveChannels(chActiveChannels),
    .validChannels(chValidChannels),

    // RegFile interface
    .regFile_writeReady(regFile_writeReady),
    .regFile_writeEnable(regFile_writeEnable),
    .regFile_writeAddr(regFile_writeAddr),
    .regFile_writeData(regFile_writeData)
    );

    // Instantiate the rd_ch_CFG_FSM module
    rd_ch_CFG_FSM #(
        .REGFILE_ADDR_WIDTH(REGFILE_ADDR_WIDTH),
        .REGFILE_DATA_WIDTH(REGFILE_DATA_WIDTH)
    ) rd_ch_CFG_FSM_inst (
        .AXI_aclk(AXI_aclk),
        .AXI_aresetn(AXI_aresetn),

        // CPU interface
        .CPU_interrupt_CFG(CPU_interrupt_CFG),
        .CPU_interrupt_end(CPU_interrupt_end),

        // Arbiter Interface
        .arbSample(arbSample),
        .arbCurrentChannelSample(arbCurrentChannelSample),
        .arbChannelPriority(arbChannelPriority),
        .arbChannelTransferSize(arbChannelTransferSize),
        .arbitrate(arbitrate),
        .arbWriteTransactionsDone(arbWriteTransactionsDone),
        
        // For new spec
        .ch_id(ch_id),
        .ch_done(ch_done),

        // Channel FSM Interface
        .chActiveChannels(chActiveChannels),
        .chValidChannels(chValidChannels),
        .req1(req1),
        .req2(req2),
        .give1(give1),
        .give2(give2),

        // RegFile interface
        .regFile_readEnable(regFile_readEnable),
        .regFile_readAddr(regFile_readAddr),
        .regFile_readData(regFile_readData),
        .regFile_readEnable2(regFile_readEnable2),
        .regFile_readAddr2(regFile_readAddr2),
        .regFile_readData2(regFile_readData2)
    );

endmodule
