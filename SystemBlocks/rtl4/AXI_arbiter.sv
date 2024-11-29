//-----------------------------------------------------------------------------
// Title        : AXI Arbiter
// Project      : DMA with AXI4 Interface
//-----------------------------------------------------------------------------
// File         : AXI_arbiter.sv
// Author       : Saber Mahmoud
// Created      : [Date, September 9, 2024]
// Last Modified: [Date, September 10, 2024]
//-----------------------------------------------------------------------------
// Description  : 
//   This module implements an AXI Arbiter for distributing the available
//   bandwidth across multiple channels. The arbitration is done in a round-
//   robin fashion, with channel priority and transaction size determining
//   the number of beats allocated per channel. The module assigns a fixed 
//   number of beats per frame (default 256) and adjusts the beat allocation 
//   based on each channel's priority and transaction size. If a channel's 
//   transaction completes, the arbiter re-assigns beats to the remaining 
//   active channels.
//-----------------------------------------------------------------------------
// Structure    : 
//   - Active channels are selected via priority and the number of beats
//     needed for each transaction.
//   - Round-robin arbitration ensures fair access to all channels.
//   - Re-arbitration is triggered when a channel completes its transaction.
//-----------------------------------------------------------------------------
// Notes        : 
//   - The number of beats assigned is proportional to each channel's priority.
//   - Channels with zero priority are skipped in the arbitration cycle but
//     are still part of the round-robin frame structure.
//   - All channels should be sampled before the arbitration starts to ensure
//     correct priority and transaction size are considered.
//-----------------------------------------------------------------------------
// Parameters   : 
//   - C_NUM_CHANNELS: Number of AXI channels to arbitrate between.
//   - C_TRANSACTION_SIZE_WIDTH: Width of the transaction size signal.
//   - C_FRAME_SIZE: Total number of beats available per arbitration frame.
//-----------------------------------------------------------------------------
// Inputs       : 
//   - aclk: System clock signal.
//   - aresetn: Active-low asynchronous reset signal.
//   - channel_number: Identifies the current channel being processed.
//   - channel_priority: Defines the priority of each channel (3-bit).
//   - ch_transaction_size: Defines the transaction size for each channel.
//   - read_transaction_completed: Flag indicating read completion for a channel.
//   - sample_channel: High for one clock cycle to include a channel in arbitration.
//   - start_arbitration: Triggers arbitration when set high for one cycle.
//-----------------------------------------------------------------------------
// Outputs      : 
//   - r_beats_of_channel: Number of beats assigned to the current active channel.
//   - r_current_active_channel: Indicates which channel is currently active.
//   - r_data_valid: Signals when the output data from the arbiter is valid.
//-----------------------------------------------------------------------------

