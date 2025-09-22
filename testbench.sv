`timescale 1ns/1ps

module tb_counter;

  localparam int WIDTH = 4;
  localparam CLK_PERIOD = 10;

  // DUT signals
  logic clk;
  logic rst_n;
  logic enable;
  logic [1:0] mode;
  logic [WIDTH-1:0] step_size;
  logic load;
  logic [WIDTH-1:0] load_value;
  logic auto_reload;

  logic [WIDTH-1:0] count;
  logic overflow, underflow, irq;
  logic [WIDTH-1:0] max_value, min_value, overflow_count, underflow_count, direction_changes;

  logic serial_enable, serial_out;
  logic [WIDTH-1:0] pwm_compare;
  logic pwm_out;

  logic [WIDTH-1:0] terminal_value;
  logic terminal_flag;

  // Instantiate DUT
  counter #(.WIDTH(WIDTH)) dut (.*);

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Dump waves
  initial begin
    $dumpfile("tb_counter.vcd");
    $dumpvars(0, tb_counter);
  end

  initial begin
    // Reset
    rst_n = 0;
    enable = 0;
    load = 0;
    serial_enable = 0;
    auto_reload = 1;
    pwm_compare = 4;
    terminal_value = 10;
    step_size = 2;
    mode = 2'b10;   
    load_value = 0;

    #20 rst_n = 1;
     #10;
    
    
    load_value = 1;  // Set the value to load
    load = 1;        // Assert load
    @(posedge clk);  // Wait for clock edge
    load = 0;        // Release load
    
    enable = 1;
    
    repeat (15) @(posedge clk);

    
     // Enable serial output for a while
    serial_enable = 1;
    repeat (WIDTH * 2) @(posedge clk); // Two full serial cycles
    serial_enable = 0;

    // Wait and watch PWM + terminal flag
    repeat (10) @(posedge clk);

    // Disable counter
    enable = 0;
    repeat (3) @(posedge clk); 
       $finish;
  end

endmodule


