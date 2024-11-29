module top_wrapper #(
    parameter  C_AXI_ADDR_WIDTH            = 32,
    parameter  C_M_AXI_ADDR_WIDTH          = 32,
    parameter  C_AXI_DATA_WIDTH            = 32,
    parameter  C_M_AXI_DATA_WIDTH          = 32,
    parameter  C_M_NUM_CHANNELS            = 32,
    parameter  REGFILE_ADDR_WIDTH          = 9,
    parameter  REGFILE_DATA_WIDTH          = 32,

    localparam C_AXI_THREAD_ID_WIDTH       = 1,
    localparam C_AXI_AWUSER_WIDTH          = 1,
    localparam C_AXI_ARUSER_WIDTH          = 1,
    localparam C_AXI_WUSER_WIDTH           = 1,
    localparam C_AXI_RUSER_WIDTH           = 1,
    localparam C_AXI_BUSER_WIDTH           = 1,

    localparam LSB_DUE_OCTET_REF = $clog2(C_AXI_DATA_WIDTH) - 3,

    parameter integer C_NUM_CHANNELS                = 32,   // Number of channels to arbitrate
    parameter integer C_TRANSACTION_SIZE_WIDTH      = 32,   // Width for transaction size signal
    parameter integer C_PRIORITY_WIDTH              = 4,
    parameter integer C_FRAME_SIZE                  = 256,  
    parameter integer FIFO_DEPTH                    = 256 
    
)(
    input AXI_aclk,
    input AXI_aresetn,
    
    // AXI Slave Interface
    input  [C_AXI_ADDR_WIDTH-1:0] AXI_awaddr,
    input  [7:0] AXI_awlen, 
    input  [2:0] AXI_awsize,
    input  [1:0] AXI_awburst,
    input  AXI_awvalid,
    output AXI_awready,

    input  [C_AXI_DATA_WIDTH-1:0] AXI_wdata,
    input  [C_AXI_DATA_WIDTH/8-1:0] AXI_wstrb, 
    input  AXI_wlast,
    input  AXI_wvalid,
    output AXI_wready,

    input  AXI_bready,
    output AXI_bvalid,
    output [1:0] AXI_bresp,

    input  [C_AXI_ADDR_WIDTH-1:0] AXI_araddr,
    input  [7:0] AXI_arlen, 
    input  [2:0] AXI_arsize,
    input  [1:0] AXI_arburst,
    input  AXI_arvalid,
    output AXI_arready,

    output [C_AXI_DATA_WIDTH-1:0] AXI_rdata, 
    output [1:0] AXI_rresp,
    output AXI_rlast,
    output AXI_rvalid,
    input  AXI_rready,   

    /*******************************************************************************************************************************/
    // AXI Master Interface

    output [C_AXI_THREAD_ID_WIDTH-1:0] m_axi_awid,
    output [C_AXI_ADDR_WIDTH-1:0]      m_axi_awaddr,
    output [8-1:0] 			 m_axi_awlen,
    output [3-1:0] 			 m_axi_awsize,
    output [2-1:0] 			 m_axi_awburst,
    output m_axi_awlock,
    output [4-1:0] 			 m_axi_awcache,
    output [3-1:0] 			 m_axi_awprot,
    // AXI3 output wire [4-1:0]                  M_AXI_AWREGION,
    output [4-1:0] 			 m_axi_awqos,
    output [C_AXI_AWUSER_WIDTH-1:0] 	 m_axi_awuser,
    output m_axi_awvalid,
    input  m_axi_awready,
    
    // Master Interface Write Data
    // AXI3 output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]     M_AXI_WID,
    output [C_AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output [C_AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output m_axi_wlast,
    output [C_AXI_WUSER_WIDTH-1:0] m_axi_wuser,
    output m_axi_wvalid,
    input  m_axi_wready,
    
    // Master Interface Write Response
    input  [C_AXI_THREAD_ID_WIDTH-1:0] 	 m_axi_bid,
    input  [2-1:0] 			 m_axi_bresp,
    input  [C_AXI_BUSER_WIDTH-1:0] 	 m_axi_buser,
    input  m_axi_bvalid,
    output m_axi_bready,
    
    // Master Interface Read Address
    output [C_AXI_THREAD_ID_WIDTH-1:0] 	 m_axi_arid,
    output [C_AXI_ADDR_WIDTH-1:0] 	 m_axi_araddr,
    output [8-1:0] 			 m_axi_arlen,
    output [3-1:0] 			 m_axi_arsize,
    output [2-1:0] 			 m_axi_arburst,
    output [2-1:0] 			 m_axi_arlock,
    output [4-1:0] 			 m_axi_arcache,
    output [3-1:0] 			 m_axi_arprot,
    // AXI3 output wire [4-1:0] 		 M_AXI_ARREGION,
    output [4-1:0] 			 m_axi_arqos,
    output [C_AXI_ARUSER_WIDTH-1:0] 	 m_axi_aruser,
    output m_axi_arvalid,
    input  m_axi_arready,
    
    // Master Interface Read Data 
    input  [C_AXI_THREAD_ID_WIDTH-1:0] 	 m_axi_rid,
    input  [C_AXI_DATA_WIDTH-1:0] 	 m_axi_rdata,
    input  [2-1:0] 			 m_axi_rresp,
    input  m_axi_rlast,
    input  [C_AXI_RUSER_WIDTH-1:0] 	 m_axi_ruser,
    input  m_axi_rvalid,
    output m_axi_rready,

    /*******************************************************************************************************************************/
    // CPU Interrupt Signals
    input wire CPU_interrupt_CFG,
    output wire CPU_interrupt_ch_done,
    output wire CPU_interrupt_end
);
        
    // Internal signals for connecting the Slave controller with the register file
    wire sys_writeEnable;
    wire sys_writeReady;
    wire [REGFILE_DATA_WIDTH-1:0] sys_writeData;
    wire [REGFILE_ADDR_WIDTH-1 : 0] sys_writeAddress;
    wire sys_readEnable;
    wire sys_readReady;
    wire [REGFILE_DATA_WIDTH-1:0] sys_readData;
    wire [REGFILE_ADDR_WIDTH-1 : 0] sys_readAddress;

    // Internal signals for connecting the Slave controller with main FSM
    wire occupied;

    /*******************************************************************************************************************************/
    // Internal signals for connecting the Main FSM with the register file
    wire regFile_readEnable2;
    wire [REGFILE_ADDR_WIDTH-1 : 0] regFile_readAddr2;
    wire [REGFILE_DATA_WIDTH-1 : 0] regFile_readData2;
    wire regFile_readEnable3;
    wire [REGFILE_ADDR_WIDTH-1 : 0] regFile_readAddr3;
    wire [REGFILE_DATA_WIDTH-1 : 0] regFile_readData3;
    wire regFile_writeEnable;
    wire[REGFILE_ADDR_WIDTH-1 : 0] regFile_writeAddr;
    wire [REGFILE_DATA_WIDTH-1 : 0] regFile_writeData;
    /*******************************************************************************************************************************/
    // Internal signals for connecting main FSM signals with Master controller
    // Read FSM signals
    logic [C_M_AXI_ADDR_WIDTH-1:0] src_addr;                    
    logic [1:0] read_burst_type;
    logic [2:0] read_burst_size;
    logic [8:0] read_beats;
    logic start_read;
    logic read_transaction_completed;
    logic read_resp_error;

    // Write FSM signals
    logic [C_M_AXI_ADDR_WIDTH-1:0] dst_addr;                  
    logic [1:0] write_burst_type;
    logic [2:0] write_burst_size;
    logic [8:0] write_beats;
    logic start_write;
    logic write_transaction_completed;
    logic write_resp_error;
    
    /*******************************************************************************************************************************/
    // Internal signals for connecting main FSM signals with Arbiter
    // Read FSM signals
    logic arbReadDone;
    logic arbReadValid;
    logic r_channelDone;
    logic [4:0] arbCurrentReadActiveChannel;
    logic [8:0] arbReadBeats;
    logic arbReadTransactionsDone;
    logic [$clog2(C_NUM_CHANNELS):0]     r_current_active_channel;  // Keeps track of the current active channel in round-robin
    logic [$clog2(C_NUM_CHANNELS):0]     w_current_active_channel;  // Keeps track of the current active channel in round-robin
    
    // Write FSM signals
    logic arbWriteDone;
    logic arbWriteValid;
    logic w_channelDone;
    logic [4:0] arbCurrentWriteActiveChannel;
    logic [8:0] arbWriteBeats;
    logic arbWriteTransactionsDone;

    // ch_CFG FSM signals
    logic arbSample;
    logic [5:0] arbCurrentChannelSample;
    logic [3:0] arbChannelPriority;
    logic [31:0] arbChannelTransferSize;
    logic arbitrate;
    
    /*******************************************************************************************************************************/

    
    //Internal signals for connecting the FIFO interface and master through the mux and demux
    logic  [C_M_AXI_DATA_WIDTH-1:0] fifo_wr_data;   //the data to be written to the fifo
    logic                           fifo_full    [C_M_NUM_CHANNELS-1:0];   //fifo full indicator    
    logic                           fifo_empty   [C_M_NUM_CHANNELS-1:0];   //fifo empty indicator
    logic [C_M_AXI_DATA_WIDTH-1:0]  fifo_rd_data [C_M_NUM_CHANNELS-1:0];   //the data to be readed from the fifo
    logic                           wr_ack       [C_M_NUM_CHANNELS-1:0];   //ack signal to make sure the write operations is done right.
    logic                           rd_ack       [C_M_NUM_CHANNELS-1:0];   //ack signal to make sure the read operations is done right.

    //master interface
    logic                                  m_fifo_full;  //the data to be written to the fifo
    logic                                  m_fifo_empty;  //the data to be read from the fifo
    logic                                  m_wr_ack;  //ack signal to make sure the write operations is done right.
    logic                                  m_rd_ack;  //ack signal to make sure the read operations is done right
    logic [C_M_AXI_DATA_WIDTH-1:0]         m_fifo_rd_data;

    logic  [C_M_NUM_CHANNELS-1:0]   fifo_wr_en;   //when enabled the fifo takes data in
    logic  [C_M_NUM_CHANNELS-1:0]   fifo_rd_en;   //when enabled the fifo gives data out 
    logic                           m_fifo_wr_en;  //when enabled the fifo takes data in
    logic                           m_fifo_rd_en;  //when enabled the fifo gives data out


    /**********************************************************************************************************************************/

    logic mxd_regFile_writeEnable;
    logic [REGFILE_ADDR_WIDTH-1 : 0] mxd_regFile_writeAddr;
    logic [REGFILE_DATA_WIDTH-1 : 0] mxd_regFile_writeData;

    /**********************************************************************************************************************************/

    // Instantiate the register file
    register_file #(
        .DATA_WIDTH(REGFILE_DATA_WIDTH),
        .ADDR_WIDTH(REGFILE_ADDR_WIDTH)
    ) u_register_file (
        .clk(AXI_aclk),
        .resetn(AXI_aresetn),

        .write_enable(mxd_regFile_writeEnable),
        .writeAddr(mxd_regFile_writeAddr),
        .writeReady(sys_writeReady),
        .datain(mxd_regFile_writeData),

        .read_enable(sys_readEnable),
        .readAddr(sys_readAddress),
        .readReady(sys_readReady),
        .dataout(sys_readData),

        .read_enable2(regFile_readEnable2),
        .readAddr2(regFile_readAddr2),
        .dataout2(regFile_readData2),

        .read_enable3(regFile_readEnable3),
        .readAddr3(regFile_readAddr3),
        .dataout3(regFile_readData3)
    );

    // Instantiate the AXI slave controller
    AXI_slave_controller #(
        .C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
        .REGFILE_ADDRWIDTH(REGFILE_ADDR_WIDTH),
        .REGFILE_DATAWIDTH(REGFILE_DATA_WIDTH)
    ) u_AXI_slave_controller (
        .AXI_aclk(AXI_aclk),
        .AXI_aresetn(AXI_aresetn),

        .AXI_awaddr(AXI_awaddr),
        .AXI_awlen(AXI_awlen),
        .AXI_awsize(AXI_awsize),
        .AXI_awburst(AXI_awburst),
        .AXI_awvalid(AXI_awvalid),
        .AXI_awready(AXI_awready),

        .AXI_wdata(AXI_wdata),
        .AXI_wstrb(AXI_wstrb),
        .AXI_wlast(AXI_wlast),
        .AXI_wvalid(AXI_wvalid),
        .AXI_wready(AXI_wready),

        .AXI_bready(AXI_bready),
        .AXI_bvalid(AXI_bvalid),
        .AXI_bresp(AXI_bresp),

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

        .sys_writeData(sys_writeData),
        .sys_writeAddress(sys_writeAddress),
        .sys_writeEnable(sys_writeEnable),
        .sys_writeReady(sys_writeReady),
        .sys_readData(sys_readData),
        .sys_readAddress(sys_readAddress),
        .sys_readEnable(sys_readEnable),
        .sys_readReady(sys_readReady),
        .occupied(occupied)
    );

    // Instantiation of the AXI_master_controller module
