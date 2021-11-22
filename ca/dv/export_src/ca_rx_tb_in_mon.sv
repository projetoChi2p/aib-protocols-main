////////////////////////////////////////////////////////////////////////////////////////////////////
//
//        Copyright (C) 2021 Eximius Design
//                All Rights Reserved
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from Eximius Design
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Functional Descript: Channel Alignment Testbench File
//
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////

`ifndef _CA_RX_TB_IN_MON_
`define _CA_RX_TB_IN_MON_
///////////////////////////////////////////////////////////////////
class ca_rx_tb_in_mon_c #(int BUS_BIT_WIDTH=80, int NUM_CHANNELS=2) extends uvm_monitor ;
    
    // register w/ the factory
    //------------------------------------------
    `uvm_component_param_utils(ca_rx_tb_in_mon_c #(BUS_BIT_WIDTH, NUM_CHANNELS))

    // Virtual Interface
    //------------------------------------------
    ca_rx_tb_in_cfg_c             cfg;
    ca_data_pkg::ca_seq_item_c    stb_item;
    virtual ca_rx_tb_in_if        #(.BUS_BIT_WIDTH(BUS_BIT_WIDTH), .NUM_CHANNELS(NUM_CHANNELS)) vif;  

    //------------------------------------------
    // Data Members
    //------------------------------------------
    bit                      rx_active = 0;
    string                   my_name = "";
    int                      rx_cnt = 0;
    int                      stb_cnt = 0;
    int                      stb_beat_cnt = 0;
    bit                      stb_sync = 0;
    
    bit [((BUS_BIT_WIDTH*NUM_CHANNELS)-1):0]  exp_stb_data = 0; 
    //------------------------------------------
    // Component Members
    //------------------------------------------
    uvm_analysis_port #(ca_data_pkg::ca_seq_item_c) aport;

    //------------------------------------------
    // Standard UVM Methods:
    //------------------------------------------
    extern function new(string name = "ca_rx_tb_in_mon", uvm_component parent = null);
    extern function void build_phase(uvm_phase phase);
    extern task run_phase(uvm_phase phase);
    
    extern function void verify_rx_stb();
    extern function void gen_stb_beat();
    extern function void set_item(ca_data_pkg::ca_seq_item_c  item);
    
    extern task mon_rx(); 
    extern task mon_err_sig();
    
    extern virtual function void check_phase(uvm_phase phase);

endclass : ca_rx_tb_in_mon_c

/////////////////////////////////////////////////

//----------------------------------------------
function ca_rx_tb_in_mon_c::new(string name = "ca_rx_tb_in_mon", uvm_component parent = null);
    
    super.new(name, parent);
    `uvm_info("ca_rx_tb_in_mon_c::new", $sformatf("BUS_BIT_WIDTH == %0d", BUS_BIT_WIDTH), UVM_LOW);
    `uvm_info("ca_rx_tb_in_mon_c::new", $sformatf("NUM_CHANNELS  == %0d", NUM_CHANNELS), UVM_LOW);

endfunction : new

//----------------------------------------------
function void ca_rx_tb_in_mon_c::build_phase(uvm_phase phase);
    
    aport = new("aport", this);

    // get the interface
    if( !uvm_config_db #( virtual ca_rx_tb_in_if #(BUS_BIT_WIDTH, NUM_CHANNELS) )::get(this, "" , "ca_rx_tb_in_vif", vif) )  
        `uvm_fatal("build_phase", "unable to get ca_rx_tb_in vif")

endfunction: build_phase

//----------------------------------------------
task ca_rx_tb_in_mon_c::run_phase(uvm_phase phase);
    
    fork
        mon_rx();
        mon_err_sig();
    join 

endtask : run_phase

//----------------------------------------------
function void ca_rx_tb_in_mon_c::set_item(ca_data_pkg::ca_seq_item_c  item);

    item.is_tx          = 0;
    item.my_name        = my_name;
    item.bus_bit_width  = BUS_BIT_WIDTH;
    item.num_channels   = NUM_CHANNELS;
    item.stb_wd_sel     = cfg.rx_stb_wd_sel;
    item.stb_bit_sel    = cfg.rx_stb_bit_sel;
    item.stb_intv       = cfg.rx_stb_intv;

endfunction : set_item