//Simple Log2 calculation function
`define C_LOG_2(n) (\
(n) <= (1<<0) ? 0 : (n) <= (1<<1) ? 1 :\
(n) <= (1<<2) ? 2 : (n) <= (1<<3) ? 3 :\
(n) <= (1<<4) ? 4 : (n) <= (1<<5) ? 5 :\
(n) <= (1<<6) ? 6 : (n) <= (1<<7) ? 7 :\
(n) <= (1<<8) ? 8 : (n) <= (1<<9) ? 9 :\
(n) <= (1<<10) ? 10 : (n) <= (1<<11) ? 11 :\
(n) <= (1<<12) ? 12 : (n) <= (1<<13) ? 13 :\
(n) <= (1<<14) ? 14 : (n) <= (1<<15) ? 15 :\
(n) <= (1<<16) ? 16 : (n) <= (1<<17) ? 17 :\
(n) <= (1<<18) ? 18 : (n) <= (1<<19) ? 19 :\
(n) <= (1<<20) ? 20 : (n) <= (1<<21) ? 21 :\
(n) <= (1<<22) ? 22 : (n) <= (1<<23) ? 23 :\
(n) <= (1<<24) ? 24 : (n) <= (1<<25) ? 25 :\
(n) <= (1<<26) ? 26 : (n) <= (1<<27) ? 27 :\
(n) <= (1<<28) ? 28 : (n) <= (1<<29) ? 29 :\
(n) <= (1<<30) ? 30 : (n) <= (1<<31) ? 31 : 32)

module arbiter #
  (
    // Custom parameters
    parameter integer C_NUM_CHANNELS                = 4,   // Number of channels to arbitrate
    parameter integer C_TRANSACTION_SIZE_WIDTH      = 32,   // Width for transaction size signal
    parameter integer C_PRIORITY_WIDTH                = 3,
    parameter integer C_FRAME_SIZE                  = 256  
  )
  (
    // System signals
    input wire                                  aclk,          // System clock
    input wire                                  aresetn,       // System reset, active-low
    
    // Main FSM interface
    input wire [`C_LOG_2(C_NUM_CHANNELS):0]     channel_number, // indicating the number of the channel being processed
    input wire [C_PRIORITY_WIDTH-1:0]           channel_priority, // Priority value of each channel (3 bits) valid values are 1,2,3,4,5,6,7 if zero the channel will not transfer any data but will take turn in the frame
    input wire [C_TRANSACTION_SIZE_WIDTH-1:0]   ch_transaction_size, // Transaction size for each channel (in beats)
    input wire                                  read_transaction_completed, //indicates when the read transaction completed to move to the next channel in the round robin
    input wire                                  write_transaction_completed, //indicates when the read transaction completed to move to the next channel in the round robin 

    input wire                                  sample_channel, //if this signal is high for one clock cycle the channel will be sambled and included in the arbitration
    input wire                                  start_arbitration,// Signal indicating when to start arbitration make it high for one clock cycle to start arbitration

    // Output signals
    output reg [9-1:0]                          r_beats_of_channel, // Number of beats for the current active channel
    output reg [9-1:0]                          w_beats_of_channel, // Number of beats for the current active channel
    output reg [`C_LOG_2(C_NUM_CHANNELS):0]     r_current_active_channel,  // Keeps track of the current active channel in round-robin
    output reg [`C_LOG_2(C_NUM_CHANNELS):0]     w_current_active_channel,  // Keeps track of the current active channel in round-robin
    output reg                                  r_data_valid,   //indicates when the data out of the arbiter starts to be valid
    output reg                                  r_transactions_done, //indicates when all the transactions are handled and no more transactions
    output reg                                  w_data_valid,   //indicates when the data out of the arbiter starts to be valid
    output reg                                  w_transactions_done, //indicates when all the transactions are handled and no more transactions
    output reg                                  r_re_arbitration,
    output reg                                  w_re_arbitration
  );

  // Internal integer variables for calculations
  reg [`C_LOG_2(C_NUM_CHANNELS):0] r_active_channels_count;
  reg [`C_LOG_2(C_NUM_CHANNELS):0] w_active_channels_count;

  //internal signal for storing data for read
  reg                                   r_active_channels                 [C_NUM_CHANNELS-1:0]; //reg to store each active channel number
  reg  [9-1:0]                          r_beats_of_channels               [C_NUM_CHANNELS-1:0]; //reg to store each active channel number of beats in each frame
  reg  [C_TRANSACTION_SIZE_WIDTH-1:0]   r_bursts_of_channels              [C_NUM_CHANNELS-1:0]; //reg to store each active channel number of nedded bursts to end the transaction
  reg  [9-1:0]                          r_last_burst_beats_of_channels    [C_NUM_CHANNELS-1:0]; // Remaining beats for the last burst in each channel equals zero if there is no remaining

  //for write
  reg                                   w_active_channels                 [C_NUM_CHANNELS-1:0]; //reg to store each active channel number
  reg  [9-1:0]                          w_beats_of_channels               [C_NUM_CHANNELS-1:0]; //reg to store each active channel number of beats in each frame
  reg  [C_TRANSACTION_SIZE_WIDTH-1:0]   w_bursts_of_channels              [C_NUM_CHANNELS-1:0]; //reg to store each active channel number of nedded bursts to end the transaction
  reg  [9-1:0]                          w_last_burst_beats_of_channels    [C_NUM_CHANNELS-1:0]; // Remaining beats for the last burst in each channel equals zero if there is no remaining

  reg [`C_LOG_2(C_NUM_CHANNELS):0]       r_next_channel;                      //reg to store the number of the channel to be active next
  reg                            r_found_active_channel;                                   //flag used to brake out of a loop 
  reg [`C_LOG_2(C_FRAME_SIZE):0] r_beats_of_channels_r;

  reg [`C_LOG_2(C_NUM_CHANNELS):0] w_next_channel;                      //reg to store the number of the channel to be active next
  reg w_found_active_channel;                                   //flag used to brake out of a loop 
  reg [`C_LOG_2(C_FRAME_SIZE):0] w_beats_of_channels_r;

  //global
  reg  [C_PRIORITY_WIDTH-1:0]           channels_priority                 [C_NUM_CHANNELS-1:0]; //reg to store each active channel priority
  reg  [C_TRANSACTION_SIZE_WIDTH-1:0]   r_ch_transactions_sizes           [C_NUM_CHANNELS-1:0]; //reg to store each active channel treansaction size

  reg  [C_TRANSACTION_SIZE_WIDTH-1:0]   w_ch_transactions_sizes           [C_NUM_CHANNELS-1:0]; //reg to store each active channel treansaction size

  reg [`C_LOG_2(C_NUM_CHANNELS):0] r_first_active_channel;
  reg [`C_LOG_2(C_NUM_CHANNELS):0] w_first_active_channel;
  
  /********************************************************************************/
    //instantiate beats counter
  /*********************************************************************************/

  calculate_beats_and_bursts #(
        .C_NUM_CHANNELS(C_NUM_CHANNELS),
        .C_TRANSACTION_SIZE_WIDTH(C_TRANSACTION_SIZE_WIDTH),
        .C_PRIORITY_WIDTH(C_PRIORITY_WIDTH),
        .C_FRAME_SIZE(C_FRAME_SIZE)
  ) r_calculate_beats_and_bursts (
        .active_channels(r_active_channels),
        .channels_priority(channels_priority),
        .ch_transactions_sizes(r_ch_transactions_sizes),
        .beats_of_channels(r_beats_of_channels),
        .bursts_of_channels(r_bursts_of_channels),
        .last_burst_beats_of_channels(r_last_burst_beats_of_channels)
    );

    calculate_beats_and_bursts #(
        .C_NUM_CHANNELS(C_NUM_CHANNELS),
        .C_TRANSACTION_SIZE_WIDTH(C_TRANSACTION_SIZE_WIDTH),
        .C_PRIORITY_WIDTH(C_PRIORITY_WIDTH),
        .C_FRAME_SIZE(C_FRAME_SIZE)
    ) w_calculate_beats_and_bursts (
        .active_channels(w_active_channels),
        .channels_priority(channels_priority),
        .ch_transactions_sizes(w_ch_transactions_sizes),
        .beats_of_channels(w_beats_of_channels),
        .bursts_of_channels(w_bursts_of_channels),
        .last_burst_beats_of_channels(w_last_burst_beats_of_channels)
    );

    // Instantiate the channel_controller module