AXI_master_controller #(
    .C_M_AXI_THREAD_ID_WIDTH(C_AXI_THREAD_ID_WIDTH),           // Set appropriate values for parameters
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
    .C_M_AXI_AWUSER_WIDTH(C_AXI_AWUSER_WIDTH),
    .C_M_AXI_ARUSER_WIDTH(C_AXI_ARUSER_WIDTH),
    .C_M_AXI_WUSER_WIDTH(C_AXI_WUSER_WIDTH),
    .C_M_AXI_RUSER_WIDTH(C_AXI_RUSER_WIDTH),
    .C_M_AXI_BUSER_WIDTH(C_AXI_BUSER_WIDTH),
    .C_M_NUM_CHANNELS(C_NUM_CHANNELS)
) axi_master_controller_inst (
    // System Signals
    .aclk(AXI_aclk),                           // Clock input
    .aresetn(AXI_aresetn),                     // Active-low reset

    // Master Interface Write Address
    .m_axi_awid(m_axi_awid),               // AXI Write ID
    .m_axi_awaddr(m_axi_awaddr),           // AXI Write address
    .m_axi_awlen(m_axi_awlen),             // AXI Write burst length
    .m_axi_awsize(m_axi_awsize),           // AXI Write burst size
    .m_axi_awburst(m_axi_awburst),         // AXI Write burst type
    .m_axi_awlock(m_axi_awlock),           // AXI Write lock
    .m_axi_awcache(m_axi_awcache),         // AXI Write cache
    .m_axi_awprot(m_axi_awprot),           // AXI Write protection
    .m_axi_awqos(m_axi_awqos),             // AXI Write quality of service
    .m_axi_awuser(m_axi_awuser),           // AXI Write user signal
    .m_axi_awvalid(m_axi_awvalid),         // AXI Write address valid
    .m_axi_awready(m_axi_awready),         // AXI Write address ready

    // Master Interface Write Data
    .m_axi_wdata(m_axi_wdata),             // AXI Write data
    .m_axi_wstrb(m_axi_wstrb),             // AXI Write strobe
    .m_axi_wlast(m_axi_wlast),             // AXI Write last transfer
    .m_axi_wuser(m_axi_wuser),             // AXI Write user signal
    .m_axi_wvalid(m_axi_wvalid),           // AXI Write data valid
    .m_axi_wready(m_axi_wready),           // AXI Write data ready

    // Master Interface Write Response
    .m_axi_bid(m_axi_bid),                 // AXI Write response ID
    .m_axi_bresp(m_axi_bresp),             // AXI Write response
    .m_axi_buser(m_axi_buser),             // AXI Write user signal
    .m_axi_bvalid(m_axi_bvalid),           // AXI Write response valid
    .m_axi_bready(m_axi_bready),           // AXI Write response ready

    // Master Interface Read Address
    .m_axi_arid(m_axi_arid),               // AXI Read ID
    .m_axi_araddr(m_axi_araddr),           // AXI Read address
    .m_axi_arlen(m_axi_arlen),             // AXI Read burst length
    .m_axi_arsize(m_axi_arsize),           // AXI Read burst size
    .m_axi_arburst(m_axi_arburst),         // AXI Read burst type
    .m_axi_arlock(m_axi_arlock),           // AXI Read lock
    .m_axi_arcache(m_axi_arcache),         // AXI Read cache
    .m_axi_arprot(m_axi_arprot),           // AXI Read protection
    .m_axi_arqos(m_axi_arqos),             // AXI Read quality of service
    .m_axi_aruser(m_axi_aruser),           // AXI Read user signal
    .m_axi_arvalid(m_axi_arvalid),         // AXI Read address valid
    .m_axi_arready(m_axi_arready),         // AXI Read address ready

    // Master Interface Read Data
    .m_axi_rid(m_axi_rid),                 // AXI Read response ID
    .m_axi_rdata(m_axi_rdata),             // AXI Read data
    .m_axi_rresp(m_axi_rresp),             // AXI Read response
    .m_axi_rlast(m_axi_rlast),             // AXI Read last transfer
    .m_axi_ruser(m_axi_ruser),             // AXI Read user signal
    .m_axi_rvalid(m_axi_rvalid),           // AXI Read data valid
    .m_axi_rready(m_axi_rready),           // AXI Read data ready

    // Main FSM Interface
    .src_addr(src_addr),                   // Source address for read transactions
    .dest_addr(dst_addr),                 // Destination address for write transactions
    .start_write(start_write),             // Start write signal
    .start_read(start_read),               // Start read signal
    .r_burst_type(read_burst_type),           // Read burst type
    .r_burst_size(read_burst_size),           // Read burst size
    .r_beats(read_beats),                     // Number of read beats
    .w_burst_type(write_burst_type),           // Write burst type
    .w_burst_size(write_burst_size),           // Write burst size
    .w_beats(write_beats),                     // Number of write beats

    .write_transaction_completed(write_transaction_completed),  // Write transaction completion flag
    .read_transaction_completed(read_transaction_completed),    // Read transaction completion flag

    // FIFO Interface
    .fifo_wr_en(m_fifo_wr_en),               // FIFO write enable
    .fifo_wr_data(fifo_wr_data),           // FIFO write data
    .fifo_full(m_fifo_full),                 // FIFO full status
    .fifo_empty(m_fifo_empty),               // FIFO empty status
    .fifo_rd_en(m_fifo_rd_en),               // FIFO read enable
    .fifo_rd_data(m_fifo_rd_data),            // FIFO read data
    .wr_ack(m_wr_ack),
    .rd_ack(m_rd_ack)
);

  // Instantiate the arbiter module
  arbiter #(
    .C_NUM_CHANNELS(C_NUM_CHANNELS),
    .C_TRANSACTION_SIZE_WIDTH(C_TRANSACTION_SIZE_WIDTH),
    .C_PRIORITY_WIDTH(C_PRIORITY_WIDTH),
    .C_FRAME_SIZE(C_FRAME_SIZE)
  ) arbiter_inst (
    .aclk(AXI_aclk),
    .aresetn(AXI_aresetn),

    .channel_number(arbCurrentChannelSample),
    .channel_priority(arbChannelPriority),
    .ch_transaction_size(arbChannelTransferSize),
    .sample_channel(arbSample),
    .start_arbitration(arbitrate),

    .r_current_active_channel(r_current_active_channel),
    .w_current_active_channel(w_current_active_channel),

    .read_transaction_completed(arbReadDone),
    .r_data_valid(arbReadValid),    
    .r_beats_of_channel(arbReadBeats),
    .r_transactions_done(arbReadTransactionsDone),
    .r_re_arbitration(r_channelDone),
    
    .write_transaction_completed(arbWriteDone),
    .w_data_valid(arbWriteValid),
    .w_beats_of_channel(arbWriteBeats),
    .w_transactions_done(arbWriteTransactionsDone),
    .w_re_arbitration(w_channelDone)
  );


  // Instantiation of the channel_arbitration_wrapper
  main_FSM #(
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .REGFILE_ADDR_WIDTH(REGFILE_ADDR_WIDTH),
    .REGFILE_DATA_WIDTH(REGFILE_DATA_WIDTH)
  ) u_main_FSM (
    .AXI_aclk(AXI_aclk),
    .AXI_aresetn(AXI_aresetn),

    // Master Controller Interface
    .src_addr(src_addr),
    .read_burst_type(read_burst_type),
    .read_burst_size(read_burst_size),
    .read_beats(read_beats),
    .start_read(start_read),
    .read_transaction_completed(read_transaction_completed),
    // .read_resp_error(read_resp_error),

    .dst_addr(dst_addr),
    .write_burst_type(write_burst_type),
    .write_burst_size(write_burst_size),
    .write_beats(write_beats),
    .start_write(start_write),
    .write_transaction_completed(write_transaction_completed),
    // .write_resp_error(write_resp_error),

    // Arbiter Interface
    .arbReadValid(arbReadValid),
    .arbReadBeats(arbReadBeats),
    .r_channelDone(r_channelDone),
    .arbReadDone(arbReadDone),
    .arbReadTransactionsDone(arbReadTransactionsDone),

    .arbWriteValid(arbWriteValid),
    .arbWriteBeats(arbWriteBeats),
    .w_channelDone(w_channelDone),
    .arbWriteDone(arbWriteDone),
    .arbWriteTransactionsDone(arbWriteTransactionsDone),

    .arbSample(arbSample),
    .arbCurrentChannelSample(arbCurrentChannelSample),
    .arbChannelPriority(arbChannelPriority),
    .arbChannelTransferSize(arbChannelTransferSize),
    .arbitrate(arbitrate),
    .arb_ch_id(r_current_active_channel),

    // AXI Slave Interface
    .regFile_writeReady(!occupied),

    // CPU Interface
    .CPU_interrupt_CFG(CPU_interrupt_CFG),
    .CPU_interrupt_ch_done(CPU_interrupt_ch_done),
    .CPU_interrupt_end(CPU_interrupt_end),

    // Register File Interface
    .regFile_readEnable(regFile_readEnable2),
    .regFile_readAddr(regFile_readAddr2),
    .regFile_readData(regFile_readData2),

    .regFile_readEnable2(regFile_readEnable3),
    .regFile_readAddr2(regFile_readAddr3),
    .regFile_readData2(regFile_readData3),

    .regFile_writeEnable(regFile_writeEnable),
    .regFile_writeAddr(regFile_writeAddr),
    .regFile_writeData(regFile_writeData)
  );
   
    
    // FIFO Instantiations
    genvar i;
    generate    
     for (i = 0; i<C_M_NUM_CHANNELS; i=i+1) begin
        FIFO #(
        .FIFO_WIDTH(C_M_AXI_DATA_WIDTH),  // Set the FIFO width
        .FIFO_DEPTH(FIFO_DEPTH)   // Set the FIFO depth
        ) fifo_inst (
        .clk(AXI_aclk),                // Connect the clock signal
        .rst_n(AXI_aresetn),            // Connect the reset signal (active low)
        .wr_en(fifo_wr_en[i]),            // Connect the write enable signal
        .rd_en(fifo_rd_en[i]),            // Connect the read enable signal
        .data_in(fifo_wr_data),        // Connect the data input bus
        .data_out(fifo_rd_data[i]),      // Connect the data output bus
        .full(fifo_full[i]),              // Connect the full flag output
        .empty(fifo_empty[i]),             // Connect the empty flag output
        .wr_ack(wr_ack[i]),                //connect the write ack signal(oprional).
        .rd_ack(rd_ack[i])                  //connect the read ack signal(oprional).
        );
    end

