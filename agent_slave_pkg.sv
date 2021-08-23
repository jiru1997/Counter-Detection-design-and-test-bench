package agent_slave_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum{INCREASE, DECREASE, ERROR, RESET} mon_slave_data_t;

  class counter_slave_monitor extends uvm_monitor;
    local virtual detec_if intf;
    uvm_analysis_port #(mon_slave_data_t) mon_ana_port;
    `uvm_component_utils(counter_slave_monitor)

    function new(string name="counter_slave_monitor", uvm_component parent);
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

    task mon_trans();
      mon_slave_data_t m;
      @(intf.mon_ck); 
      forever begin
        @(intf.mon_ck); #10ps;
        if(intf.mon_ck.incr === 1'b1) begin 
          m = INCREASE;
        end
        else if(intf.mon_ck.decr === 1'b1) begin 
          m = DECREASE;
        end
        else if(intf.mon_ck.error === 1'b1) begin 
          m = ERROR;
        end
        else begin
          m = RESET;
        end
        mon_ana_port.write(m);
      end
    endtask
  endclass

  class counter_slave_agent extends uvm_agent;
    counter_slave_monitor monitor;
    local virtual detec_if vif;

    `uvm_component_utils(counter_slave_agent)

    function new(string name = "counter_slave_agent", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual detec_if)::get(this,"","vif", vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      monitor = counter_slave_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      this.set_interface(vif);
    endfunction

    function void set_interface(virtual detec_if vif);
      monitor.set_interface(vif);
    endfunction
  endclass

endpackage