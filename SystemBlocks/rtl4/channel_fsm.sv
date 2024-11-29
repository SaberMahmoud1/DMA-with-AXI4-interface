module channel_FSM #(
  parameter  C_M_AXI_ADDR_WIDTH = 8,
  parameter  REGFILE_ADDR_WIDTH = 8,
  parameter  REGFILE_DATA_WIDTH = 32
)
(
  input  logic AXI_aclk,
  input  logic AXI_aresetn,

  // Arbitration FSM Interface for both read and write channels FSMs
  input  logic validChannels,
  input  logic [31:0] activeChannels,
  input logic arbitrate,
  input req1,
  input req2,
  output logic give1,
  output logic give2,

  // Read FSM signals
  output logic [C_M_AXI_ADDR_WIDTH-1:0] src_addr,                    
  output logic [1:0] read_burst_type,
  output logic [2:0] read_burst_size,
  output logic [8:0] read_beats,
  output logic start_read,
  input  logic read_transaction_completed,
  input  logic read_resp_error,

  // Write FSM signals
  output logic [C_M_AXI_ADDR_WIDTH-1:0] dst_addr,                    
  output logic [1:0] write_burst_type,
  output logic [2:0] write_burst_size,
  output logic [8:0] write_beats,
  output logic start_write,
  input  logic write_transaction_completed,
  input  logic write_resp_error,

  // Arbiter interface
  // Read FSM
  input  logic arbReadValid,
  input  logic [8:0] arbReadBeats,
  input  logic r_channelDone,
  input  logic arbReadTransactionsDone,
  output logic arbReadDone,
  
  // Write FSM
  input  logic [8:0] arbWriteBeats,
  input  logic w_channelDone,
  input  logic arbWriteTransactionsDone,
  input  logic arbWriteValid,
  output logic arbWriteDone,
  
  // Register File Interface
  // Read Channel FSM
  output logic regFile_readEnable,
  output logic [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr,
  input  logic [REGFILE_DATA_WIDTH-1:0] regFile_readData,

  // Write Channel FSM
  output logic regFile_readEnable2,
  output logic [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr2,
  input  logic [REGFILE_DATA_WIDTH-1:0] regFile_readData2
);

  // Instantiate the readChannel_FSM module
  readChannel_FSM #(
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .REGFILE_ADDR_WIDTH(REGFILE_ADDR_WIDTH),
    .REGFILE_DATA_WIDTH(REGFILE_DATA_WIDTH)
  ) u_readChannel_FSM (
    .AXI_aclk(AXI_aclk),
    .AXI_aresetn(AXI_aresetn),
    
    .src_addr(src_addr),
    .burst_type(read_burst_type),
    .burst_size(read_burst_size),
    .beats(read_beats),
    .start_read(start_read),
    .read_transaction_completed(read_transaction_completed),
    // .read_resp_error(read_resp_error),

    .validChannels(validChannels),
    .activeChannels(activeChannels),
    .arbitrate(arbitrate),
    .req(req1),
    .give(give1),

    .arbReadDone(arbReadDone),
    .arbReadValid(arbReadValid),
    .arbReadBeats(arbReadBeats),
    .channelDone(r_channelDone),
    .arbReadTransactionsDone(arbReadTransactionsDone),

    .regFile_readEnable(regFile_readEnable),
    .regFile_readAddr(regFile_readAddr),
    .regFile_readData(regFile_readData)
  );

  // Instantiate the writeChannel_FSM module
  writeChannel_FSM #(
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .REGFILE_ADDR_WIDTH(REGFILE_ADDR_WIDTH),
    .REGFILE_DATA_WIDTH(REGFILE_DATA_WIDTH)
  ) u_writeChannel_FSM (
    .AXI_aclk(AXI_aclk),
    .AXI_aresetn(AXI_aresetn),

    .dst_addr(dst_addr),
    .burst_type(write_burst_type),
    .burst_size(write_burst_size),
    .beats(write_beats),
    .start_write(start_write),
    .write_transaction_completed(write_transaction_completed),
    // .write_resp_error(write_resp_error),

    .validChannels(validChannels),
    .activeChannels(activeChannels),
    .arbitrate(arbitrate),
    .req(req2),
    .give(give2),

    .arbWriteDone(arbWriteDone),
    .arbWriteValid(arbWriteValid),
    .arbWriteBeats(arbWriteBeats),
    .channelDone(w_channelDone),
    .arbWriteTransactionsDone(arbWriteTransactionsDone),

    .regFile_readEnable(regFile_readEnable2),
    .regFile_readAddr(regFile_readAddr2),
    .regFile_readData(regFile_readData2)
  );

endmodule
