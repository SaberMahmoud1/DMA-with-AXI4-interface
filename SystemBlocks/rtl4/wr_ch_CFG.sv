/* This implementation saves a cycle for each active channel */

package wr_ch_CFG_pkg;

  // Define the states of the FSM
  typedef enum logic [1:0] {
    IDLE,   

    ACTIVE_CHANNELS,

    WAIT4_CHANNEL_FSM,

    UPDATE_ACTIVE_CHANNELS
  } fsm_state_t; 
 
endpackage : wr_ch_CFG_pkg


module wr_ch_CFG #(
  parameter  REGFILE_ADDR_WIDTH = 8,
  parameter  REGFILE_DATA_WIDTH = 32,

  localparam MAX_STATE_HOLD = 2
)
(
  input AXI_aclk,
  input AXI_aresetn,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // CPU interface

  input logic CPU_interrupt_end,
  output logic CPU_interrupt_ch_done,
  
  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // Arbiter Interface

  input  logic [5:0]  ch_id,
  input  logic ch_done,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // rd_ch_CFG FSM Interface
  
  input  logic [31:0] ActiveChannels,
  input  logic  validChannels,

  /**************************************************************************************************************/
  /**************************************************************************************************************/
  // RegFile interface

  output logic regFile_writeEnable,
  output logic [REGFILE_ADDR_WIDTH-1 : 0] regFile_writeAddr,
  output logic [REGFILE_DATA_WIDTH-1 : 0] regFile_writeData,

  // Is the Register file being accessed?
  input  logic regFile_writeReady
);

  // Import the FSM state definitions
  import wr_ch_CFG_pkg::*;

  // State register
  fsm_state_t current_state, next_state;

  logic ch_done_reg;
  //logic ActiveChannels_reg;

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

    // FSM behavior
    case (current_state)
      IDLE: begin
        if (validChannels) begin
          next_state = ACTIVE_CHANNELS;
        end
      end

      ACTIVE_CHANNELS: begin
        if((ch_done | ch_done_reg) & regFile_writeReady) begin
          next_state = UPDATE_ACTIVE_CHANNELS;
        end
        else begin
          next_state = WAIT4_CHANNEL_FSM;
        end
      end

      WAIT4_CHANNEL_FSM: begin
        if(CPU_interrupt_end) begin
          next_state = IDLE;
        end
        else if(validChannels) begin
          next_state = ACTIVE_CHANNELS;
        end
        else if(ch_done & regFile_writeReady) begin
          next_state = UPDATE_ACTIVE_CHANNELS;
        end
      end

      UPDATE_ACTIVE_CHANNELS: begin
        if(validChannels) begin
          next_state = ACTIVE_CHANNELS;     
        end
        else begin
          next_state = WAIT4_CHANNEL_FSM;
        end
      end

      default: begin
        next_state = current_state;
      end
    endcase
  end
  
  // Data Coherency flag //
  /*******************************************************************************/
  
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      ch_done_reg <= 'b0;
    end
    else if(next_state == UPDATE_ACTIVE_CHANNELS) begin
      ch_done_reg <= 'b0;
    end
    else if(ch_done)
    ch_done_reg <= 'b1;
  end

  // REGFILE control signals //
  /*******************************************************************************/

  assign regFile_writeAddr = '0;
  
  assign regFile_writeEnable  = (current_state == UPDATE_ACTIVE_CHANNELS);

  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) begin
      regFile_writeData <= '0;
    end
    else if(next_state == ACTIVE_CHANNELS) begin
      regFile_writeData <= ActiveChannels | regFile_writeData;
    end
    else if(ch_done) begin
      regFile_writeData[ch_id] <= 1'b0;
    end
  end

  //always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
  //  if (!AXI_aresetn) begin
  //    ActiveChannels_reg <= '0;
  //  end
  //  else if(validChannels) begin
  //    ActiveChannels_reg <= ActiveChannels;
  //  end
  //  else if(next_state == IDLE) begin
  //    ActiveChannels_reg <= '0;
  //  end
  //end

  // CPU control signals //
  /*******************************************************************************/

  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn) 
      CPU_interrupt_ch_done <= 1'b0;
    else if(CPU_interrupt_ch_done)
      CPU_interrupt_ch_done <= 1'b0;
    else if(current_state == UPDATE_ACTIVE_CHANNELS)
      CPU_interrupt_ch_done <= 1'b1;
  end 
  
endmodule
