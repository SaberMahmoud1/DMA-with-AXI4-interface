add wave -position insertpoint  \
sim:/tb_top_wrapper/AXI_aclk

add wave -position insertpoint  \
sim:/tb_top_wrapper/m_axi_araddr \
sim:/tb_top_wrapper/m_axi_arburst \
sim:/tb_top_wrapper/m_axi_arlen \
sim:/tb_top_wrapper/m_axi_arready \
sim:/tb_top_wrapper/m_axi_arsize \
sim:/tb_top_wrapper/m_axi_arvalid \
sim:/tb_top_wrapper/m_axi_awaddr \
sim:/tb_top_wrapper/m_axi_awburst \
sim:/tb_top_wrapper/m_axi_awlen \
sim:/tb_top_wrapper/m_axi_awready \
sim:/tb_top_wrapper/m_axi_awsize \
sim:/tb_top_wrapper/m_axi_awvalid \
sim:/tb_top_wrapper/m_axi_bready \
sim:/tb_top_wrapper/m_axi_bresp \
sim:/tb_top_wrapper/m_axi_bvalid \
sim:/tb_top_wrapper/m_axi_rdata \
sim:/tb_top_wrapper/m_axi_rready \
sim:/tb_top_wrapper/m_axi_rresp \
sim:/tb_top_wrapper/m_axi_rvalid \
sim:/tb_top_wrapper/m_axi_wdata \
sim:/tb_top_wrapper/m_axi_wlast \
sim:/tb_top_wrapper/m_axi_wready \
sim:/tb_top_wrapper/m_axi_wstrb \
sim:/tb_top_wrapper/m_axi_wvalid

add wave -position insertpoint  \
sim:/tb_top_wrapper/uut/axi_master_controller_inst/r_counter
add wave -position insertpoint  \
sim:/tb_top_wrapper/uut/axi_master_controller_inst/w_counter

add wave -position insertpoint  \
sim:/tb_top_wrapper/uut/axi_master_controller_inst/fifo_rd_data \
sim:/tb_top_wrapper/uut/axi_master_controller_inst/fifo_wr_data
add wave -position insertpoint  \
sim:/tb_top_wrapper/uut/axi_master_controller_inst/r_cs \
sim:/tb_top_wrapper/uut/axi_master_controller_inst/r_ns
add wave -position insertpoint  \
sim:/tb_top_wrapper/uut/axi_master_controller_inst/w_cs \
sim:/tb_top_wrapper/uut/axi_master_controller_inst/w_ns