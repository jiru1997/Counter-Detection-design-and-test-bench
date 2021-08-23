`timescale 1ns/1ps

interface detec_if (input clk, input rstn);
	logic [3:0] data;
	logic       incr;
	logic       decr;
	logic       error;   

	bit         has_coverage = 1;
	bit         has_checks   = 1;

	import uvm_pkg::*;
  `include "uvm_macros.svh"

  clocking drv_ck @(posedge clk);
  	default input #1ps output #1ps;
  	output  data;
  	input   incr, decr, error;
  endclocking

  clocking mon_ck @(posedge clk);
    default input #1ps output #1ps;
    input  incr, decr, error, data;
  endclocking

  covergroup all_possible_input_data @(posedge clk iff rstn);
    input_data: coverpoint data{
       bins possible_input[] = {[0:15]};
    }
  endgroup

  covergroup all_possible_flag @(posedge clk iff rstn);
  	incr_statue: coverpoint incr{
  	   type_option.weight = 0;
  	   bins high = {1};
  	   bins low = {0};
  	}
  	decr_statue: coverpoint decr{
  	   type_option.weight = 0;
  	   bins high = {1};
  	   bins low = {0};  	   
  	}
  	error_statue:coverpoint error{
  	   type_option.weight = 0;
  	   bins high = {1};
  	   bins low = {0};    	
  	}
  	statue_flag: cross incr_statue, decr_statue, error_statue{
  	   bins incr_high = binsof(incr_statue.high);
  	   bins incr_low  = binsof(incr_statue.low);
  	   bins decr_high = binsof(decr_statue.high);
  	   bins decr_low  = binsof(decr_statue.low);
  	   bins err_high  = binsof(error_statue.high);
  	   bins err_low   = binsof(error_statue.low);
  	   illegal_bins illegal1 = binsof(incr_statue.high) && binsof(decr_statue.high);
  	   illegal_bins illegal2 = binsof(decr_statue.high) && binsof(error_statue.high);
  	   illegal_bins illegal3 = binsof(incr_statue.high) && binsof(error_statue.high);
  	}
  endgroup

  covergroup all_possible_filp @(posedge clk iff rstn);
  	incr_flip: coverpoint incr{
  	  bins flip10 = (1 => 0);
  	  bins flip01 = (0 => 1);
  	}
  	decr_flip: coverpoint decr{
   	  bins flip10 = (1 => 0);
  	  bins flip01 = (0 => 1); 	
  	}
  	error_flip:coverpoint error{
  	  bins flip10 = (1 => 0);
  	  bins flip01 = (0 => 1);
  	}
  endgroup

  initial begin : coverage_control
    if(has_coverage) begin
      automatic all_possible_input_data cg0 = new();
      automatic all_possible_flag cg1 = new();
      automatic all_possible_filp cg2 = new();
    end
  end

  property increase_seq;
    @(posedge clk) (data === $past(data) + 1) |=> $rose(incr);
  endproperty
  cover property(increase_seq);

  property decrease_seq;
    @(posedge clk) (data === $past(data) - 1) |=> $rose(decr);
  endproperty
  cover property(decrease_seq);

  property error_seq;
  	@(posedge clk) ((data !== $past(data) - 1) && (data !== $past(data) + 1)) |=> $rose(error);
  endproperty
  cover property(error_seq);

  property increase_statue;
  	@(posedge clk) incr |-> (!error && !decr);
  endproperty
  cover property(increase_statue);

  property decrease_statue;
  	@(posedge clk) decr |-> (!error && !incr);
  endproperty
  cover property(decrease_statue); 

  property error_statue;
  	@(posedge clk) error |-> (!decr && !incr);
  endproperty
  cover property(error_statue);   

  initial begin: assertion_control
    fork
      forever begin
        wait(rstn == 0);
        $assertoff();
        wait(rstn == 1);
        if(has_checks) $asserton();
      end
    join_none
  end	
endinterface

interface clk_if   (output logic clk, output logic rstn);
    
  initial begin 
    clk <= 0;
    forever begin
      #5 clk <= !clk;
    end
  end
  
  initial begin 
    rstn <= 0;
    repeat(10) @(negedge clk);
    rstn <= 1;
  end
endinterface

module tb;
  logic  clk;
  logic  rstn;

  counter_detection dut(
   .clk             (clk),
   .reset           (rstn),
   .in_data         (vif.data),
   .incr            (vif.incr),
   .decr            (vif.decr),
   .error           (vif.error)
  );

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import counter_detec_pkg::*; 
  
  detec_if vif(.*);
  clk_if   cif(.*);

  initial begin 
    uvm_config_db#(virtual detec_if)::set(uvm_root::get(), "uvm_test_top.env.slave_agt",    "vif",          vif);
    uvm_config_db#(virtual detec_if)::set(uvm_root::get(), "uvm_test_top.env.master_agt",   "vif",          vif);
    uvm_config_db#(virtual detec_if)::set(uvm_root::get(),      "uvm_test_top.env.*",       "dect_intf",    vif);
    run_test("counter_base_test");
  end

endmodule