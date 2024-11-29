/* This implementation saves a cycle for each active channel */

package control_unit_FSM_pkg;

  // Define the states of the FSM
  typedef enum logic [0:0] {
    ARBITRATION_FSM_PATH,   

    CHANNEL_FSM_PATH
  } fsm_state_t;

  // Define the mux select values
  typedef enum logic [0:0] {
    ARBITRATION_FSM,   

    CHANNEL_FSM
  } muxSel_t; 
 
endpackage : control_unit_FSM_pkg

module control_unit_FSM 
(
  input AXI_aclk,
  input AXI_aresetn,

  input CPU_interrupt_CFG,
  input CPU_interrupt_end,
  input arbitrate,

  input validChannels,
  input give1,
  input give2,

  output control_unit_FSM_pkg::muxSel_t muxSel1,
  output control_unit_FSM_pkg::muxSel_t muxSel2
);

  import control_unit_FSM_pkg::*;
  // State register
  fsm_state_t current_state, next_state;
  
  logic CPU_INT_first;
  
  // FSM
  /*******************************************************************************/

  // FSM sequential logic (state transition)
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn)
      current_state <= ARBITRATION_FSM_PATH;
    else
      current_state <= next_state;
  end

  // FSM combinational logic (next state logic)
  always_comb begin
    // Default assignments
    next_state = current_state;
    muxSel1 = ARBITRATION_FSM;
    muxSel2 = ARBITRATION_FSM;

    // FSM behavior
    case (current_state)
      ARBITRATION_FSM_PATH: begin
        muxSel1 = ARBITRATION_FSM;
        muxSel2 = ARBITRATION_FSM;
        if (arbitrate) begin
          next_state = CHANNEL_FSM_PATH;
          muxSel1    = CHANNEL_FSM;
          muxSel2    = CHANNEL_FSM;
        end
        else if(validChannels & CPU_INT_first) begin
          next_state = CHANNEL_FSM_PATH;
          muxSel1    = CHANNEL_FSM;
          muxSel2    = CHANNEL_FSM;
        end
      end

      CHANNEL_FSM_PATH: begin
        muxSel1 = CHANNEL_FSM;
        muxSel2 = CHANNEL_FSM;
        if (CPU_interrupt_CFG & !CPU_INT_first) begin
          next_state = ARBITRATION_FSM_PATH;
          muxSel1 = ARBITRATION_FSM;
          muxSel2 = ARBITRATION_FSM;
        end
        else if(give1 & give2) begin
          next_state = ARBITRATION_FSM_PATH;
          muxSel1 = ARBITRATION_FSM;
          muxSel2 = ARBITRATION_FSM;
        end
      end

      default: begin
        next_state = current_state;
        muxSel1 = ARBITRATION_FSM;
        muxSel2 = ARBITRATION_FSM;
      end
    endcase
  end
  
  // FSM sequential logic (state transition)
  always_ff @(posedge AXI_aclk or negedge AXI_aresetn) begin
    if (!AXI_aresetn)
      CPU_INT_first <= 1'b0;
    else if(arbitrate)
      CPU_INT_first <= 1'b1;
    else if(CPU_interrupt_end)
      CPU_INT_first <= 1'b0;
  end
  
endmodule