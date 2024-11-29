/* This implementation saves a cycle for each active channel */

package rd_ch_CFG_pkg;

  // Define the states of the FSM
  typedef enum logic [2:0] {
    IDLE,   

    ACTIVE_CHANNELS,
    CHANNEL_DETAILS, 

    SLEEP,

    WAIT4ACCESS
  } fsm_state_t; 
 
endpackage : rd_ch_CFG_pkg


module rd_ch_CFG_FSM #(
  parameter  REGFILE_ADDR_WIDTH = 8,
  parameter  REGFILE_DATA_WIDTH = 32,
  parameter  NUM_CHANNELS =32,

  localparam MAX_STATE_HOLD = 2
)
(
  input AXI_aclk,
  input AXI_aresetn,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // CPU interface

  input  CPU_interrupt_CFG,
  output logic CPU_interrupt_end,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // Arbiter Interface
  output  logic arbSample,
  // Extra bit for the arbiter
  output  logic [5:0]  arbCurrentChannelSample,
  output  logic [3:0]  arbChannelPriority,
  output  logic [31:0] arbChannelTransferSize,
  output  logic arbitrate,

  input logic arbWriteTransactionsDone,

  input  logic [5:0]  ch_id,
  input  logic ch_done,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // Channel FSM Interface
  output  logic [31:0] chActiveChannels,
  output  logic  chValidChannels,
  output  logic  req1,
  output  logic  req2,
  input  logic  give1,
  input  logic  give2,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // RegFile interface

  output logic regFile_readEnable,
  output logic [REGFILE_ADDR_WIDTH-1 : 0] regFile_readAddr,
  input  logic [REGFILE_DATA_WIDTH-1 : 0] regFile_readData,

  output logic regFile_readEnable2,
  output logic [REGFILE_ADDR_WIDTH-1 : 0] regFile_readAddr2,
  input  logic [REGFILE_DATA_WIDTH-1 : 0] regFile_readData2
);

  // Import the FSM state definitions
  import rd_ch_CFG_pkg::*;

  // State register
  fsm_state_t current_state, next_state;

  // Each bit denotes to an active channel
  logic [31:0] prevState;  
  logic [31:0] activeChannels;
  logic [31:0] activeChannels_s2;
  logic [4:0]  activeChannelsCount;
  logic [4:0]  currentActiveChannel;
  logic [4:0]  currentActiveChannel_s2;

  // Flag to denote that the DMA is starting from IDLE
  logic strt_engine;
  logic [31:0] newChannel;

  /* Counter control signals*/
  logic stateCounterEnable; // Counter control signals
  logic [MAX_STATE_HOLD-1:0] stateCounter;
  logic load_value_enable;
  logic [MAX_STATE_HOLD-1:0] load_value;

  // Instantiate a prioirty encoder
  priority_encoder u_priority_encoder1 (.in(activeChannels), .out(currentActiveChannel));
  priority_encoder u_priority_encoder2 (.in(activeChannels_s2), .out(currentActiveChannel_s2));

  // Instantiate a counter for states
  counter #(
    .WIDTH(MAX_STATE_HOLD)
  ) u_stateCounter (
      .clk(AXI_aclk),                
      .resetn(AXI_aresetn),           
      .enable(stateCounterEnable),    
      .add_enable(1'b0),                      // Connect add_enable signal            (control)
      .add_value({MAX_STATE_HOLD{1'b0}}),     // Connect the arbitrary value to add   (constant)
      .load_value_enable(load_value_enable),  // Connect the load_value_enable signal (control)
      .load_value(load_value),                // Connect the load_value signal        (constant)
      .count(stateCounter)             
  );

  // FSM
  /*******************************************************************************/

  // FSM sequential logic (state transition)
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn)
      current_state <= IDLE;
    else
      current_state <= next_state;
  end

  // FSM combinational logic (next state logic)
  always_comb begin
    // Default assignments
    next_state = current_state;
    stateCounterEnable = 0;
    load_value_enable = 0;
    load_value = 0;

    // FSM behavior
    case (current_state)
      IDLE: begin
        if (CPU_interrupt_CFG) begin
          next_state = ACTIVE_CHANNELS;
          stateCounterEnable = 1;
        end
      end

      ACTIVE_CHANNELS: begin
        stateCounterEnable = 1;
        if(stateCounter == 2) begin
          next_state = CHANNEL_DETAILS;
          load_value_enable = 1;
          load_value = 1;
        end
      end

      CHANNEL_DETAILS: begin
        if(stateCounter !=2) begin
          stateCounterEnable = 1;
        end
        if(activeChannelsCount == 0) begin
          next_state = SLEEP;
          load_value_enable = 1;
          load_value = 0;   
        end
      end

      SLEEP: begin
        if(arbWriteTransactionsDone) begin
          next_state = IDLE;
        end
        if(CPU_interrupt_CFG) begin
          next_state = WAIT4ACCESS;
        end
      end

      WAIT4ACCESS: begin
        if(give1 & give2) begin
          next_state = ACTIVE_CHANNELS;
          load_value_enable = 1;
          load_value = 1;
        end
      end

      default: begin
        next_state = current_state;
        stateCounterEnable = 0;
        load_value_enable = 0;
        load_value = 0;
      end
    endcase
  end
  
  // Active Channels //
  /*******************************************************************************/

  // The ID of the active channel
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      activeChannels <= '0;
      activeChannels_s2 <= '0;
      newChannel <= '0;
    end
    else if(current_state == ACTIVE_CHANNELS & stateCounter == 1) begin
      // That's the masking technique for detecting the new added channels
      activeChannels <= regFile_readData & ~prevState;
      newChannel <= regFile_readData & ~prevState;
    end
    else if(next_state == CHANNEL_DETAILS) begin
      activeChannels[currentActiveChannel] <= 0;
      // activeChannels_s2 is delayed by one cycle to send the correct channel to the arbiter 
      activeChannels_s2 <= activeChannels;
    end
    else if(current_state == IDLE) begin
      // Reset everything
      activeChannels <= '0;
      activeChannels_s2 <= '0;
    end
  end

  // The number of the active channels
  always_comb begin
    activeChannelsCount = '0;  // Initialize to zero

    // Use a for loop to iterate over the parameter NUM_CHANNELS
    for (int idx = 0; idx < NUM_CHANNELS; idx++) begin
      activeChannelsCount += activeChannels[idx];
    end
  end

  // Keep track of the finished channels for the previous state
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      prevState <= '0;
    end
    else if((current_state == ACTIVE_CHANNELS & stateCounter == 1) & !strt_engine) begin
      prevState <= regFile_readData;
    end
    else if(next_state == SLEEP & current_state != SLEEP & strt_engine) begin
      prevState <= prevState | newChannel;
    end
    else if(ch_done) begin
      prevState[ch_id] <= 1'b0;
    end
  end
  
  // REGFILE control signals //
  /*******************************************************************************/

  // The address of the Register file for PORT1
  always_comb begin
    regFile_readAddr = 0;
    if((current_state == IDLE | current_state == WAIT4ACCESS) & (next_state == ACTIVE_CHANNELS)) begin
      regFile_readAddr = 0;
    end
    else if((current_state == ACTIVE_CHANNELS & stateCounter == 2) | (current_state == CHANNEL_DETAILS)) begin
      // Get Channel Priority
      regFile_readAddr = currentActiveChannel * 4 + 1;
    end 
  end

  // The address of the Register file for PORT2
  always_comb begin
    regFile_readAddr2 = 0;
    if((current_state == ACTIVE_CHANNELS & stateCounter == 2) | (current_state == CHANNEL_DETAILS)) begin
      // Get Channel Transaction Count
      regFile_readAddr2 = currentActiveChannel * 4 + 2;
    end
  end

  // The read enable of the register file
  assign regFile_readEnable  = (((current_state == IDLE | current_state == WAIT4ACCESS) & next_state == ACTIVE_CHANNELS) | (current_state == ACTIVE_CHANNELS &  stateCounter == 2 ) | (current_state == CHANNEL_DETAILS & next_state != SLEEP)) ? 1'b1 : 1'b0;
  assign regFile_readEnable2 = ((current_state == ACTIVE_CHANNELS &  stateCounter == 2) | (current_state == CHANNEL_DETAILS & next_state != SLEEP)) ? 1'b1 : 1'b0; 

  // Output Logic to arbiter //
  /*******************************************************************************/
  
  // Capture the channel priority 
  always_ff@(posedge AXI_aclk or negedge AXI_aresetn ) begin
    if(~AXI_aresetn) begin
      arbChannelPriority <= 0;
    end
    else if(current_state == CHANNEL_DETAILS & (stateCounter == 1 | stateCounter == 2)) begin
      arbChannelPriority <= regFile_readData[2:0];
    end
  end

  // Capture the channel transfer size
  always_ff@(posedge AXI_aclk or negedge AXI_aresetn ) begin
    if(~AXI_aresetn) begin
      arbChannelTransferSize <= 0;
    end
    else if(current_state == CHANNEL_DETAILS & (stateCounter == 1 | stateCounter == 2)) begin
      // We communicate the transfer size of the channel in beats, each #beats = transferSizeInBytes/burstSizeInBytes
      arbChannelTransferSize <= regFile_readData2 / 4;
    end
  end

  // Send the sampled channel ID
  always_ff@(posedge AXI_aclk or negedge AXI_aresetn ) begin
    if(~AXI_aresetn) begin
      arbCurrentChannelSample <= 0;
    end
    else if(current_state == CHANNEL_DETAILS & (stateCounter == 1 | stateCounter == 2)) begin
      arbCurrentChannelSample <= currentActiveChannel_s2;
    end
  end

  // The sample channel signal
  always_ff@(posedge AXI_aclk or negedge AXI_aresetn ) begin
    if(~AXI_aresetn) begin
      arbSample <= 1'b0;
    end
    else if(current_state == CHANNEL_DETAILS & (stateCounter == 1 | stateCounter == 2)) begin
      arbSample <= 1'b1;
    end
    else if(current_state == SLEEP) begin
      arbSample <= 1'b0;
    end
  end

  // The arbitrate signal
  always_ff@(posedge AXI_aclk or negedge AXI_aresetn ) begin
    if(~AXI_aresetn) begin
      arbitrate <= 1'b0;
      strt_engine <= 0;
    end
    // Pulsed
    else if(arbitrate) begin
      arbitrate <= 1'b0;
    end
    // Should be sent along with the transferSize
    else if(!strt_engine & (current_state == SLEEP)) begin
      arbitrate <= 1'b1;
      strt_engine <= 1;
    end
    else if(next_state == IDLE) begin
      strt_engine <= 0;
    end
  end

  
  // Channel FSM Control //
  /*******************************************************************************/

  // The ID of the active channel
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      chActiveChannels <= '0;
      chValidChannels  <= 1'b0;
    end
    else if((current_state == ACTIVE_CHANNELS & stateCounter == 1) & !strt_engine) begin
      chActiveChannels <= regFile_readData;
      chValidChannels  <= 1'b1;
    end
    else if (next_state == SLEEP & current_state != SLEEP & strt_engine) begin
      chActiveChannels <= newChannel;
      chValidChannels  <= 1'b1;
    end
    else begin
      chActiveChannels <= '0;
      chValidChannels  <= 1'b0;
    end
  end

  assign req1 = (next_state == WAIT4ACCESS & ~give1);
  assign req2 = (next_state == WAIT4ACCESS & ~give2);

  /*******************************************************************************/

  // CPU Intrrupt
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) 
      CPU_interrupt_end <= 1'b0;
    else if(CPU_interrupt_end)
      CPU_interrupt_end <=  1'b0;
    else if((current_state == SLEEP) & (next_state == IDLE))
      CPU_interrupt_end <= 1'b1;
  end 
  
endmodule
