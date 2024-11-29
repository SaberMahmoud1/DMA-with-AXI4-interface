module calculate_beats_and_bursts#(
        // Custom parameters
    parameter integer C_NUM_CHANNELS                = 4,   // Number of channels to arbitrate
    parameter integer C_TRANSACTION_SIZE_WIDTH      = 32,   // Width for transaction size signal
    parameter integer C_PRIORITY_WIDTH                = 3,
    parameter integer C_FRAME_SIZE                  = 256  

) (
  input logic  active_channels [C_NUM_CHANNELS-1:0],
  input logic [C_PRIORITY_WIDTH-1:0] channels_priority [C_NUM_CHANNELS-1:0],
  input logic [C_TRANSACTION_SIZE_WIDTH-1:0] ch_transactions_sizes [C_NUM_CHANNELS-1:0],
  output logic [9-1:0] beats_of_channels [C_NUM_CHANNELS-1:0],
  output logic [C_TRANSACTION_SIZE_WIDTH-1:0] bursts_of_channels [C_NUM_CHANNELS-1:0],
  output logic [9-1:0] last_burst_beats_of_channels [C_NUM_CHANNELS-1:0]
);

  integer i;
  reg [9-1:0] base_beats;
  reg [9-1:0] remaining_beats;

  integer total_channels_priority;  // Sum of all active channels' priorities

always_comb begin : beats_burst_calculator
   // Calculate total priority
   total_channels_priority= 1'b0;

  for (i = 0; i < C_NUM_CHANNELS; i = i + 1) begin
    if (active_channels[i]) begin
      total_channels_priority = total_channels_priority + channels_priority[i];
    end
  end
  
  // Calculate base beats
  base_beats = (total_channels_priority == 0) ? 0 : (C_FRAME_SIZE / total_channels_priority);

  // Loop to calculate beats, bursts, and last burst beats
  for (i = C_NUM_CHANNELS -1 ; i >= 0; i = i - 1) begin
    if (active_channels[i]) begin
      beats_of_channels[i] = (base_beats*channels_priority[i] > 256) ? 256 : base_beats*channels_priority[i];
      bursts_of_channels[i] = ch_transactions_sizes[i] / beats_of_channels[i];
      remaining_beats = ch_transactions_sizes[i] % beats_of_channels[i];

      if (remaining_beats > 0) begin
        last_burst_beats_of_channels[i] = remaining_beats;
      end else begin
        last_burst_beats_of_channels[i] = 0;
      end
    end else begin
      beats_of_channels[i] = 0;
      bursts_of_channels[i] = 0;
      last_burst_beats_of_channels[i] = 0;
      remaining_beats = 'b0;
    end
  end 
end
  
endmodule