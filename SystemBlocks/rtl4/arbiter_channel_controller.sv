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

module channel_controller#(
        // Custom parameters
    parameter integer C_NUM_CHANNELS                = 4,   // Number of channels to arbitrate
    parameter integer C_TRANSACTION_SIZE_WIDTH      = 32,   // Width for transaction size signal
    parameter integer C_PRIORITY_WIDTH                = 3,
    parameter integer C_FRAME_SIZE                  = 256  

) (
  input logic                               active_channels [C_NUM_CHANNELS-1:0],
  input logic  [`C_LOG_2(C_NUM_CHANNELS):0] current_active_channel,
  input logic                               transaction_completed,
  output logic [`C_LOG_2(C_NUM_CHANNELS):0] first_active_channel ,
  output logic [`C_LOG_2(C_NUM_CHANNELS):0] next_active_channel
  
);

reg found_first_channel;

reg found_next_channel;
reg [`C_LOG_2(C_NUM_CHANNELS):0] next_active_channel_r;

always_comb begin : first_channel_logic
    
    first_active_channel = 0;

 for (int i = C_NUM_CHANNELS-1 ; i >= 0 ; i = i - 1 ) begin
    if(active_channels[i])begin
        first_active_channel = i;
    end
 end
    
end

always_comb begin : next_channel_logic
    next_active_channel = 1'b0;

    for (int k = C_NUM_CHANNELS - 1 ;k >= 0 ; k = k - 1 ) begin
       if(active_channels[(current_active_channel + 1 + k) % C_NUM_CHANNELS])begin
        next_active_channel = (current_active_channel + 1 + k) % C_NUM_CHANNELS;
       end
    end
   end
    
endmodule