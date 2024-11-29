module main_FSM #(
  parameter  C_M_AXI_ADDR_WIDTH = 8,
  parameter  REGFILE_ADDR_WIDTH = 8,
  parameter  REGFILE_DATA_WIDTH = 32
)(
  input  logic AXI_aclk,
  input  logic AXI_aresetn,

  /*********************************************************************************************************/
  // Master Controller interface

  // Read FSM signals
  output logic [C_M_AXI_ADDR_WIDTH-1:0] src_addr,                    
  output logic [1:0] read_burst_type,
  output logic [2:0] read_burst_size,
  output logic [8:0] read_beats,
  output logic start_read,
  input  logic read_transaction_completed,
  // input  logic read_resp_error,

  // Write FSM signals
  output logic [C_M_AXI_ADDR_WIDTH-1:0] dst_addr,                    
  output logic [1:0] write_burst_type,
  output logic [2:0] write_burst_size,
  output logic [8:0] write_beats,
  output logic start_write,
  input  logic write_transaction_completed,
  // input  logic write_resp_error,

  /*********************************************************************************************************/
  // Arbiter interface
  // Read Channel FSM
  input  logic arbReadValid,
  input  logic [8:0] arbReadBeats,
  input  logic r_channelDone,
  input  logic arbReadTransactionsDone,
  output logic arbReadDone,

  // Write Channel FSM
  input  logic arbWriteValid,
  input  logic [8:0] arbWriteBeats,
  input  logic w_channelDone,
  input  logic arbWriteTransactionsDone,
  output logic arbWriteDone,
  
  // wr_ch_CFG 
  input  logic [5:0] arb_ch_id,

  // // rd_ch_CFG
  output logic arbSample,
  output logic [5:0] arbCurrentChannelSample,
  output logic [3:0] arbChannelPriority,
  output logic [31:0] arbChannelTransferSize,
  output logic arbitrate,

  /*********************************************************************************************************/
  
  // CPU interface
  input wire CPU_interrupt_CFG,
  output wire CPU_interrupt_ch_done,
  output wire CPU_interrupt_end,
  
  /*********************************************************************************************************/
  // Register File Interface
  output logic regFile_readEnable,
  output logic [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr,
  input  logic [REGFILE_DATA_WIDTH-1:0] regFile_readData,

  output logic regFile_readEnable2,
  output logic [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr2,
  input  logic [REGFILE_DATA_WIDTH-1:0] regFile_readData2,

  // RegFile interface with wr_ch_CFG
  output logic regFile_writeEnable,
  output logic [REGFILE_ADDR_WIDTH-1 : 0] regFile_writeAddr,
  output logic [REGFILE_DATA_WIDTH-1 : 0] regFile_writeData,

  // AXI_SLAVE_INTERFACE with wr_ch_CFG
  input  logic regFile_writeReady
);

  // ch_CFG FSM Interface with the channel FSM
  logic validChannels;
  logic [31:0] activeChannels;
  logic req1;
  logic req2;
  logic give1;
  logic give2;

  // Mux select
  logic regFile_readEnable_arb;
  logic [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr_arb;
  logic [REGFILE_DATA_WIDTH-1:0] regFile_readData_arb;

  logic regFile_readEnable2_arb;
  logic [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr2_arb;
  logic [REGFILE_DATA_WIDTH-1:0] regFile_readData2_arb;

  logic regFile_readEnable_ch;
  logic [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr_ch;
  logic [REGFILE_DATA_WIDTH-1:0] regFile_readData_ch;

  logic regFile_readEnable2_ch;
  logic [REGFILE_ADDR_WIDTH-1:0] regFile_readAddr2_ch;
  logic [REGFILE_DATA_WIDTH-1:0] regFile_readData2_ch;

  // Instantiate the channel_FSM module
  channel_FSM #(
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .REGFILE_ADDR_WIDTH(REGFILE_ADDR_WIDTH),
    .REGFILE_DATA_WIDTH(REGFILE_DATA_WIDTH)
  ) u_channel_FSM (
    .AXI_aclk(AXI_aclk),
    .AXI_aresetn(AXI_aresetn),

    /*********************************************************************************************************/

    .validChannels(validChannels),
    .activeChannels(activeChannels),
    .arbitrate(arbitrate),
    .req1(req1),
    .req2(req2),
    .give1(give1),
    .give2(give2),

    /*********************************************************************************************************/

    .src_addr(src_addr),
    .read_burst_type(read_burst_type),
    .read_burst_size(read_burst_size),
    .read_beats(read_beats),
    .start_read(start_read),
    .read_transaction_completed(read_transaction_completed),
    // .read_resp_error(read_resp_error),

    .arbReadValid(arbReadValid),
    .arbReadBeats(arbReadBeats),
    .r_channelDone(r_channelDone),
    .arbReadDone(arbReadDone),
    .arbReadTransactionsDone(arbReadTransactionsDone),

    .regFile_readEnable(regFile_readEnable_ch),
    .regFile_readAddr(regFile_readAddr_ch),
    .regFile_readData(regFile_readData_ch),

    /*********************************************************************************************************/

    .dst_addr(dst_addr),
    .write_burst_type(write_burst_type),
    .write_burst_size(write_burst_size),
    .write_beats(write_beats),
    .start_write(start_write),
    .write_transaction_completed(write_transaction_completed),
    // .write_resp_error(write_resp_error),

    .arbWriteValid(arbWriteValid),
    .arbWriteBeats(arbWriteBeats),
    .w_channelDone(w_channelDone),
    .arbWriteDone(arbWriteDone),
    .arbWriteTransactionsDone(arbWriteTransactionsDone), 

    .regFile_readEnable2(regFile_readEnable2_ch),
    .regFile_readAddr2(regFile_readAddr2_ch),
    .regFile_readData2(regFile_readData2_ch)
  );

  // Instantiate the arbitration_FSM module
  ch_CFG_FSM #(
    .REGFILE_ADDR_WIDTH(REGFILE_ADDR_WIDTH),
    .REGFILE_DATA_WIDTH(REGFILE_DATA_WIDTH)
  ) u_ch_CFG_FSM (
    .AXI_aclk(AXI_aclk),
    .AXI_aresetn(AXI_aresetn),

    .CPU_interrupt_CFG(CPU_interrupt_CFG),
    .CPU_interrupt_end(CPU_interrupt_end),
    .CPU_interrupt_ch_done(CPU_interrupt_ch_done),

    .arbSample(arbSample),
    .arbCurrentChannelSample(arbCurrentChannelSample),
    .arbChannelPriority(arbChannelPriority),
    .arbChannelTransferSize(arbChannelTransferSize),
    .arbitrate(arbitrate),
    .arbWriteTransactionsDone(arbWriteTransactionsDone),
    .ch_id(arb_ch_id),
    .ch_done(w_channelDone),

    .chActiveChannels(activeChannels),
    .chValidChannels(validChannels),
    .req1(req1),
    .req2(req2),
    .give1(give1),
    .give2(give2),

    // rd_ch_CFG interface with regFile
    .regFile_readEnable(regFile_readEnable_arb),
    .regFile_readAddr(regFile_readAddr_arb),
    .regFile_readData(regFile_readData_arb),
    .regFile_readEnable2(regFile_readEnable2_arb),
    .regFile_readAddr2(regFile_readAddr2_arb),
    .regFile_readData2(regFile_readData2_arb),

    // wr_ch_CFG interface with regFile
    .regFile_writeReady(regFile_writeReady),
    .regFile_writeEnable(regFile_writeEnable),
    .regFile_writeAddr(regFile_writeAddr),
    .regFile_writeData(regFile_writeData)
  );

  control_unit_FSM u_control_unit_FSM (
    .AXI_aclk(AXI_aclk),
    .AXI_aresetn(AXI_aresetn),

    // CPU
    .CPU_interrupt_CFG(CPU_interrupt_CFG),
    .CPU_interrupt_end(CPU_interrupt_end),
    
    // rd_ch_CFG
    .arbitrate(arbitrate),
    .validChannels(validChannels),
    // Channel FSM
    .give1(give1),
    .give2(give2),

    .muxSel1(muxSel1),
    .muxSel2(muxSel2)
  );

  MUX2to1  #(1'b1) u_MUX2to1_readEnable_1 (.sel(muxSel1), .data_in1(regFile_readEnable_arb),.data_in2(regFile_readEnable_ch), .data_out(regFile_readEnable));
  MUX2to1  #(REGFILE_ADDR_WIDTH) u_MUX2to1_readAddr_1  (.sel(muxSel1), .data_in1(regFile_readAddr_arb),.data_in2(regFile_readAddr_ch), .data_out(regFile_readAddr));
  DMUX1to2 #(REGFILE_DATA_WIDTH) u_MUX2to1_readData_1  (.sel(muxSel1), .dout1(regFile_readData_arb),.dout2(regFile_readData_ch), .din(regFile_readData) );

  MUX2to1  #(1'b1) u_MUX2to1_readEnable_2 (.sel(muxSel2), .data_in1(regFile_readEnable2_arb),.data_in2(regFile_readEnable2_ch), .data_out(regFile_readEnable2) );
  MUX2to1  #(REGFILE_ADDR_WIDTH) u_MUX2to1_readAddr_2  (.sel(muxSel2), .data_in1(regFile_readAddr2_arb),.data_in2(regFile_readAddr2_ch), .data_out(regFile_readAddr2) );
  DMUX1to2 #(REGFILE_DATA_WIDTH) u_MUX2to1_readData_2  (.sel(muxSel2), .dout1(regFile_readData2_arb),.dout2(regFile_readData2_ch), .din(regFile_readData2) );

endmodule
