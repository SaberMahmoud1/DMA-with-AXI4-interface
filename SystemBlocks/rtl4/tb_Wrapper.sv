class AXITransaction;
    // Parameters for the transaction
    rand bit [7:0]  awlen;
    rand bit [2:0]  awsize;
    rand bit [1:0]  awburst;
    rand bit [31:0] awaddr;
    rand bit [31:0] wdata;
    rand bit [3:0]  wstrb;
    rand bit        wlast;
    rand bit [31:0] araddr;
    rand bit [7:0]  arlen;
    rand bit [2:0]  arsize;
    rand bit [1:0]  arburst;

    // Constraints
    constraint awsize_constraint { awsize == 3'b010; } // 4 bytes
    constraint wstrb_constraint { wstrb == 4'b1111; }  // Full write strobe
    constraint awburst_constraint { awburst inside {2'b00, 2'b01}; } // FIXED or INCR
    constraint arburst_constraint { arburst inside {2'b00, 2'b01}; } // FIXED or INCR
endclass

module tb_top_wrapper;

    // Parameters
    parameter C_AXI_ADDR_WIDTH = 32;
    parameter C_AXI_DATA_WIDTH = 32;
    
    // Clock and Reset
    logic AXI_aclk;
    logic AXI_aresetn;

    // AXI Slave Interface
    logic [C_AXI_ADDR_WIDTH-1:0] AXI_awaddr;
    logic [7:0] AXI_awlen; 
    logic [2:0] AXI_awsize;
    logic [1:0] AXI_awburst;
    logic AXI_awvalid;
    logic AXI_awready;

    logic [C_AXI_DATA_WIDTH-1:0] AXI_wdata;
    logic [C_AXI_DATA_WIDTH/8-1:0] AXI_wstrb; 
    logic AXI_wlast;
    logic AXI_wvalid;
    logic AXI_wready;

    logic AXI_bready;
    logic AXI_bvalid;
    logic [1:0] AXI_bresp;

    logic [C_AXI_ADDR_WIDTH-1:0] AXI_araddr;
    logic [7:0] AXI_arlen; 
    logic [2:0] AXI_arsize;
    logic [1:0] AXI_arburst;
    logic AXI_arvalid;
    logic AXI_arready;

    logic [C_AXI_DATA_WIDTH-1:0] AXI_rdata; 
    logic [1:0] AXI_rresp;
    logic AXI_rlast;
    logic AXI_rvalid;
    logic AXI_rready;   

    // AXI Master Interface
    logic [0:0] m_axi_awid;
    logic [C_AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
    logic [7:0] m_axi_awlen;
    logic [2:0] m_axi_awsize;
    logic [1:0] m_axi_awburst;
    logic m_axi_awlock;
    logic [3:0] m_axi_awcache;
    logic [2:0] m_axi_awprot;
    logic [3:0] m_axi_awqos;
    logic [0:0] m_axi_awuser;
    logic m_axi_awvalid;
    logic m_axi_awready;

    logic [C_AXI_DATA_WIDTH-1:0] m_axi_wdata;
    logic [C_AXI_DATA_WIDTH/8-1:0] m_axi_wstrb;
    logic m_axi_wlast;
    logic [0:0] m_axi_wuser;
    logic m_axi_wvalid;
    logic m_axi_wready;

    logic [0:0] m_axi_bid;
    logic [1:0] m_axi_bresp;
    logic [0:0] m_axi_buser;
    logic m_axi_bvalid;
    logic m_axi_bready;

    logic [0:0] m_axi_arid;
    logic [C_AXI_ADDR_WIDTH-1:0] m_axi_araddr;
    logic [7:0] m_axi_arlen;
    logic [2:0] m_axi_arsize;
    logic [1:0] m_axi_arburst;
    logic [1:0] m_axi_arlock;
    logic [3:0] m_axi_arcache;
    logic [2:0] m_axi_arprot;
    logic [3:0] m_axi_arqos;
    logic [0:0] m_axi_aruser;
    logic m_axi_arvalid;
    logic m_axi_arready;

    logic [0:0] m_axi_rid;
    logic [C_AXI_DATA_WIDTH-1:0] m_axi_rdata;
    logic [1:0] m_axi_rresp;
    logic m_axi_rlast;
    logic [0:0] m_axi_ruser;
    logic m_axi_rvalid;
    logic m_axi_rready;

    // CPU Interrupt Signals
    logic CPU_interrupt_CFG;
    logic CPU_interrupt_end;
    logic CPU_interrupt_ch_done;

    // Instantiate the top_wrapper module
    top_wrapper #(
        .C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
        .C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH)
    ) uut (
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

        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awuser(m_axi_awuser),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),

        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wuser(m_axi_wuser),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),

        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_buser(m_axi_buser),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),

        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_aruser(m_axi_aruser),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),

        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_ruser(m_axi_ruser),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),

        .CPU_interrupt_ch_done(CPU_interrupt_ch_done),
        .CPU_interrupt_CFG(CPU_interrupt_CFG),
        .CPU_interrupt_end(CPU_interrupt_end)
    );

    // Clock Generation
    initial begin
        AXI_aclk = 0;
        forever #5 AXI_aclk = ~AXI_aclk;
    end

    // Reset
    initial begin
        AXI_aresetn = 0;
        #20 AXI_aresetn = 1;
    end

    // Task for sending a write transaction
    task automatic send_write(AXITransaction txn);
        @(posedge AXI_aclk);
        AXI_awaddr = txn.awaddr;
        AXI_awlen = txn.awlen;
        AXI_awsize = txn.awsize;
        AXI_awburst = txn.awburst;
        AXI_awvalid = 1;

        // Wait for ready
        wait(AXI_awready);
        @(posedge AXI_aclk);
        AXI_awvalid = 0;

        // Write data
        AXI_wdata = txn.wdata;
        AXI_wstrb = txn.wstrb;
        AXI_wlast = txn.wlast;
        AXI_wvalid = 1;

        // Wait for ready
        wait(AXI_wready);
        @(posedge AXI_aclk);
        AXI_wvalid = 0;
    endtask

    initial begin
        m_axi_rdata=0;
        #5;
        forever begin
        #10 m_axi_rdata=$random; 
        end
    end

    // Test Stimulus
    initial begin
        AXITransaction txn;

     //normal operation
        
        // Initialize signals
        AXI_awvalid = 0;
        AXI_wvalid = 0;
        AXI_bready = 0;
        AXI_arvalid = 0;
        AXI_rready = 0;

        m_axi_rresp='b0;
        m_axi_rlast='b0;
        m_axi_rvalid='b0;
        m_axi_awready='b0;
        m_axi_wready='b0;
        m_axi_arready='b0;
        m_axi_bresp='b0;
        m_axi_bvalid='b0;

        #20;

        // Begin test sequence 1 -> Write Active Channels

        AXI_awaddr = 32'h00000000;
        AXI_awlen = 8'h00; // 1 transfer
        AXI_awsize = 3'b010; // 4 bytes
        AXI_awburst = 2'b01; // INCR
        AXI_awvalid = 1;



        /*address zero in the reg file is dedicated for the active channels
          as each channel corispondes to a bit at that address we have 32 chanels
          from ch0-->ch31, for test activate Channels 1,2,7 */ 

        AXI_wdata = 32'b0000_0000_0000_0000_0000_0000_1000_0110;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 1;
        #10;
        #10;
        
        AXI_awvalid = 0;
        AXI_wvalid = 0;
        AXI_wlast = 0;

        // Test write response channel
        AXI_bready = 1;
        #20;
        AXI_bready = 0;

        // Begin test sequence 1 -> Write Active Channels
        /*the register file has addresses dedicated to each channel to store its data
        for channel one it is in address 5 
        */

        AXI_awaddr = 32'b0000_0000_0000_0000_0000_0000_0001_01_00; //addr 5
        AXI_awlen = 8'd7; // 8 transfer
        AXI_awsize = 3'b010; // 4 bytes
        AXI_awburst = 2'b01; // INCR
        AXI_awvalid = 1;
        #10;

        AXI_awvalid = 0;

        // Channels 1,2 are to be activated
        // 1 -> config
        /* */
        AXI_wdata = 32'b1111_1111_1111_1111_0000_0000_0000_0001;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 2 -> Transaction Count
        AXI_wdata = 32'd1200;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 3 -> SRC addr
        AXI_wdata = 32'hDEADDEAD;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 4 -> DST addr
        AXI_wdata = 32'hDEADDEAD;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // Channel 2

        // 1 -> config
        AXI_wdata = 32'b1111_1111_1111_1111_0000_0000_0000_0010;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 2 -> Transaction Count
        AXI_wdata = 32'd1200;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 3 -> SRC addr
        AXI_wdata = 32'hBEEFBEEF;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 4 -> DST addr
        AXI_wdata = 32'hBEEFBEEF;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 1;
        #10;

        AXI_wvalid = 0;
        AXI_wlast = 0;

        // Test write response channel
        AXI_bready = 1;
        #20;
        AXI_bready = 0;
        
        // Begin test sequence 3 -> Channel 7
        AXI_awaddr = 32'b0000_0000_0000_0000_0000_0000_0111_01_00; //addr 
        AXI_awlen = 8'd3; // 4 transfer
        AXI_awsize = 3'b010; // 4 bytes
        AXI_awburst = 2'b01; // INCR
        AXI_awvalid = 1;
        #10;

        AXI_awvalid = 0;

        // Channels 7 is to be activated
        // 1 -> config
        AXI_wdata = 32'b1111_1111_1111_1111_0000_0000_0000_0011;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 2 -> Transaction Count
        AXI_wdata = 32'd1200;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 3 -> SRC addr
        AXI_wdata = 32'hDEADBEEF;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 0;
        #10;

        // 4 -> DST addr
        AXI_wdata = 32'hDEADBEEF;
        AXI_wvalid = 1;
        AXI_wstrb = 4'b1111;
        AXI_wlast = 1;
        #10;

        AXI_wvalid = 0;
        AXI_wlast = 0;

        // Test write response channel
        AXI_bready = 1;
        #20;
        AXI_bready = 0;
        
        // DATA WRITTEN TO REGISTER FILE
        //************************************************************************************************************//

        #20;

        m_axi_rresp='b0;
        m_axi_rlast='b0;
        m_axi_rvalid='b1;
        m_axi_awready='b1;
        
        m_axi_arready='b1;
        m_axi_bresp='b0;
        m_axi_bvalid='b1;

        CPU_interrupt_CFG = 1;

        #10;
        
        CPU_interrupt_CFG = 0;
        
        repeat(750)begin
        @(posedge AXI_aclk);
        m_axi_wready='b1;
        @(posedge AXI_aclk);
        @(posedge AXI_aclk);
        @(posedge AXI_aclk);
        @(posedge AXI_aclk);
        m_axi_wready='b0;
        end

        m_axi_wready='b1;
        #1000;
        // Read Channel 1 and 2
        AXI_araddr  = 32'b0000_0000_0000_0000_0000_0000_0001_01_00;
        AXI_arlen   = 7;
        AXI_arsize  = 2;
        AXI_arburst = 1; 
        AXI_arvalid = 1;
        AXI_rready  = 1;

        #10;

        AXI_arvalid = 0;
        
        #200;

    /*****************************************************************************************************************************/

        // //fifo full

        
        // // Initialize signals
        // AXI_awvalid = 0;
        // AXI_wvalid = 0;
        // AXI_bready = 0;
        // AXI_arvalid = 0;
        // AXI_rready = 0;

        // m_axi_rresp='b0;
        // m_axi_rlast='b0;
        // m_axi_rvalid='b0;
        // m_axi_awready='b0;
        // m_axi_wready='b0;
        // m_axi_arready='b0;
        // m_axi_bresp='b0;
        // m_axi_bvalid='b0;

        // #20;

        // // Begin test sequence 1 -> Write Active Channels

        // AXI_awaddr = 32'h00000000;
        // AXI_awlen = 8'h00; // 1 transfer
        // AXI_awsize = 3'b010; // 4 bytes
        // AXI_awburst = 2'b01; // INCR
        // AXI_awvalid = 1;



        // /*address zero in the reg file is dedicated for the active channels
        //   as each channel corispondes to a bit at that address we have 32 chanels
        //   from ch0-->ch31, for test activate Channels 1,2,7 */ 

        // AXI_wdata = 32'b0000_0000_0000_0000_0000_1111_0000_0000;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 1;
        // #10;
        // #10;
        
        // AXI_awvalid = 0;
        // AXI_wvalid = 0;
        // AXI_wlast = 0;

        // // Test write response channel
        // AXI_bready = 1;
        // #20;
        // AXI_bready = 0;

        // // Begin test sequence 1 -> Write Active Channels
        // /*the register file has addresses dedicated to each channel to store its data
        // for channel one it is in address 5 
        // */

        // AXI_awaddr = 32'b0000_0000_0000_0000_0000_0000_1000_01_00; //addr 8
        // AXI_awlen = 8'd7; // 8 transfer
        // AXI_awsize = 3'b010; // 4 bytes
        // AXI_awburst = 2'b01; // INCR
        // AXI_awvalid = 1;
        // #10;

        // AXI_awvalid = 0;

        // // Channels 1,2 are to be activated
        // // 1 -> config
        // /* */
        // AXI_wdata = 32'b1111_1111_1111_1111_0000_0000_0000_0111;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 2 -> Transaction Count
        // AXI_wdata = 32'd200;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 3 -> SRC addr
        // AXI_wdata = 32'hDEADDEAD;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 4 -> DST addr
        // AXI_wdata = 32'hDEADDEAD;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // Channel 2

        // // 1 -> config
        // AXI_wdata = 32'b1111_1111_1111_1111_0000_0000_0000_0011;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 2 -> Transaction Count
        // AXI_wdata = 32'd1024;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 3 -> SRC addr
        // AXI_wdata = 32'hBEEFBEEF;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 4 -> DST addr
        // AXI_wdata = 32'hBEEFBEEF;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 1;
        // #10;

        // AXI_wvalid = 0;
        // AXI_wlast = 0;

        // // Test write response channel
        // AXI_bready = 1;
        // #20;
        // AXI_bready = 0;
        
        // // Begin test sequence 3 -> Channel 7
        // // Begin test sequence 1 -> Write Active Channels
        // /*the register file has addresses dedicated to each channel to store its data
        // for channel one it is in address 5 
        // */

        // AXI_awaddr = 32'b0000_0000_0000_0000_0000_0000_1010_01_00; //addr 5
        // AXI_awlen = 8'd7; // 8 transfer
        // AXI_awsize = 3'b010; // 4 bytes
        // AXI_awburst = 2'b01; // INCR
        // AXI_awvalid = 1;
        // #10;

        // AXI_awvalid = 0;

        // // Channels 1,2 are to be activated
        // // 1 -> config
        // /* */
        // AXI_wdata = 32'b1111_1111_1111_1111_0000_0000_0000_0111;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 2 -> Transaction Count
        // AXI_wdata = 32'd200;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 3 -> SRC addr
        // AXI_wdata = 32'hDEADDEAD;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 4 -> DST addr
        // AXI_wdata = 32'hDEADDEAD;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // Channel 2

        // // 1 -> config
        // AXI_wdata = 32'b1111_1111_1111_1111_0000_0000_0000_0011;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 2 -> Transaction Count
        // AXI_wdata = 32'd1024;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 3 -> SRC addr
        // AXI_wdata = 32'hBEEFBEEF;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 0;
        // #10;

        // // 4 -> DST addr
        // AXI_wdata = 32'hBEEFBEEF;
        // AXI_wvalid = 1;
        // AXI_wstrb = 4'b1111;
        // AXI_wlast = 1;
        // #10;

        // AXI_wvalid = 0;
        // AXI_wlast = 0;

        // // Test write response channel
        // AXI_bready = 1;
        // #20;
        // AXI_bready = 0;
        
        // // DATA WRITTEN TO REGISTER FILE
        // //************************************************************************************************************//

        // #20;

        // m_axi_rresp='b0;
        // m_axi_rlast='b0;
        // m_axi_rvalid='b1;
        // m_axi_awready='b1;

        // m_axi_arready='b1;
        // m_axi_bresp='b0;
        // m_axi_bvalid='b1;

        // CPU_interrupt_start = 1;

        // #10;
        
        // CPU_interrupt_start = 0;

        // repeat(900)begin
        //     @(posedge AXI_aclk);
        //     m_axi_wready = 1;
        //     @(posedge AXI_aclk);
        //     @(posedge AXI_aclk);
        //     @(posedge AXI_aclk);
        //     m_axi_wready = 0;
        // end
        

        // // Read Channel 1 and 2
        // AXI_araddr  = 32'b0000_0000_0000_0000_0000_0000_0001_01_00;
        // AXI_arlen   = 7;
        // AXI_arsize  = 2;
        // AXI_arburst = 1; 
        // AXI_arvalid = 1;
        // AXI_rready  = 1;

        // #10;

        // AXI_arvalid = 0;
        
        // #200;

        $stop;
    end


endmodule