channel_controller #(
    .C_NUM_CHANNELS(C_NUM_CHANNELS),               // Number of channels to arbitrate
    .C_TRANSACTION_SIZE_WIDTH(C_TRANSACTION_SIZE_WIDTH), // Width for transaction size signal
    .C_PRIORITY_WIDTH(C_PRIORITY_WIDTH),            // Priority width for channels
    .C_FRAME_SIZE(C_FRAME_SIZE)                     // Frame size (default 256)
) r_channel_controller_inst (
    .active_channels(r_active_channels),             // Connect to active channels input
    .current_active_channel(r_current_active_channel), // Connect to current active channel
    .transaction_completed(read_transaction_completed), // Connect to transaction completed signal
    .first_active_channel(r_first_active_channel),   // Output first active channel
    .next_active_channel(r_next_channel)      // Output next active channel
);

// Instantiate the channel_controller module
channel_controller #(
    .C_NUM_CHANNELS(C_NUM_CHANNELS),               // Number of channels to arbitrate
    .C_TRANSACTION_SIZE_WIDTH(C_TRANSACTION_SIZE_WIDTH), // Width for transaction size signal
    .C_PRIORITY_WIDTH(C_PRIORITY_WIDTH),            // Priority width for channels
    .C_FRAME_SIZE(C_FRAME_SIZE)                     // Frame size (default 256)
) w_channel_controller_inst (
    .active_channels(w_active_channels),             // Connect to active channels input
    .current_active_channel(w_current_active_channel), // Connect to current active channel
    .transaction_completed(write_transaction_completed), // Connect to transaction completed signal
    .first_active_channel(w_first_active_channel),   // Output first active channel
    .next_active_channel(w_next_channel)      // Output next active channel
);
  
  /*********************************************************************************************************************************/
  //read arbitration
  /*********************************************************************************************************************************/
  // Always block triggered on clock edge or reset (asynchronous reset)
  always_ff @(posedge aclk, negedge aresetn) begin
    if (!aresetn) begin
      // Reset all internal and output values
      r_active_channels_count <= 1'b0;
      r_re_arbitration <= 1'b0;
      r_transactions_done <= 1'b0;
    end 
    else if(sample_channel)begin
      r_active_channels       [channel_number] <= 1'b1;
      channels_priority     [channel_number] <= channel_priority;
      r_ch_transactions_sizes [channel_number] <= ch_transaction_size;
      r_transactions_done <= 1'b0;
      r_active_channels_count <= r_active_channels_count + 1;
    end else if (start_arbitration  && r_active_channels_count != 1'b0 ) begin
      r_transactions_done <= 1'b0;
      r_current_active_channel <= r_first_active_channel;
      if(r_bursts_of_channels[r_first_active_channel] > 0)begin
      r_beats_of_channel <= r_beats_of_channels[w_first_active_channel];
      r_ch_transactions_sizes[r_first_active_channel] <= r_ch_transactions_sizes[r_first_active_channel] - r_beats_of_channels[r_first_active_channel];
      end else begin
      r_beats_of_channel <= r_last_burst_beats_of_channels[r_first_active_channel];
      r_active_channels[r_first_active_channel] <= 1'b0;
      r_active_channels_count<=r_active_channels_count-1;
      r_ch_transactions_sizes[r_first_active_channel] <= r_ch_transactions_sizes[r_first_active_channel] - r_last_burst_beats_of_channels[r_first_active_channel];
      r_re_arbitration <= 1'b1;
      if(r_active_channels_count ==1)begin
          r_transactions_done <= 1;
        end else begin
          r_transactions_done <= 0;
        end
      end
      r_data_valid <= 1'b1;
    end else if(read_transaction_completed) begin
      r_ch_transactions_sizes[r_next_channel] <= r_ch_transactions_sizes[r_next_channel] - r_beats_of_channels[r_next_channel];
      r_current_active_channel <= r_next_channel;
      if(r_ch_transactions_sizes[r_next_channel] <= r_beats_of_channels[r_next_channel])begin
        r_beats_of_channel <= r_last_burst_beats_of_channels [r_next_channel];
        r_active_channels[r_next_channel]<= 0;
        r_active_channels_count<=r_active_channels_count-1;
        r_re_arbitration <= 1'b1;
        if(r_active_channels_count ==1)begin
          r_transactions_done <= 1;
        end else begin
          r_transactions_done <= 0;
        end
        if(r_last_burst_beats_of_channels [r_next_channel] == 0)begin
          r_data_valid <= 0;
        end else begin
          r_data_valid <= 1;
        end
      end else begin
        r_beats_of_channel <= r_beats_of_channels [r_next_channel];
        r_data_valid <= 1;
      end
    end else begin
      r_data_valid <= 1'b0;
      r_re_arbitration <= 1'b0;
    end
  end

  /*********************************************************************************************************************************/
  //write arbitration
  /*********************************************************************************************************************************/
  // Always block triggered on clock edge or reset (asynchronous reset)
  always_ff @(posedge aclk, negedge aresetn) begin
    if (!aresetn) begin
      // Reset all internal and output values
      w_active_channels_count <= 1'b0;
      w_re_arbitration <= 1'b0;
      w_transactions_done <= 1'b0;
    end 
    else if(sample_channel)begin
      w_active_channels       [channel_number] <= 1'b1;
      w_ch_transactions_sizes [channel_number] <= ch_transaction_size;
      w_active_channels_count <= w_active_channels_count + 1;
      w_transactions_done <= 1'b0;

    end else if (start_arbitration && w_active_channels_count != 1'b0 ) begin
      
      w_transactions_done <= 1'b0;
      w_current_active_channel <= w_first_active_channel;
      if(w_bursts_of_channels[w_first_active_channel] > 0)begin
      w_beats_of_channel <= w_beats_of_channels[w_first_active_channel];
      w_ch_transactions_sizes[w_first_active_channel] <= w_ch_transactions_sizes[w_first_active_channel] - w_beats_of_channels[w_first_active_channel];
      end else begin
      w_beats_of_channel <= w_last_burst_beats_of_channels[w_first_active_channel];
      w_active_channels[w_first_active_channel] <= 1'b0;
      w_active_channels_count<=w_active_channels_count-1;
      w_re_arbitration <= 1'b1;
      w_ch_transactions_sizes[w_first_active_channel] <= w_ch_transactions_sizes[w_first_active_channel] - w_last_burst_beats_of_channels[w_first_active_channel];
      if(w_active_channels_count ==1)begin
          w_transactions_done <= 1;
        end else begin
          w_transactions_done <= 0;
        end
      end
      w_data_valid <= 1'b1;
    end else if(write_transaction_completed) begin

      w_ch_transactions_sizes[w_next_channel] <= w_ch_transactions_sizes[w_next_channel] - w_beats_of_channels[w_next_channel];
  
      w_current_active_channel <= w_next_channel;
      if(w_ch_transactions_sizes[w_next_channel] <= w_beats_of_channels[w_next_channel])begin
        w_beats_of_channel <= w_last_burst_beats_of_channels [w_next_channel];
        w_active_channels[w_next_channel]<= 0;
        w_active_channels_count<=w_active_channels_count-1;
        w_re_arbitration <= 1'b1;
        if(w_active_channels_count ==1)begin
          w_transactions_done <= 1;
        end else begin
          w_transactions_done <= 0;
        end
        if(w_last_burst_beats_of_channels [w_next_channel] == 0)begin
          w_data_valid <= 0;
        end else begin
          w_data_valid <= 1;
        end
      end else begin
        w_beats_of_channel <= w_beats_of_channels [w_next_channel];
        w_data_valid <= 1'b1;
      end
    end else begin
      w_data_valid <= 1'b0;
      w_re_arbitration <= 1'b0;
    end
  end


endmodule


