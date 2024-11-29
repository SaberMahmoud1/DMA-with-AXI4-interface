package readChannel_FSM_pkg;

  // Define the states of the FSM
  typedef enum logic [2:0] {
    IDLE,   
    
    READ_TRANSACTION_DETAILS2,  
    
    CPU_INT,

    TRANSACTION_DONE,

    REARBITRATE
  } fsm_state_t; 
 
endpackage : readChannel_FSM_pkg


module readChannel_FSM #(
  parameter  C_M_AXI_ADDR_WIDTH = 8,
  parameter  REGFILE_ADDR_WIDTH = 8,
  parameter  REGFILE_DATA_WIDTH = 32,
  parameter  NUM_CHANNELS = 32,

  localparam MAX_STATE_HOLD = 2
)
(
  input AXI_aclk,
  input AXI_aresetn,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // Master Controller Interface

  output logic [C_M_AXI_ADDR_WIDTH-1:0] src_addr,                    
  output logic [1:0] burst_type,
  output logic [2:0] burst_size,
  output logic [8:0] beats,

  output logic start_read,

  input logic read_transaction_completed,
  // input logic read_resp_error,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // Arbitration FSM Interface

  input logic validChannels,
  input logic [31:0] activeChannels,
  input logic arbitrate,
  input req,
  output logic give,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // Arbiter Interface

  output  logic arbReadDone,

  input logic arbReadValid,
  input logic [8:0] arbReadBeats,
  input logic channelDone,
  input logic arbReadTransactionsDone,

  /**************************************************************************************************************/
  /**************************************************************************************************************/

  output logic regFile_readEnable,
  output logic [REGFILE_ADDR_WIDTH-1 : 0] regFile_readAddr,
  input  logic [REGFILE_DATA_WIDTH-1 : 0] regFile_readData
);

  // Import the FSM state definitions
  import readChannel_FSM_pkg::*;

  // State register
  fsm_state_t current_state, next_state;

  // First Transaction Valid
  logic firstTransaction;

  // Active Channel 
  logic [31:0] activeChannels_reg;
  logic [31:0] activeChannels_reg_iterative;
  logic [4:0]  currentActiveChannel;
  logic [4:0]  activeChannelsCount;
  logic loadChannels_0, loadChannels_1, loadChannels_2;
  logic getActive_0, getActive_1;

  /* Counter control signals*/
  logic stateCounterEnable; // Counter control signals
  logic [MAX_STATE_HOLD-1:0] stateCounter;
  logic load_value_enable;
  logic [1:0] load_value;

  // Instantiate a prioirty encoder
  priority_encoder u_priority_encoder (.in(activeChannels_reg_iterative), .out(currentActiveChannel));

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
        if (arbitrate) begin
          next_state = READ_TRANSACTION_DETAILS2;
          load_value_enable = 1;
          load_value = 1;
        end
      end

      READ_TRANSACTION_DETAILS2: begin
        stateCounterEnable = 1;
        if(stateCounter == 3) begin
          if(firstTransaction) begin
            load_value_enable = 1;
            load_value = 1;
            if(arbReadTransactionsDone) begin
              next_state = IDLE;
            end
            else begin
              next_state = READ_TRANSACTION_DETAILS2;
            end
          end
          else if(read_transaction_completed) begin
            next_state = TRANSACTION_DONE;
            load_value_enable = 1;
            load_value = 1;
          end
          else if(req) begin
            next_state = CPU_INT;
          end
          else begin
            stateCounterEnable = 0;
          end  
        end
      end

      CPU_INT: begin
        if(validChannels) begin
          next_state = READ_TRANSACTION_DETAILS2;
          load_value_enable = 1;
          load_value = 3;
        end
      end

      TRANSACTION_DONE: begin
        if(stateCounter == 2) begin
          if(arbReadTransactionsDone) begin
            next_state = IDLE;
            load_value_enable = 1;
            load_value = 0;
          end
          else begin
            next_state = READ_TRANSACTION_DETAILS2;
            load_value_enable = 1;
            load_value = 1;
          end
        end      
        else if((arbReadValid & (!channelDone)) | (channelDone & activeChannelsCount >1) | arbReadTransactionsDone) begin
          stateCounterEnable = 1;
        end
        else if(channelDone & activeChannelsCount <=1)begin
          next_state = REARBITRATE;
          load_value_enable = 1;
          load_value = 1;
        end
      end

      REARBITRATE: begin
        stateCounterEnable = 1;
        if(stateCounter == 2) begin
          next_state = READ_TRANSACTION_DETAILS2;
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
  
  // First Transaction //
  /*******************************************************************************/

  // The First Transaction flag 
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      firstTransaction <= 1'b1;
    end
    else if(start_read) begin
        firstTransaction <= 1'b0;
    end
    else if(next_state == IDLE)begin
      firstTransaction <= 1'b1;
    end
  end

  // Active Channels //
  /*******************************************************************************/

  // The ID of the active channel
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      activeChannels_reg_iterative <= 1'b0;
    end
    else if(validChannels) begin
      activeChannels_reg_iterative <= activeChannels;
    end
    else if(loadChannels_0 | loadChannels_1 | loadChannels_2) begin
      activeChannels_reg_iterative <= activeChannels_reg;
    end
    else if(((next_state == READ_TRANSACTION_DETAILS2 & firstTransaction & arbReadValid) | (current_state == TRANSACTION_DONE & arbReadValid)) & activeChannelsCount > 1) begin
      activeChannels_reg_iterative[currentActiveChannel] <= 0;
    end
  end

  assign loadChannels_0 = (next_state == READ_TRANSACTION_DETAILS2 & firstTransaction & arbReadValid) & activeChannelsCount <= 1;
  assign loadChannels_1 = (current_state == TRANSACTION_DONE & arbReadValid) & activeChannelsCount <= 1 & (next_state != REARBITRATE);
  assign loadChannels_2 = current_state == REARBITRATE & stateCounter == 1;

  // The current active channels, Given by the CFG FSM 
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      activeChannels_reg <= 1'b0;
    end
    else if(getActive_0) begin
      activeChannels_reg <= activeChannels;
    end
    else if(getActive_1) begin
      activeChannels_reg <= activeChannels | activeChannels_reg;
    end
    else if(channelDone) begin
      activeChannels_reg [currentActiveChannel] <= 0;
    end
  end  

  assign getActive_0 = validChannels & current_state == IDLE;
  assign getActive_1 = validChannels & current_state == CPU_INT;

  // The number of the active channels
  always_comb begin
    activeChannelsCount = '0;  // Initialize to zero

    // Use a for loop to iterate over the parameter NUM_CHANNELS
    for (int idx = 0; idx < NUM_CHANNELS; idx++) begin
      activeChannelsCount += activeChannels_reg_iterative[idx];
    end
  end

  // CFG FSM req //
  /*******************************************************************************/
  // Leave the RegFile ports

  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      give <= 1'b0;
    end
    else if(next_state == CPU_INT) begin
      give <= 1'b1;
    end
    else if(next_state == READ_TRANSACTION_DETAILS2) begin
      give <= 1'b0;
    end
  end  
  
  /*******************************************************************************/
  // REGFILE control signals
  
  // The address of the Register file
  always_comb begin
    regFile_readAddr = 0;
    if((current_state == IDLE & next_state == READ_TRANSACTION_DETAILS2) | (current_state == READ_TRANSACTION_DETAILS2 & stateCounter == 3 & firstTransaction) | (current_state == TRANSACTION_DONE & stateCounter == 2) | (current_state == REARBITRATE & stateCounter == 2)) begin
      // Get Channel configurations
      regFile_readAddr = currentActiveChannel * 4 + 1;
    end
    else if((current_state == READ_TRANSACTION_DETAILS2 & stateCounter == 1) ) begin
      // Get SRC address
      regFile_readAddr = currentActiveChannel * 4 + 3;
    end
  end

  assign regFile_readEnable = ((next_state == READ_TRANSACTION_DETAILS2 & stateCounter == 0) | (current_state == READ_TRANSACTION_DETAILS2 & (stateCounter == 0 | stateCounter == 1)) | (current_state == TRANSACTION_DONE & stateCounter == 2) | (current_state == REARBITRATE & stateCounter == 2)) ? 1'b1 : 1'b0; 

  // Output Logic to arbiter //
  /*******************************************************************************/

  // The arbReadDone signal
  assign arbReadDone = (current_state != TRANSACTION_DONE & next_state == TRANSACTION_DONE) ? 1'b1 : 1'b0 ;

  /*******************************************************************************/

  // Master Controller signals
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      burst_type <= 0;
      burst_size <= 0;
    end
    else if(current_state == READ_TRANSACTION_DETAILS2 & stateCounter == 1) begin
      burst_type <= regFile_readData [26:25];
      burst_size <= regFile_readData [24:22];
    end
  end
  
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      src_addr <= 0;
    end
    else if(current_state == READ_TRANSACTION_DETAILS2 & stateCounter == 2) begin
      src_addr <= regFile_readData;
    end
  end

  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      beats <= 0;
    end
    else if((current_state == READ_TRANSACTION_DETAILS2 & firstTransaction & arbReadValid) | (current_state == TRANSACTION_DONE & arbReadValid)) begin
      beats <= arbReadBeats;
    end
  end

  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      start_read <= 0;
    end
    else if(start_read) begin
      start_read <= 1'b0;
    end
    else if((current_state == READ_TRANSACTION_DETAILS2 & firstTransaction & stateCounter == 2) | (current_state == TRANSACTION_DONE & arbReadValid)) begin
      start_read <= 1'b1;
    end
  end
  
endmodule