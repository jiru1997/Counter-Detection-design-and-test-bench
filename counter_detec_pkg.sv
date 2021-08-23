package counter_detec_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import agent_pkg::*;
  import agent_slave_pkg::*;

  class counter_reference extends uvm_component;
    bit[3:0]  prev_value;
    uvm_blocking_get_peek_port #(mon_data_t)  in_bgpk_port;
    uvm_tlm_analysis_fifo #(mon_slave_data_t) out_tlm_fifo;
    `uvm_component_utils(counter_reference)
    local virtual detec_if dect_intf;

    function new (string name = "counter_reference", uvm_component parent);
      super.new(name, parent);
      prev_value = 4'b0;
      in_bgpk_port = new("in_bgpk_port", this);
      out_tlm_fifo  = new("out_tlm_fifo" , this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual detec_if)::get(this,"","dect_intf", dect_intf)) begin
        `uvm_fatal("GETVIF","cannot get dect_intf handle from config DB")
      end
    endfunction

    task run_phase(uvm_phase phase);
      fork
        do_reset();
        do_packet();
      join
    endtask  

    task do_reset();
      forever begin
        @(negedge dect_intf.rstn);
        prev_value = 4'b0;
      end
    endtask 

    task do_packet();
      mon_slave_data_t  ot;
      mon_data_t        it;
      forever begin
        this.in_bgpk_port.get(it);
        //$display("it.data is %d",it.data);
        if(prev_value !== 4'b1111 && it.data === prev_value + 1) begin
          ot = INCREASE;
          prev_value = it.data;
        end
        else if(prev_value !== 4'b0 && it.data === prev_value - 1) begin
          ot = DECREASE;
          prev_value = it.data;
        end
        else begin
          ot = ERROR;
          prev_value = it.data;
        end
        if(dect_intf.rstn === 1'b0) begin 
          ot = RESET;
        end
        this.out_tlm_fifo.put(ot);
      end
    endtask    
  endclass

  class counter_checker extends uvm_scoreboard;
    local int err_count;
    local int total_count;
    local counter_reference refmod;

    uvm_tlm_analysis_fifo #(mon_data_t)       master_tlm_fifo;
    uvm_tlm_analysis_fifo #(mon_slave_data_t) slave_tlm_fifo;
    uvm_blocking_get_port #(mon_slave_data_t) exp_bg_port;

    `uvm_component_utils(counter_checker)

    function new (string name = "counter_checker", uvm_component parent);
      super.new(name, parent);
      this.err_count = 0;
      this.total_count = 0;
      slave_tlm_fifo = new("slave_tlm_fifo", this);
      exp_bg_port    = new("exp_bg_port", this);
      master_tlm_fifo = new("master_tlm_fifo", this);
    endfunction   

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // if(!uvm_config_db#(virtual detec_if)::get(this,"","dect_intf", dect_intf)) begin
      //   `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      // end
      this.refmod = counter_reference::type_id::create("refmod", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      refmod.in_bgpk_port.connect(master_tlm_fifo.blocking_get_peek_export);
      exp_bg_port.connect(refmod.out_tlm_fifo.blocking_get_export);
    endfunction

    task run_phase(uvm_phase phase);
      this.do_data_compare();
    endtask  

    task do_data_compare();
      mon_slave_data_t expt, mont;
      forever begin
        this.slave_tlm_fifo.get(mont);
        this.exp_bg_port.get(expt);
        this.total_count++;
        if(int'(mont) != int'(expt)) begin
          this.err_count++; #1ns;
          `uvm_error("[CMPERR]", $sformatf("%0dth times comparing but failed!", this.total_count))
        end
        else begin
          `uvm_info("[CMPSUC]",$sformatf("%0dth times comparing and succeeded!", this.total_count), UVM_LOW)
        end
      end
    endtask 
  endclass

  class counter_env extends uvm_env;
    counter_master_agent master_agt;
    counter_slave_agent  slave_agt;
    counter_checker      chker;

    `uvm_component_utils(counter_env)

    function new (string name = "counter_env", uvm_component parent);
      super.new(name, parent);
    endfunction    

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      this.chker = counter_checker::type_id::create("chker", this);
      this.master_agt = counter_master_agent::type_id::create("master_agt", this);
      this.slave_agt  = counter_slave_agent::type_id::create("slave_agt", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      master_agt.monitor.mon_ana_port.connect(chker.master_tlm_fifo.analysis_export);
      slave_agt.monitor.mon_ana_port.connect(chker.slave_tlm_fifo.analysis_export);
    endfunction
  endclass

  class counter_base_test extends uvm_test;
    counter_env env;
    `uvm_component_utils(counter_base_test)

    function new(string name = "mcdf_base_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = counter_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_root::get().set_report_verbosity_level_hier(UVM_LOW);
      uvm_root::get().set_report_max_quit_count(1);
      uvm_root::get().set_timeout(10ms);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      this.run_top_virtual_sequence();
      phase.drop_objection(this);
    endtask

    virtual task run_top_virtual_sequence();
      counter_master_sequence seq = new();
      seq.start(env.master_agt.sequencer);
    endtask
  endclass

  class counter_wrap_sequence extends uvm_sequence #(counter_trans);
    rand bit[3:0] data;

    constraint cstr{
      data inside {[0:15]};
    };

    `uvm_object_utils_begin(counter_wrap_sequence)
      `uvm_field_int(data, UVM_ALL_ON)
    `uvm_object_utils_end 

    `uvm_declare_p_sequencer(counter_master_sequencer)
    function new (string name = "counter_wrap_sequence");
      super.new(name);
    endfunction

    task body();
      send_trans1();
      send_trans2();
    endtask

    task send_trans1();
      counter_trans req, rsp;
      `uvm_do_with(req, {data == 4'b1111;});
      `uvm_info(get_type_name(), req.sprint(), UVM_HIGH)
      get_response(rsp);
      `uvm_info(get_type_name(), rsp.sprint(), UVM_HIGH)
      assert(rsp.rsp)
        else $error("[RSPERR] %0t error response received!", $time);
    endtask

    task send_trans2();
      counter_trans req, rsp;
      `uvm_do_with(req, {data == 4'b0000;});
      `uvm_info(get_type_name(), req.sprint(), UVM_HIGH)
      get_response(rsp);
      `uvm_info(get_type_name(), rsp.sprint(), UVM_HIGH)
      assert(rsp.rsp)
        else $error("[RSPERR] %0t error response received!", $time);
    endtask

    function void post_randomize();
      string s;
      s = {s, "AFTER RANDOMIZATION \n"};
      s = {s, "=======================================\n"};
      s = {s, "counter_sequence object content is as below: \n"};
      s = {s, super.sprint()};
      s = {s, "=======================================\n"};
      `uvm_info(get_type_name(), s, UVM_HIGH)
    endfunction
  endclass  

  class counter_wrap_test extends counter_base_test;
    `uvm_component_utils(counter_wrap_test)

    function new(string name = "counter_wrap_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      counter_wrap_sequence wrap_seq = new();
      wrap_seq.start(env.master_agt.sequencer);
    endtask
  endclass

  class counter_const_sequence extends uvm_sequence #(counter_trans);
    rand bit[3:0] data;
    int ntrans = 500;

    constraint cstr{
      data inside {[0:15]};
    };

    `uvm_object_utils_begin(counter_const_sequence)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(ntrans, UVM_ALL_ON)
    `uvm_object_utils_end 

    `uvm_declare_p_sequencer(counter_master_sequencer)
    function new (string name = "counter_const_sequence");
      super.new(name);
    endfunction

    task body();
      repeat(ntrans) send_trans();
    endtask

    task send_trans();
      counter_trans req, rsp;
      `uvm_do_with(req, {data == 0;});
      `uvm_info(get_type_name(), req.sprint(), UVM_HIGH)
      get_response(rsp);
      `uvm_info(get_type_name(), rsp.sprint(), UVM_HIGH)
      assert(rsp.rsp)
        else $error("[RSPERR] %0t error response received!", $time);
    endtask

    function void post_randomize();
      string s;
      s = {s, "AFTER RANDOMIZATION \n"};
      s = {s, "=======================================\n"};
      s = {s, "counter_sequence object content is as below: \n"};
      s = {s, super.sprint()};
      s = {s, "=======================================\n"};
      `uvm_info(get_type_name(), s, UVM_HIGH)
    endfunction
  endclass 

  class counter_const_test extends counter_base_test;
    `uvm_component_utils(counter_const_test)

    function new(string name = "counter_const_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      counter_const_sequence const_seq = new();
      const_seq.start(env.master_agt.sequencer);
    endtask
  endclass

  class counter_flip_sequence extends uvm_sequence #(counter_trans);
    rand bit[3:0] data;
    int ntrans = 10;

    constraint cstr{
      data inside {[0:15]};
    };

    `uvm_object_utils_begin(counter_flip_sequence)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(ntrans, UVM_ALL_ON)
    `uvm_object_utils_end 

    `uvm_declare_p_sequencer(counter_master_sequencer)
    function new (string name = "counter_flip_sequence");
      super.new(name);
    endfunction

    task body();
      repeat(ntrans) begin
       send_trans();
      end
    endtask

    task send_trans();
      counter_trans req, rsp;
      `uvm_do_with(req, {data == 4'b0001;});
      `uvm_info(get_type_name(), req.sprint(), UVM_HIGH)
      get_response(rsp);
      `uvm_info(get_type_name(), rsp.sprint(), UVM_HIGH)
      assert(rsp.rsp)
        else $error("[RSPERR] %0t error response received!", $time);
      `uvm_do_with(req, {data == 4'b0000;});
      `uvm_info(get_type_name(), req.sprint(), UVM_HIGH)
      get_response(rsp);
      `uvm_info(get_type_name(), rsp.sprint(), UVM_HIGH)
      assert(rsp.rsp)
        else $error("[RSPERR] %0t error response received!", $time);
    endtask

    function void post_randomize();
      string s;
      s = {s, "AFTER RANDOMIZATION \n"};
      s = {s, "=======================================\n"};
      s = {s, "counter_sequence object content is as below: \n"};
      s = {s, super.sprint()};
      s = {s, "=======================================\n"};
      `uvm_info(get_type_name(), s, UVM_HIGH)
    endfunction
  endclass 

  class counter_flip_test extends counter_base_test;
    `uvm_component_utils(counter_flip_test)

    function new(string name = "counter_flip_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      counter_flip_sequence flip_seq = new();
      flip_seq.start(env.master_agt.sequencer);
    endtask
  endclass

endpackage