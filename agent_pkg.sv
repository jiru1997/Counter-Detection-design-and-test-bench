package agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class counter_trans extends uvm_sequence_item;
    rand bit[3:0] data;
    bit           rsp;

    constraint cstr{
      data inside {[0:15]};
    };

    `uvm_object_utils_begin(counter_trans)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(rsp, UVM_ALL_ON)
    `uvm_object_utils_end 

    function new (string name = "counter_trans");
      super.new(name);
    endfunction   
  endclass

  class counter_master_driver extends uvm_driver #(counter_trans);
    local virtual detec_if intf;
    `uvm_component_utils(counter_master_driver)

    function new (string name = "counter_master_driver", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void set_interface(virtual detec_if intf);
      if(intf == null)
        $error("interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
    endfunction

    task run_phase(uvm_phase phase);
      fork
       this.do_drive();
       this.do_reset();
      join
    endtask

    task do_reset();
      forever begin
        @(negedge intf.rstn);
        intf.data <= 4'b0;
      end
    endtask   

    task do_drive();
      counter_trans req, rsp;
      @(posedge intf.rstn);
      forever begin
        seq_item_port.get_next_item(req);
        this.chnl_write(req);
        void'($cast(rsp, req.clone()));
        rsp.rsp = 1;
        rsp.set_sequence_id(req.get_sequence_id());
        seq_item_port.item_done(rsp);
      end
    endtask 

    task chnl_write(input counter_trans t);
      @(posedge intf.clk);
      intf.drv_ck.data <= t.data;
    endtask
  endclass

  class counter_master_sequencer extends uvm_sequencer #(counter_trans);
    `uvm_component_utils(counter_master_sequencer)
    function new (string name = "counter_master_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class counter_master_sequence extends uvm_sequence #(counter_trans);
    rand bit[3:0] data;
    int ntrans = 500;

    constraint cstr{
      data inside {[0:15]};
    };

    `uvm_object_utils_begin(counter_master_sequence)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(ntrans, UVM_ALL_ON)
    `uvm_object_utils_end 

    `uvm_declare_p_sequencer(counter_master_sequencer)
    function new (string name = "counter_sequence");
      super.new(name);
    endfunction

    task body();
      repeat(ntrans) send_trans();
    endtask

    task send_trans();
      counter_trans req, rsp;
      `uvm_do(req);
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

//  typedef enum{INCREASE, DECREASE, ERROR} mon_data_t;
  typedef struct packed {
    bit[3:0] data;
  } mon_data_t;

  class counter_master_monitor extends uvm_monitor;
    local virtual detec_if intf;
    uvm_analysis_port #(mon_data_t) mon_ana_port;
    `uvm_component_utils(counter_master_monitor)

    function new(string name="counter_master_monitor", uvm_component parent);
      super.new(name, parent);
      mon_ana_port = new("mon_ana_port", this);
    endfunction   

    function void set_interface(virtual detec_if intf);
      if(intf == null)
        $error("interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
    endfunction 

    task run_phase(uvm_phase phase);
      this.mon_trans();
    endtask

    // task mon_trans();
    //   mon_data_t m;
    //   forever begin
    //     @(intf.mon_ck);
    //     if(intf.mon_ck.incr === 1'b1) begin 
    //       m = INCREASE;
    //     end
    //     else if(intf.mon_ck.decr === 1'b1) begin 
    //       m = DECREASE;
    //     end
    //     else if(intf.mon_ck.error === 1'b1) begin 
    //       m = ERROR;
    //     end
    //     mon_ana_port.write(m);
    //   end
    // endtask

    task mon_trans();
      mon_data_t m;
      forever begin
        @(intf.mon_ck);
        m.data = intf.mon_ck.data;
        mon_ana_port.write(m);
      end
    endtask
  endclass

  class counter_master_agent extends uvm_agent;
    counter_master_driver driver;
    counter_master_monitor monitor;
    counter_master_sequencer sequencer;
    local virtual detec_if vif;

    `uvm_component_utils(counter_master_agent)

    function new(string name = "counter_master_agent", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual detec_if)::get(this,"","vif", vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      driver = counter_master_driver::type_id::create("driver", this);
      monitor = counter_master_monitor::type_id::create("monitor", this);
      sequencer = counter_master_sequencer::type_id::create("sequencer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      this.set_interface(vif);
    endfunction

    function void set_interface(virtual detec_if vif);
      driver.set_interface(vif);
      monitor.set_interface(vif);
    endfunction
  endclass

endpackage