endgenerate

// Instantiate the mux module
    mux #(
        .C_M_NUM_CHANNELS(C_NUM_CHANNELS),  // Set the number of channels
        .C_M_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH)
    ) mux_inst (
        .fifo_full(fifo_full),            // Connect fifo_full input array
        .fifo_empty(fifo_empty),          // Connect fifo_empty input array
        .wr_ack(wr_ack),                  // Connect wr_ack input array
        .rd_ack(rd_ack),                  // Connect rd_ack input array
        .fifo_rd_data(fifo_rd_data),      // Connect fifo_rd_data input array

        .m_fifo_full(m_fifo_full),        // Connect m_fifo_full output
        .m_fifo_empty(m_fifo_empty),      // Connect m_fifo_empty output
        .m_wr_ack(m_wr_ack),              // Connect m_wr_ack output
        .m_rd_ack(m_rd_ack),              // Connect m_rd_ack output
        .w_active_channel(w_current_active_channel),  // Connect active write channel
        .r_active_channel(r_current_active_channel),  // Connect active read channel
        .m_fifo_rd_data(m_fifo_rd_data)    // Connect master fifo read data
    );
/********************************************************************************************************/
    // Instantiation of the demux module
demux #(
    .C_M_NUM_CHANNELS(C_NUM_CHANNELS)  // Set the number of channels
) demux_inst (
    .fifo_wr_en(fifo_wr_en),             // Connect to fifo write enable output
    .fifo_rd_en(fifo_rd_en),             // Connect to fifo read enable output

    .m_fifo_wr_en(m_fifo_wr_en),         // Connect to master fifo write enable input
    .m_fifo_rd_en(m_fifo_rd_en),         // Connect to master fifo read enable input

    .w_active_channel(w_current_active_channel), // Connect to active write channel input
    .r_active_channel(r_current_active_channel)  // Connect to active read channel input
);

    // Multiplexing the write port:
    MUX2to1  #(1'b1) u_MUX2to1_writeEnable (.sel(occupied), .data_in1(regFile_writeEnable),.data_in2(sys_writeEnable), .data_out(mxd_regFile_writeEnable));
    MUX2to1  #(REGFILE_ADDR_WIDTH) u_MUX2to1_writeAddr  (.sel(occupied), .data_in1(regFile_writeAddr),.data_in2(sys_writeAddress), .data_out(mxd_regFile_writeAddr));
    MUX2to1  #(REGFILE_DATA_WIDTH) u_MUX2to1_writeData  (.sel(occupied), .data_in1(regFile_writeData),.data_in2(sys_writeData), .data_out(mxd_regFile_writeData));

endmodule
