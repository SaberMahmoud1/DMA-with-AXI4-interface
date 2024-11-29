//-----------------------------------------------------------------------------
// Title        : AXI Master
// Project      : part of DMA with AXI4 interface
//-----------------------------------------------------------------------------
// File         : AXI_M_C.sv
// Author       : Saber Mahmoud
// Created      : [Date, August 23, 2024]
// Last Modified: [Date, August 25, 2024]
//-----------------------------------------------------------------------------
// Description  : 
//   This module implements an AXI Master interface that handles read and write
//   transactions over the AXI bus. The design includes state machines for 
//   managing the AXI protocol for both read and write channels, ensuring data
//   integrity and proper handshaking with AXI-compliant slave devices.
//-----------------------------------------------------------------------------
// Structure    : 
//   - RIDLE: Idle state for read channel
//   - READ_ADDR: Address phase for read transactions
//   - READ_DATA: Data phase for read transactions
//   - RWAIT_ACK: another Data phase for read transactions
//   - WIDLE: Idle state for write channel
//   - WRITE_ADDR: Address phase for write transactions
//   - WRITE_DATA: Data phase for write transactions
//   - WRITE_DATAA: another Data phase for write transactions
//   - WWAIT_RESP: Waiting for response phase in write transactions
//-----------------------------------------------------------------------------
// Notes        : 
//   - Ensure that all signal connections are correctly mapped to the AXI bus.
//   - The module handles both burst and single transactions.
//   - Error handling is implemented for AXI protocol compliance.
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

