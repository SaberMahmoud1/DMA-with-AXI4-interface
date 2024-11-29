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

module mux #(
    parameter integer C_M_NUM_CHANNELS              = 4,
    parameter integer C_M_AXI_DATA_WIDTH            = 32
)(
    //fifos interface
    input  logic    fifo_full   [C_M_NUM_CHANNELS-1:0] ,  //fifo full indicator    
    input  logic    fifo_empty  [C_M_NUM_CHANNELS-1:0] ,  //fifo empty indicator
    input  logic    wr_ack      [C_M_NUM_CHANNELS-1:0] ,  //ack signal to make sure the write operations is done right.
    input  logic    rd_ack      [C_M_NUM_CHANNELS-1:0] ,  //ack signal to make sure the read operations is done right. 
    input  logic [C_M_AXI_DATA_WIDTH-1:0]         fifo_rd_data [C_M_NUM_CHANNELS-1:0],

    //master interface
    output  logic                                  m_fifo_full,  //the data to be written to the fifo
    output  logic                                  m_fifo_empty,  //the data to be read from the fifo
    output  logic                                  m_wr_ack,  //ack signal to make sure the write operations is done right.
    output  logic                                  m_rd_ack,  //ack signal to make sure the read operations is done right.
    input   logic [(`C_LOG_2(C_M_NUM_CHANNELS)):0] w_active_channel,  //the number of the write channel that is active now based on the arbitration
    input   logic [(`C_LOG_2(C_M_NUM_CHANNELS)):0] r_active_channel,  //the number of the read channel that is active now based on the arbitration
    output   logic [C_M_AXI_DATA_WIDTH-1:0]         m_fifo_rd_data
);

always_comb begin : mux_the_wr_ack
    m_wr_ack = 'b0;
    m_wr_ack = wr_ack[r_active_channel];
end

always_comb begin : mux_the_rd_ack
    m_rd_ack = 'b0;
    m_rd_ack = rd_ack[w_active_channel];
end

always_comb begin : mux_the_full_flag
    m_fifo_full = 'b0;
    m_fifo_full = fifo_full[r_active_channel];
end

always_comb begin : mux_the_empty_flag
    m_fifo_empty = 'b0;
    m_fifo_empty = fifo_empty[w_active_channel];
end

always_comb begin : mux_the_rd_data
    m_fifo_rd_data = 'b0;
    m_fifo_rd_data = fifo_rd_data[w_active_channel];
end
    
endmodule