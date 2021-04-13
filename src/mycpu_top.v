`timescale 1ns / 1ps

module mycpu_top(
	input wire[5:0] ext_int,
	input wire aclk,aresetn,
	
	// axi port
    //ar
    output wire[3:0] arid,      //read request id, fixed 4'b0
    output wire[31:0] araddr,   //read request address
    output wire[7:0] arlen,     //read request transfer length(beats), fixed 4'b0
    output wire[2:0] arsize,    //read request transfer size(bytes per beats)
    output wire[1:0] arburst,   //transfer type, fixed 2'b01
    output wire[1:0] arlock,    //atomic lock, fixed 2'b0
    output wire[3:0] arcache,   //cache property, fixed 4'b0
    output wire[2:0] arprot,    //protect property, fixed 3'b0
    output wire arvalid,        //read request address valid
    input wire arready,         //slave end ready to receive address transfer
    //r              
    input wire[3:0] rid,        //equal to arid, can be ignored
    input wire[31:0] rdata,     //read data
    input wire[1:0] rresp,      //this read request finished successfully, can be ignored
    input wire rlast,           //the last beat data for this request, can be ignored
    input wire rvalid,          //read data valid
    output wire rready,         //master end ready to receive data transfer
    //aw           
    output wire[3:0] awid,      //write request id, fixed 4'b0
    output wire[31:0] awaddr,   //write request address
    output wire[3:0] awlen,     //write request transfer length(beats), fixed 4'b0
    output wire[2:0] awsize,    //write request transfer size(bytes per beats)
    output wire[1:0] awburst,   //transfer type, fixed 2'b01
    output wire[1:0] awlock,    //atomic lock, fixed 2'b01
    output wire[3:0] awcache,   //cache property, fixed 4'b01
    output wire[2:0] awprot,    //protect property, fixed 3'b01
    output wire awvalid,        //write request address valid
    input wire awready,         //slave end ready to receive address transfer
    //w          
    output wire[3:0] wid,       //equal to awid, fixed 4'b0
    output wire[31:0] wdata,    //write data
    output wire[3:0] wstrb,     //write data strobe select bit
    output wire wlast,          //the last beat data signal, fixed 1'b1
    output wire wvalid,         //write data valid
    input wire wready,          //slave end ready to receive data transfer
    //b              
    input  wire[3:0] bid,       //equal to wid,awid, can be ignored
    input  wire[1:0] bresp,     //this write request finished successfully, can be ignored
    input wire bvalid,          //write data valid
    output wire bready,          //master end ready to receive write response

	//debug signals
	output wire [31:0] debug_wb_pc,
	output wire [3 :0] debug_wb_rf_wen,
	output wire [4 :0] debug_wb_rf_wnum,
	output wire [31:0] debug_wb_rf_wdata

    );

    wire        inst_req  ;
    wire [31:0] inst_addr ;
    wire        inst_wr   ;
    wire [1:0]  inst_size ;
    wire [31:0] inst_wdata;
    wire [31:0] inst_rdata;
    wire        inst_addr_ok;
    wire        inst_data_ok;

    wire        data_req  ;
    wire [31:0] data_addr ;
    wire        data_wr   ;
    wire [1:0]  data_size ;
    wire [31:0] data_wdata;
    wire [31:0] data_rdata;
    wire        data_addr_ok;
    wire        data_data_ok;

    wire        ram_data_req  ;
    wire [31:0] ram_data_addr ;
    wire        ram_data_wr   ;
    wire [1:0]  ram_data_size ;
    wire [31:0] ram_data_wdata;
    wire [31:0] ram_data_rdata;
    wire        ram_data_addr_ok;
    wire        ram_data_data_ok;

    wire        conf_data_req  ;
    wire [31:0] conf_data_addr ;
    wire        conf_data_wr   ;
    wire [1:0]  conf_data_size ;
    wire [31:0] conf_data_wdata;
    wire [31:0] conf_data_rdata;
    wire        conf_data_addr_ok;
    wire        conf_data_data_ok;

    wire        wrap_data_req  ;
    wire [31:0] wrap_data_addr ;
    wire        wrap_data_wr   ;
    wire [1:0]  wrap_data_size ;
    wire [31:0] wrap_data_wdata;
    wire [31:0] wrap_data_rdata;
    wire        wrap_data_addr_ok;
    wire        wrap_data_data_ok;

    wire        cache_data_req  ;
    wire [31:0] cache_data_addr ;
    wire        cache_data_wr   ;
    wire [1:0]  cache_data_size ;
    wire [31:0] cache_data_wdata;
    wire [31:0] cache_data_rdata;
    wire        cache_data_addr_ok;
    wire        cache_data_data_ok;

    wire        cache_inst_req  ;
    wire [31:0] cache_inst_addr ;
    wire        cache_inst_wr   ;
    wire [1:0]  cache_inst_size ;
    wire [31:0] cache_inst_wdata;
    wire [31:0] cache_inst_rdata;
    wire        cache_inst_addr_ok;
    wire        cache_inst_data_ok;

    wire [31:0] inst_paddr, data_paddr;
    wire no_dcache;


    mycpu cpusraml(
        .clk(aclk), .rst(~aresetn),
        .int(ext_int),

        .inst_req     (inst_req  ),
        .inst_wr      (inst_wr   ),
        .inst_addr    (inst_addr ),
        .inst_size    (inst_size ),
        .inst_wdata   (inst_wdata),
        .inst_rdata   (inst_rdata),
        .inst_addr_ok (inst_addr_ok),
        .inst_data_ok (inst_data_ok),

        .data_req     (data_req  ),
        .data_wr      (data_wr   ),
        .data_addr    (data_addr ),
        .data_wdata   (data_wdata),
        .data_size    (data_size ),
        .data_rdata   (data_rdata),
        .data_addr_ok (data_addr_ok),
        .data_data_ok (data_data_ok),

        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    // 虚拟地址转换成物理地址   
    mmu mmu(
        .inst_vaddr(inst_addr),
        .inst_paddr(inst_paddr),
        .data_vaddr(data_addr),
        .data_paddr(data_paddr),
        .no_dcache(no_dcache)    //是否经过d cache
    );

    
    bridge_1x2 bridge_1x2(
        .no_dcache        (no_dcache    ),

        .cpu_data_req     (data_req  ),
        .cpu_data_wr      (data_wr   ),
        .cpu_data_addr    (data_paddr ),    //paddr
        .cpu_data_wdata   (data_wdata),
        .cpu_data_size    (data_size ),
        .cpu_data_rdata   (data_rdata),
        .cpu_data_addr_ok (data_addr_ok),
        .cpu_data_data_ok (data_data_ok),

        .ram_data_req     (ram_data_req  ),
        .ram_data_wr      (ram_data_wr   ),
        .ram_data_addr    (ram_data_addr ),
        .ram_data_wdata   (ram_data_wdata),
        .ram_data_size    (ram_data_size ),
        .ram_data_rdata   (ram_data_rdata),
        .ram_data_addr_ok (ram_data_addr_ok),
        .ram_data_data_ok (ram_data_data_ok),

        .conf_data_req     (conf_data_req  ),
        .conf_data_wr      (conf_data_wr   ),
        .conf_data_addr    (conf_data_addr ),
        .conf_data_wdata   (conf_data_wdata),
        .conf_data_size    (conf_data_size ),
        .conf_data_rdata   (conf_data_rdata),
        .conf_data_addr_ok (conf_data_addr_ok),
        .conf_data_data_ok (conf_data_data_ok)
    );

    cache cache(
        .clk(aclk), 
        .rst(~aresetn),
        .cpu_inst_req(inst_req),
        .cpu_inst_wr(inst_wr),
        .cpu_inst_size(inst_size),
        .cpu_inst_addr(inst_paddr),
        .cpu_inst_wdata(inst_wdata),
        .cpu_inst_rdata(inst_rdata),
        .cpu_inst_addr_ok(inst_addr_ok),
        .cpu_inst_data_ok(inst_data_ok),

        .cpu_data_req(ram_data_req)     ,
        .cpu_data_wr(ram_data_wr)      ,
        .cpu_data_size(ram_data_size)    ,
        .cpu_data_addr(ram_data_addr)    ,
        .cpu_data_wdata(ram_data_wdata)   ,
        .cpu_data_rdata(ram_data_rdata)   ,
        .cpu_data_addr_ok(ram_data_addr_ok) ,
        .cpu_data_data_ok(ram_data_data_ok) ,


        .cache_inst_req(cache_inst_req)     ,
        .cache_inst_wr(cache_inst_wr)      ,
        .cache_inst_size(cache_inst_size)    ,
        .cache_inst_addr(cache_inst_addr)    ,
        .cache_inst_wdata(cache_inst_wdata)   ,
        .cache_inst_rdata(cache_inst_rdata)   ,
        .cache_inst_addr_ok(cache_inst_addr_ok) ,
        .cache_inst_data_ok(cache_inst_data_ok) ,

        .cache_data_req(cache_data_req)     ,
        .cache_data_wr(cache_data_wr)      ,
        .cache_data_size(cache_data_size)    ,
        .cache_data_addr(cache_data_addr)    ,
        .cache_data_wdata(cache_data_wdata)   ,
        .cache_data_rdata(cache_data_rdata)   ,
        .cache_data_addr_ok(cache_data_addr_ok) ,
        .cache_data_data_ok(cache_data_data_ok)
    );

    bridge_2x1 bridge_2x1(
        .no_dcache        (no_dcache    ),

        .ram_data_req     (cache_data_req  ),
        .ram_data_wr      (cache_data_wr   ),
        .ram_data_addr    (cache_data_addr ),
        .ram_data_wdata   (cache_data_wdata),
        .ram_data_size    (cache_data_size ),
        .ram_data_rdata   (cache_data_rdata),
        .ram_data_addr_ok (cache_data_addr_ok),
        .ram_data_data_ok (cache_data_data_ok),

        .conf_data_req     (conf_data_req  ),
        .conf_data_wr      (conf_data_wr   ),
        .conf_data_addr    (conf_data_addr ),
        .conf_data_wdata   (conf_data_wdata),
        .conf_data_size    (conf_data_size ),
        .conf_data_rdata   (conf_data_rdata),
        .conf_data_addr_ok (conf_data_addr_ok),
        .conf_data_data_ok (conf_data_data_ok),

        .wrap_data_req     (wrap_data_req  ),
        .wrap_data_wr      (wrap_data_wr   ),
        .wrap_data_addr    (wrap_data_addr ),
        .wrap_data_wdata   (wrap_data_wdata),
        .wrap_data_size    (wrap_data_size ),
        .wrap_data_rdata   (wrap_data_rdata),
        .wrap_data_addr_ok (wrap_data_addr_ok),
        .wrap_data_data_ok (wrap_data_data_ok)
    );

    
    cpu_axi_interface cpu_axi_interface(
        .clk(aclk),
        .resetn(aresetn),

        .inst_req       (cache_inst_req  ),
        .inst_wr        (cache_inst_wr   ),
        .inst_size      (cache_inst_size ),
        .inst_addr      (cache_inst_addr ),
        .inst_wdata     (cache_inst_wdata),
        .inst_rdata     (cache_inst_rdata),
        .inst_addr_ok   (cache_inst_addr_ok),
        .inst_data_ok   (cache_inst_data_ok),

        .data_req       (wrap_data_req  ),
        .data_wr        (wrap_data_wr   ),
        .data_size      (wrap_data_size ),
        .data_addr      (wrap_data_addr ),
        .data_wdata     (wrap_data_wdata ),
        .data_rdata     (wrap_data_rdata),
        .data_addr_ok   (wrap_data_addr_ok),
        .data_data_ok   (wrap_data_data_ok),

        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arlock(arlock),
        .arcache(arcache),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),

        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),

        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awlock(awlock),
        .awcache(awcache),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),

        .wid(wid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),

        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready)
    );



endmodule