module AXI_master_controller #
  (
    parameter integer C_M_AXI_THREAD_ID_WIDTH       = 1,
    parameter integer C_M_AXI_ADDR_WIDTH            = 32,
    parameter integer C_M_AXI_DATA_WIDTH            = 32,
    parameter integer C_M_AXI_AWUSER_WIDTH          = 1,
    parameter integer C_M_AXI_ARUSER_WIDTH          = 1,
    parameter integer C_M_AXI_WUSER_WIDTH           = 1,
    parameter integer C_M_AXI_RUSER_WIDTH           = 1,
    parameter integer C_M_AXI_BUSER_WIDTH           = 1,
    parameter integer C_M_NUM_CHANNELS              = 4
	  
   )
   (
    // System Signals
    input wire 	      aclk,
    input wire 	      aresetn,
    
    // Master Interface Write Address
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] m_axi_awid,
    output reg [C_M_AXI_ADDR_WIDTH-1:0]      m_axi_awaddr,
    output wire [8-1:0] 			 m_axi_awlen,
    output wire [3-1:0] 			 m_axi_awsize,
    output reg [2-1:0] 			 m_axi_awburst,
    output wire 				 m_axi_awlock,
    output wire [4-1:0] 			 m_axi_awcache,
    output wire [3-1:0] 			 m_axi_awprot,
    // AXI3 output wire [4-1:0]                  M_AXI_AWREGION,
    output wire [4-1:0] 			 m_axi_awqos,
    output wire [C_M_AXI_AWUSER_WIDTH-1:0] 	 m_axi_awuser,
    output reg 				 m_axi_awvalid,
    input  wire 				 m_axi_awready,
    
    // Master Interface Write Data
    // AXI3 output wire [C_M_AXI_THREAD_ID_WIDTH-1:0]     M_AXI_WID,
    output reg [C_M_AXI_DATA_WIDTH-1:0] 	 m_axi_wdata,
    output reg [C_M_AXI_DATA_WIDTH/8-1:0] 	 m_axi_wstrb,
    output reg 				 m_axi_wlast,
    output wire [C_M_AXI_WUSER_WIDTH-1:0] 	 m_axi_wuser,
    output reg 				 m_axi_wvalid,
    input  wire 				 m_axi_wready,
    
    // Master Interface Write Response
    input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] 	 m_axi_bid,
    input  wire [2-1:0] 			 m_axi_bresp,
    input  wire [C_M_AXI_BUSER_WIDTH-1:0] 	 m_axi_buser,
    input  wire 				 m_axi_bvalid,
    output reg 				 m_axi_bready,
    
    // Master Interface Read Address
    output wire [C_M_AXI_THREAD_ID_WIDTH-1:0] 	 m_axi_arid,
    output reg [C_M_AXI_ADDR_WIDTH-1:0] 	 m_axi_araddr,
    output wire [8-1:0] 			 m_axi_arlen,
    output wire [3-1:0] 			 m_axi_arsize,
    output reg [2-1:0] 			 m_axi_arburst,
    output wire [2-1:0] 			 m_axi_arlock,
    output wire [4-1:0] 			 m_axi_arcache,
    output wire [3-1:0] 			 m_axi_arprot,
    // AXI3 output wire [4-1:0] 		 M_AXI_ARREGION,
    output wire [4-1:0] 			 m_axi_arqos,
    output wire [C_M_AXI_ARUSER_WIDTH-1:0] 	 m_axi_aruser,
    output reg 				 m_axi_arvalid,
    input  wire 				 m_axi_arready,
    
    // Master Interface Read Data 
    input  wire [C_M_AXI_THREAD_ID_WIDTH-1:0] 	 m_axi_rid,
    input  wire [C_M_AXI_DATA_WIDTH-1:0] 	 m_axi_rdata,
    input  wire [2-1:0] 			 m_axi_rresp,
    input  wire 				 m_axi_rlast,
    input  wire [C_M_AXI_RUSER_WIDTH-1:0] 	 m_axi_ruser,
    input  wire 				 m_axi_rvalid,
    output reg 				 m_axi_rready,

  //main FSM interface
  // Control signals from main FSM
    input wire [C_M_AXI_ADDR_WIDTH-1:0] src_addr,                    // Source address for AXI read transactions
    input wire [C_M_AXI_ADDR_WIDTH-1:0] dest_addr,                   // Destination address for AXI write transactions
    input  wire				start_write,                             //holding this signal up for 1 positive edge will start the write transaction if the transaction is completed and this signal is still up a new transaction will start
    input  wire				start_read,                              //holding this signal up for 1 positive edge will start the read transaction if the transaction is completed and this signal is still up a new transaction will start
    input wire [2-1:0] r_burst_type,                                   //burst type INC,WRAP,FIXED
    input wire [3-1:0] r_burst_size,                                   //the size of each transfer in the beat ,mostly equals the data bus width
    input wire [9-1:0] r_beats,                                        //number of beats in the burst
    input wire [2-1:0] w_burst_type,                                   //burst type INC,WRAP,FIXED
    input wire [3-1:0] w_burst_size,                                   //the size of each transfer in the beat ,mostly equals the data bus width
    input wire [9-1:0] w_beats,                                        //number of beats in the burst
    output reg write_transaction_completed ,                  //flag when the write transaction is completed will be up for one cycle
    output reg read_transaction_completed  ,                    //flag when the read transaction is completed will be up for one cycle   
    

    //fifo interface
        //FIFO interface
    output logic                           fifo_wr_en,   //when enabled the fifo takes data in
    output logic  [C_M_AXI_DATA_WIDTH-1:0] fifo_wr_data,   //the data to be written to the fifo
    input  logic                           fifo_full,   //fifo full indicator    
    input  logic                           fifo_empty,   //fifo empty indicator
    output logic                           fifo_rd_en,   //when enabled the fifo gives data out
    input  logic [C_M_AXI_DATA_WIDTH-1:0]  fifo_rd_data,  //the data to be read from the fifo
    input  logic                           wr_ack,   //ack signal to make sure the write operations is done right.
    input  logic                           rd_ack   //ack signal to make sure the read operations is done right. 
    );

    reg 					 write_resp_error;            //flag the if there is an error in the writing
    reg					     read_resp_error;             // flag if there is an error in reading
    reg                      slave_error;                 //flag if the last expected data is recived but the slave still sends more and did not rise the rlast signal 

    reg [9-1:0] w_beats_r;
    reg [9-1:0] r_beats_r;                    
    reg [2-1:0] w_burst_type_r;               
    reg [2-1:0] r_burst_type_r;               
    reg [3-1:0] w_burst_size_r;               
    reg [3-1:0] r_burst_size_r;               
    reg [C_M_AXI_ADDR_WIDTH-1:0] src_addr_r;  
    reg [C_M_AXI_ADDR_WIDTH-1:0] dest_addr_r; 


    reg w_en,r_en,r_counter_en,w_counter_en,w_counter_sample,r_counter_sample;


/*
enum to define the states of the write channel
WIDLE:write idle
WRITE_ADDR:write address
WRITE_DATA
WWAIT_RESP:write wait responce
WWAIT_ACK:write wait ack (from the fifo that the fifo data is now valid to be read)
*/

typedef enum logic [2:0] {
    WIDLE,
    WRITE_SAMPLE,
    WRITE_ADDR,
    WRITE_DATA,
    WRITE_DATAA,
    WWAIT_RESP
    } axi_write_t;       

axi_write_t w_cs,w_ns;

/*
enum to define the states of the read channel
RIDLE:read idle
READ_ADDR:read address
READ_DATA
RWAIT_ACK:read wait ack (from the fifo to show that the data is stored successfully in the fifo)
*/

