module counter_detection(
  input clk,
  input reset,
  input[3:0] in_data,
  output incr,
  output decr,
  output error
);

  reg[3:0] prev_value;
  reg      incr_reg;
  reg      decr_reg;
  reg      error_reg;

  always @(posedge clk or negedge reset) begin
    if(!reset) begin
      prev_value <= 4'b0;
      incr_reg   <= 1'b0;
      decr_reg   <= 1'b0;
      error_reg  <= 1'b0;
    end 
    else if(prev_value !== 4'b1111 && in_data === prev_value + 1) begin
      prev_value <= in_data;
      incr_reg   <= 1'b1;
      decr_reg   <= 1'b0;
      error_reg  <= 1'b0; 
    end
    else if(prev_value !== 4'b0 && in_data === prev_value - 1) begin
      prev_value <= in_data;
      incr_reg   <= 1'b0;
      decr_reg   <= 1'b1;
      error_reg  <= 1'b0; 
    end   
    else begin
      prev_value <= in_data;
      incr_reg   <= 1'b0;
      decr_reg   <= 1'b0;
      error_reg  <= 1'b1;   
    end
  end

  assign incr = incr_reg;
  assign decr = decr_reg;
  assign error = error_reg;

endmodule