//----------------------------------------------
function void ca_rx_tb_in_mon_c::gen_stb_beat();

    `uvm_info("gen_stb_beat", $sformatf("RX TB_out:"), UVM_LOW);
    stb_item = ca_data_pkg::ca_seq_item_c::type_id::create("stb_item") ;
    set_item(stb_item);
    stb_item.calc_stb_beat();

endfunction : gen_stb_beat

//----------------------------------------------
task ca_rx_tb_in_mon_c::mon_rx(); 

    logic [((BUS_BIT_WIDTH*NUM_CHANNELS)-1):0]    rx_data_prev[4]; 
    logic [((BUS_BIT_WIDTH*NUM_CHANNELS)-1):0]    rx_data      = 0; 
    logic [((BUS_BIT_WIDTH*NUM_CHANNELS*4)-1):0]  rx_data_fin  = 0; 
    ca_data_pkg::ca_seq_item_c                    ca_item;
    bit                                           calc_stb     = 1;
    bit[1:0]                                      is_stb_mark  = 0;
    int                                           i_max;
    bit [2:0]                                     clk_cnt;
    bit                                           rx_data_rdy  = 0;
    bit                                           rx_compare_start=0;
    logic [((BUS_BIT_WIDTH*NUM_CHANNELS)-1):0]    onlymark_data=0; 
    logic [((BUS_BIT_WIDTH*NUM_CHANNELS)-1):0]    onlystb_data=0; 
    logic [((BUS_BIT_WIDTH*NUM_CHANNELS)-1):0]    markstb_data=0; 
    int                                           index, stb_bit_pos;
    int                                           first_time_rst;
    forever begin @(posedge vif.clk)
        
       if (vif.rst_n == 1'b1) begin
            first_time_rst = first_time_rst + 1;
       end
       if (first_time_rst == 5) begin
            //$display("rx_tb_in_mon first_time_rst : %0d, marker %0d,my_name %s,time %0t",first_time_rst,vif.user_marker,my_name,$time);
            index = 0;
             for (int i=0; i<40; i+=1) begin
                 if (cfg.tx_stb_bit_sel[i]) begin
                     index = i;
                     break;
                 end
             end
             if (cfg.tx_stb_wd_sel[7:0]  == 8'h01) begin
                 stb_bit_pos = index;
             end else begin
                 stb_bit_pos = ($clog2(cfg.tx_stb_wd_sel[7:0])*40) + (index);
             end
          for (int i=0, ch=0; i<(BUS_BIT_WIDTH*NUM_CHANNELS); i+=1) begin
                 if ((i!=0) && (i%BUS_BIT_WIDTH == 0)) ch++;
           `ifdef GEN2
               `ifdef CA_ASYMMETRIC ///F2F case do not use Markers
                   if (BUS_BIT_WIDTH == 80) begin //H2F,Q2F 
                       onlymark_data[(ch*BUS_BIT_WIDTH) + `CA_TX_MARKER_LOC]     = vif.user_marker;  
                       markstb_data[(ch*BUS_BIT_WIDTH)  + `CA_TX_MARKER_LOC]     = vif.user_marker; 
                       markstb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]             = 1'b1; ///only for asym
                       onlystb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]             = 1'b1; ///only for asym
                   end 
               `endif//CA_ASYMMETRIC
                if (BUS_BIT_WIDTH == 160) begin //H2H, F2H, Q2H
                  for(int mk=0;mk<=1;mk++)begin ///80,160
                      onlymark_data[(ch*BUS_BIT_WIDTH) +`CA_TX_MARKER_LOC]       = vif.user_marker[mk];  
                      markstb_data[(ch*BUS_BIT_WIDTH)  +`CA_TX_MARKER_LOC]       = vif.user_marker[mk]; 
                  end
                      markstb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]              = 1'b1; 
                      onlystb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]              = 1'b1; 
                end else if (BUS_BIT_WIDTH == 320) begin //Q2Q, F2Q, H2Q
                  //for(int mk=0;mk<=3;mk++)begin ///80,160,240,320
                  //  onlymark_data[(ch*BUS_BIT_WIDTH) + (mk*80) + `CA_TX_MARKER_LOC]  = vif.user_marker[mk]; //1'b1; 
                  //  markstb_data[(ch*BUS_BIT_WIDTH)  + (mk*80) + `CA_TX_MARKER_LOC]  = vif.user_marker[mk]; //1'b1;
                  //end
                     onlymark_data[(ch*BUS_BIT_WIDTH) + 240 + `CA_TX_MARKER_LOC]  = 1;//vif.user_marker; 
                     markstb_data[(ch*BUS_BIT_WIDTH)  + 240 +`CA_TX_MARKER_LOC]   = 1;//vif.user_marker; 
                     markstb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]                = 1'b1; 
                     onlystb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]                = 1'b1; 
                end
           `else
                if(BUS_BIT_WIDTH == 40) begin
                    onlymark_data[(ch*BUS_BIT_WIDTH) + `CA_TX_MARKER_LOC]         = vif.user_marker;  
                    markstb_data[(ch*BUS_BIT_WIDTH) + `CA_TX_MARKER_LOC]          = vif.user_marker; 
                    markstb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]                 = 1'b1;
                    onlystb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]                 = 1'b1;
                end
              else if(BUS_BIT_WIDTH == 80) begin //40,80 => 80-160, 160-80
                    onlymark_data[(ch*BUS_BIT_WIDTH) + 40 + `CA_TX_MARKER_LOC]    = vif.user_marker;  
                    markstb_data[(ch*BUS_BIT_WIDTH)  + 40 + `CA_TX_MARKER_LOC]    = vif.user_marker; 
                    markstb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]                 = 1'b1;
                    onlystb_data[(ch*BUS_BIT_WIDTH)+ stb_bit_pos]                 = 1'b1;
              end
           `endif
          end
        end //for first_time_rst 

        if(vif.rst_n === 1'b0) begin 
            // reset state
            rx_active = 0;
            rx_cnt = 0;
            stb_cnt = 0;
            stb_sync = 0;
            if(calc_stb == 1) begin
                calc_stb = 0;
                gen_stb_beat();
            end
        end //for rst_n = 0
        else if((vif.rx_online === 1'b1) && (vif.align_done === 1'b1)) begin // non reset state
            calc_stb = 1; 
            stb_cnt++;
            rx_data = vif.rx_dout;
            rx_data_prev[3] = rx_data_prev[2];             
            rx_data_prev[2] = rx_data_prev[1];             
            rx_data_prev[1] = rx_data_prev[0];             
            rx_data_prev[0] = rx_data;             

`ifndef CA_ASYMMETRIC
 if((|rx_data !== 1'b0) && ((^rx_data) !== 1'bx)) begin 
                ca_item = ca_data_pkg::ca_seq_item_c::type_id::create("ca_item");
                rx_cnt=rx_cnt+1;
                set_item(ca_item);
                ca_item.init_xfer((BUS_BIT_WIDTH*NUM_CHANNELS) / 8);
                `uvm_info("mon_rx_tb_in", $sformatf("%s rx-ing rxRTL --> TB xfer: %0d rx_din: 0x%h", my_name, rx_cnt, rx_data), UVM_MEDIUM);
                for(int i = 0; i < (BUS_BIT_WIDTH*NUM_CHANNELS) / 8; i++) begin
                    ca_item.databytes[i] = rx_data[7:0];
                    rx_data = rx_data >> 8;
                 end // for
                 case(ca_item.is_stb_beat(stb_item))
                     2'b01: begin
                         ca_item.add_stb = 0;
                         if(((`TB_DIE_A_BUS_BIT_WIDTH == 160) && (`TB_DIE_B_BUS_BIT_WIDTH == 160)) || 
                            ((`TB_DIE_A_BUS_BIT_WIDTH == 320) && (`TB_DIE_B_BUS_BIT_WIDTH == 320)))begin
                             //$display("tx_tb_in_mon.sv inside H2H,Q2Q loop,time %0t",$time);
                             if(onlymark_data != rx_data_prev[0]) begin
                                 aport.write(ca_item);
                             end
                         end else begin
                              aport.write(ca_item); // data only
                        end
                     end
                     2'b10: begin
                         verify_rx_stb();  // stb only
                     end
                     2'b11: begin // both data and stb
                         if(((`TB_DIE_A_BUS_BIT_WIDTH == 160) && (`TB_DIE_B_BUS_BIT_WIDTH == 160)) || 
                            ((`TB_DIE_A_BUS_BIT_WIDTH == 320) && (`TB_DIE_B_BUS_BIT_WIDTH == 320)))begin //H2H and Q2Q cases
                              if(markstb_data != rx_data_prev[0]) begin
                                  aport.write(ca_item);
                              end
                              verify_rx_stb();  
                              ca_item.add_stb = 1;
                          end else begin
                              verify_rx_stb();  
                              ca_item.add_stb = 1;
                              aport.write(ca_item);
                          end
                     end
                     default: begin
                         ca_item.dprint();
                         //`uvm_fatal("mon_rx_tb_in", $sformatf("BAD case in is_stb_beat for above beat"));
                         `uvm_error("mon_rx_tb_in", $sformatf("BAD case in is_stb_beat for above beat"));
                     end
                 endcase
            end // if        
`else
            //$display("ca_rx_tb_in_mon_c ::: onlystb_data = %h onlymark_data = %h markstb_data %h,rx_data %h,time %0t,my_name %s",onlystb_data,onlymark_data,markstb_data,rx_data,$time,my_name);
           
           if((rx_compare_start == 1'b1) && ((onlystb_data == rx_data) || (onlymark_data == rx_data) || (markstb_data == rx_data) || (rx_data == 0)) )begin 
               rx_compare_start = 0; ///marks end-of actual Rx data out from DUT
           end else if((rx_compare_start == 1'b0) && ((onlystb_data != rx_data) && (onlymark_data != rx_data) && (markstb_data != rx_data) && (rx_data != 0))) begin
               rx_compare_start = 1; ///marks start-of actual Rx data out from DUT
           end

            if(((rx_compare_start ==1)) && ((^rx_data) !== 1'bx)) begin 
                ca_item = ca_data_pkg::ca_seq_item_c::type_id::create("ca_item");
                if((onlystb_data != rx_data) && (onlymark_data != rx_data) && (markstb_data != rx_data) && (rx_data != 0))  rx_cnt = rx_cnt+1;
                clk_cnt += 1'b1; 
                set_item(ca_item);
                ca_item.init_xfer((BUS_BIT_WIDTH*NUM_CHANNELS) / 8);
                `uvm_info("mon_rx_tb_in", $sformatf("%s rx-ing rxRTL --> TB xfer: %0d rx_din: 0x%h", my_name, rx_cnt, rx_data), UVM_MEDIUM);
                if(my_name == "DIE_A") `uvm_info("mon_rx_tb_in", $sformatf("%s rx-ing rxRTL --> TB xfer: %0d rx_din: 0x%h", my_name, rx_cnt, rx_data), UVM_MEDIUM);
                i_max = (BUS_BIT_WIDTH*NUM_CHANNELS*cfg.slave_rate)/8; //40*2*2/8
                  
                ///////////////////////////////////////////////////////////////////
                if ((cfg.master_rate == 4) && (cfg.slave_rate == 1)) begin //Q2F
                        rx_data_fin  = rx_data;
                        rx_data_rdy = 1;
                        ca_item.cnt_mul= cfg.master_rate/cfg.slave_rate;
                end

                if ((cfg.master_rate == 2) && (cfg.slave_rate == 1)) begin //H2F
                          rx_data_fin    = rx_data;
                          rx_data_rdy    = 1;
                          ca_item.cnt_mul     = cfg.master_rate/cfg.slave_rate; 
                end
 
                if ((cfg.master_rate == 4) && (cfg.slave_rate == 2)) begin //Q2H 
                      if(clk_cnt == cfg.slave_rate)  begin
                       for (int i=0; i< NUM_CHANNELS; i++) begin
                        rx_data_fin[2*(i*BUS_BIT_WIDTH) +: 2*BUS_BIT_WIDTH]  = {rx_data_prev[0][(i*BUS_BIT_WIDTH) +: BUS_BIT_WIDTH],rx_data_prev[1][(i*BUS_BIT_WIDTH) +: BUS_BIT_WIDTH]};
                        rx_data_rdy = 1;  
                        clk_cnt=0;
                        ca_item.cnt_mul= cfg.master_rate/cfg.slave_rate;
                       end
                      end
                end

                if ((cfg.master_rate == 1) && (cfg.slave_rate == 2)) begin //F2H
                        if(clk_cnt == cfg.slave_rate)  begin
                            for (int i=0; i< NUM_CHANNELS; i++) begin
                                rx_data_fin[2*(i*BUS_BIT_WIDTH) +: 2*BUS_BIT_WIDTH]  = {rx_data_prev[0][(i*BUS_BIT_WIDTH) +: BUS_BIT_WIDTH],rx_data_prev[1][(i*BUS_BIT_WIDTH) +: BUS_BIT_WIDTH]};
                            end
                            rx_data_rdy = 1;
                            clk_cnt     = 0;
                            ca_item.cnt_mul     = 1;
                        end
                end

                if ((cfg.master_rate == 2) && (cfg.slave_rate == 4)) begin //Q2H
                        rx_data_fin  = rx_data;
                        rx_data_rdy = 1;
                        ca_item.cnt_mul     = cfg.master_rate/cfg.slave_rate;
                end

                if ((cfg.master_rate == 1) && (cfg.slave_rate == 4)) begin //Q2F 
                      if(clk_cnt == cfg.slave_rate)  begin
                       for (int i=0; i< NUM_CHANNELS; i++) begin
                        rx_data_fin[4*(i*BUS_BIT_WIDTH) +: 4*BUS_BIT_WIDTH]  = {rx_data_prev[0][(i*BUS_BIT_WIDTH) +: BUS_BIT_WIDTH],rx_data_prev[1][(i*BUS_BIT_WIDTH) +: BUS_BIT_WIDTH],rx_data_prev[2][(i*BUS_BIT_WIDTH) +: BUS_BIT_WIDTH],rx_data_prev[3][(i*BUS_BIT_WIDTH) +: BUS_BIT_WIDTH]};
                       end
                        rx_data_rdy = 1;  
                        clk_cnt=0;
                        ca_item.cnt_mul     = 1;
                      end
                end
                ///////////////////////////////////////////////////////////////////
                if(rx_data_rdy == 1 ) begin
                    for(int i = 0; i < i_max; i++) begin
                        ca_item.databytes[i] = rx_data_fin[7:0];
                        rx_data_fin = rx_data_fin >> 8;
                    end //// for
                    clk_cnt = 0; //clearing clk_Cnt 
                    rx_data_rdy = 0 ;
                    ca_item.last_tx_cnt_a = cfg.last_tx_cnt_a;
                    ca_item.last_tx_cnt_b = cfg.last_tx_cnt_b;
                    aport.write(ca_item); // data only
                end//rx_data_rdy
            end // if rx_data!=x   
`endif //CA_ASYMMETRIC
        end // non reset 
    end // clk
endtask : mon_rx

//---------------------------------------------
function void ca_rx_tb_in_mon_c::verify_rx_stb();

    stb_beat_cnt++;
    if(stb_sync == 0) begin
        stb_sync = 1;
        if(stb_cnt >= 2 * cfg.rx_stb_intv) begin
            `uvm_error("verify_rx_stb", $sformatf("INIT: %s did NOT receive rx_stb within rx_stb_intv: %0d | act: %0d",
                my_name, cfg.rx_stb_intv, stb_cnt));
        end
    end
    else begin // sync

        if(stb_cnt != cfg.rx_stb_intv) begin
            `uvm_error("verify_rx_stb", $sformatf("%s did NOT rx stb_cnt: %0d  within rx_stb_intv: %0d | act: %0d",
                my_name, stb_beat_cnt, cfg.rx_stb_intv, stb_cnt));
        end
        else begin
            `uvm_info("verify_rx_stb", $sformatf("%s rx stb_cnt: %0d within rx_stb_intv: %0d | act: %0d",
                my_name, stb_beat_cnt, cfg.rx_stb_intv, stb_cnt), UVM_MEDIUM);
        end
        //
    end
    stb_cnt = 0;

endfunction : verify_rx_stb

    
//---------------------------------------------
task ca_rx_tb_in_mon_c::mon_err_sig(); 

    ca_data_pkg::ca_seq_item_c                ca_item;

    forever begin @(posedge vif.clk)
        
        if(vif.rst_n === 1'b0) begin 
            // reset state
            end
        else if(vif.rx_online === 1'b1) begin // non reset state
    
            if((vif.rx_stb_pos_err !== 1'b0 ) || (vif.rx_stb_pos_coding_err !== 1'b0) || vif.align_err !== 1'b0) begin 
                ca_item = ca_data_pkg::ca_seq_item_c::type_id::create("ca_item");
                set_item(ca_item);
                `uvm_warning("mon_err_sig", $sformatf("%s rx-ing error: rx_stb_pos_err: %h  rx_stb_pos_coding_err: %h align_err: %h",
                    my_name, vif.rx_stb_pos_err, vif.rx_stb_pos_coding_err, vif.align_err));
                ca_item.stb_pos_err        = vif.rx_stb_pos_err;
                ca_item.stb_pos_coding_err = vif.rx_stb_pos_coding_err;
                ca_item.align_err          = vif.align_err;
                aport.write(ca_item); 
            end // non error 
    
        end // non reset 
    end // clk

endtask : mon_err_sig    

//---------------------------------------------
function void ca_rx_tb_in_mon_c::check_phase(uvm_phase phase);

    if(rx_active == 1) `uvm_error("check_phase", $sformatf("TX pkt rx_active still active at EOT!"));
    
    if(vif.align_done !== 1'b1) begin
       `uvm_error("check_phase", $sformatf("%s align_done NEVER asserted! act: %0h", my_name, vif.align_done));
    end

endfunction : check_phase

////////////////////////////////////////////////////////////
`endif