typedef enum logic [2:0] {
    RIDLE,
    READ_SAMPLE,
    READ_ADDR,
    READ_DATA,
    READ_DATAA
} axi_read_t;

axi_read_t r_cs,r_ns;

/*w_counter to count the number of beats: used to drive the write last signal*/

reg [9-1:0] w_counter;
reg [9-1:0] r_counter;

///////////////////////
//Write  Channel
///////////////////////

assign m_axi_awid = 'b0;
   
//Burst LENgth is number of transaction beats, minus 1
assign m_axi_awlen = w_beats_r - 1;

// Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
assign m_axi_awsize = w_burst_size_r;

assign m_axi_awlock = 1'b0;
// Not Allocated, Modifiable, not Bufferable
// Not Bufferable since this example is meant to test memory, not intermediate cache
assign m_axi_awcache = 4'b0010;
assign m_axi_awprot = 3'h0;
assign m_axi_awqos = 4'h0;
assign m_axi_awser = 'b0;
assign m_axi_wuser ='b0;
assign m_axi_buser ='b0;
assign m_axi_awuser ='b0;

/*****************here****************/
assign m_axi_wdata = fifo_rd_data;

assign fifo_rd_en = !fifo_empty && m_axi_wready && (w_counter != 1'b0) && ((w_cs == WRITE_DATA)||(w_cs == WRITE_DATAA));

/*********************************/

always @(posedge aclk, negedge aresetn) begin
    if(!aresetn)begin
        /* if reset the next state is the idle state*/
        w_cs <= WIDLE;
    end
    else begin
        /*to go from state to another*/
        w_cs <= w_ns;
    end
end

always_ff @(posedge aclk, negedge aresetn) begin : write_sample_block
    if(!aresetn)begin
        w_beats_r <= 1'b0;
        w_burst_size_r <= 1'b0;
        w_burst_type_r <= 1'b0;
        dest_addr_r <= 1'b0;
    end else if(w_en) begin
        w_beats_r <= w_beats;
        w_burst_size_r <= w_burst_size;
        w_burst_type_r <= w_burst_type;
        dest_addr_r <= dest_addr;
    end
end

always_ff @(posedge aclk, negedge aresetn) begin : write_counter
    if(!aresetn)begin
        w_counter <= 0;
    end else if(w_counter_sample) begin
        w_counter <= w_beats_r;
    end else if(w_counter_en)begin
        w_counter <= w_counter - 1;
    end
end


always_comb begin : write_channel_logic
            m_axi_awvalid = 'b0;
            m_axi_awburst = 'b0;
            m_axi_awaddr = 'b0;
            m_axi_wvalid = 'b0;
            m_axi_bready = 'b0;
            m_axi_wlast = 'b0;
            m_axi_wstrb = 'b0;
            write_resp_error = 1'b0;

            write_transaction_completed = 1'b0;
        
            w_counter_sample = 0;
            w_counter_en = 0;

            w_en = 1'b0;
    case (w_cs)
         WIDLE:begin
            /*wait in the idle state until the main FSM requests starting the transaction
            if the main FSM asserted start_write for one posetive edge the write channel will start
            and will samble the data from the main FSM and the next state would be 
            the write address state other wise will remain idle.
            */
            if(start_write == 1'b1)begin
                w_en = 1'b1;
                w_ns = WRITE_SAMPLE;
            end else begin
                w_ns = WIDLE;
            end
        end
        WRITE_SAMPLE:begin
            w_ns = WRITE_ADDR;
        end
        WRITE_ADDR:begin
            /*spicify the burst type and the destination address and set the address write valid signal to 1 and 
            also make bready 1 which indicates that we are ready to accebt the responce for the write,
            wait for the slave to be ready for the transaction (until he sets awready=1) then go to write data state
            other wise remain in the same state  
            */
            m_axi_awburst = w_burst_type_r;
            m_axi_awaddr = dest_addr_r;
            m_axi_awvalid = 1'b1;
            m_axi_bready = 1'b1;
            if(m_axi_awready)begin
                w_counter_sample = 1;
                w_ns = WRITE_DATA;
            end
            else begin
                w_ns = WRITE_ADDR;
            end
        end 
        /***************here******************/
        WRITE_DATA:begin
            /* Specify the write strobes (m_axi_wstrb) to indicate which bytes of data are valid.
               In this case, all bytes are valid (0'hf). If the FIFO is not empty and m_axi_wvalid is '0',
               we are ready to read data from the FIFO and transition to the WWAIT_ACK state.
               If m_axi_wvalid is '1' and m_axi_wready is also '1', we have successfully transferred data,
               so we clear m_axi_wvalid, check if it was the last transfer (m_axi_wlast), and decide the next state.
               If neither condition is met, remain in the WRITE_DATA state.
            */
            m_axi_wstrb = 4'b1111;
            m_axi_bready = 'b1;
            if(w_counter == 1'b0)begin
                m_axi_wlast = 1'b1;
                m_axi_wvalid = 1'b1;
                w_counter_en= 1'b1;
                w_ns = WWAIT_RESP;
            end else if(rd_ack)begin
                m_axi_wvalid = 1'b1;
                w_counter_en= 1'b1;
                w_ns = WRITE_DATAA;
            end else begin
                w_ns = WRITE_DATAA;
            end

        end
        WRITE_DATAA:begin
            /* Specify the write strobes (m_axi_wstrb) to indicate which bytes of data are valid.
               In this case, all bytes are valid (0'hf). If the FIFO is not empty and m_axi_wvalid is '0',
               we are ready to read data from the FIFO and transition to the WWAIT_ACK state.
               If m_axi_wvalid is '1' and m_axi_wready is also '1', we have successfully transferred data,
               so we clear m_axi_wvalid, check if it was the last transfer (m_axi_wlast), and decide the next state.
               If neither condition is met, remain in the WRITE_DATA state.
            */
            m_axi_wstrb = 4'b1111;
            m_axi_bready = 'b1;
            if(w_counter == 1'b0)begin
                m_axi_wlast = 1'b1;
                m_axi_wvalid = 1'b1;
                w_counter_en= 1'b1;
                w_ns = WWAIT_RESP;
            end else if(rd_ack)begin
                m_axi_wvalid = 1'b1;
                w_counter_en= 1'b1;
                w_ns = WRITE_DATA;
            end else begin
                w_ns = WRITE_DATA;
            end
            end
            /***************here******************/
        WWAIT_RESP:begin
            /* Wait for the write response from the slave (m_axi_bvalid).
             If the slave asserts m_axi_bvalid, capture any error response (m_axi_bresp[1])
            and set write_transaction_completed to '1' to signal that the write transaction is done.
            Transition back to the WIDLE state to be ready for the next transaction.
            If m_axi_bvalid is not asserted, remain in the WWAIT_RESP state waiting for the response.
            */
            m_axi_bready = 'b1;
            m_axi_wvalid = 1'b0;
            if(m_axi_bvalid)begin
                write_resp_error = m_axi_bresp[1];
                write_transaction_completed = 1'b1;
                w_ns = WIDLE;
            end
            else begin
                w_ns = WWAIT_RESP;
            end
        end

        default: w_ns = WIDLE;
        /* The default state handles unexpected values of w_cs.
        It forces a transition back to the WIDLE state to reset the state machine
        and prevent it from staying in an undefined state.
        */
    endcase

end

//////////////////////   
//Read Channel
//////////////////////

assign m_axi_arid = 'b0;
   
//Burst LENgth is number of transaction beats, minus 1
assign m_axi_arlen = r_beats_r - 1;

// Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
assign m_axi_arsize = r_burst_size_r;

assign m_axi_arlock = 'b0;
// Not Allocated, Modifiable, not Bufferable
// Not Bufferable since this example is meant to test memory, not intermediate cache
assign m_axi_arcache = 4'b0010;
assign m_axi_arprot = 3'h0;
assign m_axi_arqos = 4'h0;
assign m_axi_aruser = 'b0;

assign fifo_wr_en = m_axi_rvalid && (r_counter != 0) && !fifo_full && ((r_cs==READ_DATA)||(r_cs==READ_DATAA));
 
assign fifo_wr_data = m_axi_rdata;

always @(posedge aclk, negedge aresetn) begin
    if(!aresetn)begin
        r_cs <= RIDLE;
    end
    else begin
        r_cs <= r_ns;
    end
end

always_ff @(posedge aclk, negedge aresetn) begin : read_sample_block
    if(!aresetn)begin
        r_beats_r <= 1'b0;
        r_burst_size_r <= 1'b0;
        r_burst_type_r <= 1'b0;
        src_addr_r <= 1'b0;
    end else if(r_en) begin
        r_beats_r <= r_beats;
        r_burst_size_r <= r_burst_size;
        r_burst_type_r <= r_burst_type;
        src_addr_r <= src_addr;
    end
end


always_ff @(posedge aclk, negedge aresetn) begin : read_counter
    if(!aresetn)begin
        r_counter <= 0;
    end else if(r_counter_sample) begin
        r_counter <= r_beats_r;
    end else if(r_counter_en)begin
        r_counter <= r_counter - 1;
    end
end


always_comb begin : read_channel

            m_axi_arvalid = 'b0;
            m_axi_arburst = 'b0;
            m_axi_araddr = 'b0;
            m_axi_rready = 'b0;

            r_counter_sample = 1'b0;
            r_counter_en = 1'b0;

            read_transaction_completed = 1'b0;
        
        /***************here******************/
            r_en =1'b0; 
        /***************here******************/
    case (r_cs)
         RIDLE:begin
             /* The state machine remains in the idle state (RIDLE) until a read transaction is requested.
       All signals are set to default values to indicate no transaction is ongoing.
       If the start signal (start_read) is asserted, indicating that the main FSM wants to initiate a read transaction,
       the state machine clears the read_transaction_completed flag and transitions to the READ_ADDR state to start 
       the address phase of the read transaction. If start_read is not asserted, the state machine stays in RIDLE.
    */
            
            if(start_read == 1'b1)begin
                r_en =1'b1;
                r_ns = READ_SAMPLE;
            end
            else begin
                r_ns = RIDLE;
            end
        end
        READ_SAMPLE:begin
            r_ns = READ_ADDR;
        end
        READ_ADDR:begin
             /* In the READ_ADDR state, the read address (m_axi_araddr) and burst type (m_axi_arburst) are set up
       for the AXI read transaction. The read address valid signal (m_axi_arvalid) is asserted to indicate
       to the slave that a valid read address is being presented. The state machine then waits for the slave 
       to acknowledge the address by asserting m_axi_arready. Once the slave is ready (m_axi_arready is high),
       the state machine transitions to the READ_DATA state to start reading data. If not, it remains in READ_ADDR.
    */
            m_axi_arvalid = 'b1;
            m_axi_arburst = r_burst_type_r;
            m_axi_araddr = src_addr_r;
            if(m_axi_arready)begin
                r_counter_sample = 1'b1;
                r_ns = READ_DATA;
            end
            else begin
                r_ns = READ_ADDR;
            end
        end 
        /***************here******************/
        READ_DATA:begin
             /* In the READ_DATA state, the read ready signal (m_axi_rready) is asserted to indicate that the master 
       is ready to accept data from the slave. If the slave asserts m_axi_rvalid (indicating that data is available)
       and the FIFO is not full, the state machine enables writing to the FIFO (fifo_wr_en) and loads the received 
       data (m_axi_rdata) into the FIFO (fifo_wr_data). The state then moves to the RWAIT_ACK state to wait for the 
       write acknowledgment from the FIFO. If the data is not valid or the FIFO is full, remain in the READ_DATA state.
       Also, capture any read response error (m_axi_rresp[1]).
    */      

        // If last beat, go back to RIDLE, otherwise continue reading also report if the slave sent more than the req data
            if (m_axi_rlast || (r_counter == 0)) begin
                read_transaction_completed = 1'b1;
                // Check if it's an error case
                if (!m_axi_rlast && r_counter <= 1) begin
                    slave_error = 1'b1;
                end else begin
                    slave_error = 1'b0;
                end
                    r_ns = RIDLE;
            end else if(wr_ack) begin
                read_resp_error = m_axi_rresp[1];
                m_axi_rready = 'b1;
                r_counter_en = 1'b1;
                r_ns = READ_DATAA;
            end else begin
                m_axi_rready = 'b0;
                r_ns = READ_DATAA;
            end
        end
        READ_DATAA:begin
           /* dublication for the read state to improve the effictiency of the transaction
           and also avoide hanging in the read data state if the slave is always reads 
           as the always comb will never be tregered then
    */
            if (m_axi_rlast || (r_counter == 0)) begin
                read_transaction_completed = 1'b1;
                // Check if it's an error case
                if (!m_axi_rlast && r_counter <= 1) begin
                    slave_error = 1'b1;
                end else begin
                    slave_error = 1'b0;
                end
                    r_ns = RIDLE;
            end else if(wr_ack) begin
                read_resp_error = m_axi_rresp[1];
                m_axi_rready = 'b1;
                r_counter_en = 1'b1;
                r_ns = READ_DATA;
            end else begin
                m_axi_rready = 'b0;
                r_ns = READ_DATA;
            end
        end
        /***************here******************/
        default: r_ns = RIDLE;
        /* The default state ensures that if an undefined state is encountered,
   the state machine resets to RIDLE to prevent it from staying in an undefined state,
   thereby ensuring a safe and controlled reset behavior.
*/
    endcase

end

endmodule 