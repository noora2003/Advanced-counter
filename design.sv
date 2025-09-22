`timescale 1ns/1ps

module counter #( parameter WIDTH = 3)                  // Counter width in bits
 (
  // Clock and Reset
    input  logic clk,
    input  logic rst_n,
    
    // Control Interface
    input  logic  enable,
  
    // Mode Control
    input  logic [1:0] mode,           // 00: up, 01: down, 10: auto up/down
    input  logic [WIDTH-1:0] step_size,    
    
  // Load Interface
    input  logic  load,
    input  logic [WIDTH-1:0] load_value,
    input  logic auto_reload, // Auto-reload on overflow/underflow
  
    // Counter Output
    output logic [WIDTH-1:0] count,
    output logic overflow,
    output logic underflow,
   // output logic direction,      // 0: up, 1: down
  
  // Interrupt
    output logic irq,
  
 // Statistical Outputs 
    output logic [WIDTH-1:0] max_value,
    output logic [WIDTH-1:0] min_value,
    output logic [WIDTH-1:0] overflow_count,
    output logic [WIDTH-1:0] underflow_count,
    output logic [WIDTH-1:0] direction_changes,
  
  // Serial Output 
    input  logic serial_enable,
    output logic serial_out,
  
   // PWM Output 
    input  logic [WIDTH-1:0] pwm_compare,
    output logic pwm_out,
  
  // Terminal Count 
    input  logic [WIDTH-1:0] terminal_value,
    output logic terminal_flag
  
   
    
);
 
    logic [WIDTH-1:0] count_next,count_reg; 
    logic overflow_detected, underflow_detected,direction_detected;           
    logic direction;         // 0: Up, 1: Down (for auto mode)
    logic [WIDTH-1:0] max_reg,min_reg,overflow_reg,underflow_reg, direction_reg;    
    logic [WIDTH-1:0] shift_serial_reg;        // Serial output shift register
    logic [$clog2(WIDTH)-1:0] index_next;

    logic [WIDTH-1:0] index;  // for serial 
    logic gated_clk;
	logic clk_enable;
  
  
  
  
  //---- counter mode logic ------
  always_comb begin 
    
    count_next = count_reg;
    overflow_detected = 1'b0;
    underflow_detected = 1'b0;
    direction_detected = 1'b0;
        index_next = index; // FIX: Default value for index_next

    
    if (enable) begin
      case (mode) 
 //-----   up mode ------        
      2'b00: begin      
        if (count_reg + step_size >= (1 << WIDTH)) begin         // counter reg+step >= 2^width
            overflow_detected = 1'b1;
          count_next = auto_reload ? load_value : (count_reg + step_size - (1 << WIDTH)); //load vaul=counter reg+step-2^width        
        end
        else begin
          count_next = count_reg + step_size;
        end
      end 
//---- down mode -----      
       2'b01:begin 
         
         if (count_reg < step_size) begin
            underflow_detected = 1'b1;
            count_next = auto_reload ? load_value : (count_reg - step_size + (1 << WIDTH));//load vaul=counter reg+step+2^width
         end
         else begin
           count_next = count_reg - step_size;
         end      
       end
        
 //----- Auto UP/DN -------
        2'b10:begin
          
         if (direction == 1'b0) begin         // Counting up
           if (count_reg + step_size >= (1 << WIDTH)) begin
                overflow_detected = 1'b1;
                count_next = auto_reload ? load_value : (count_reg + step_size - (1 << WIDTH));
                direction_detected = 1'b1;
               end else begin
                count_next = count_reg + step_size;
                 end
                 end
          
          else begin                // Counting down
           if (count_reg < step_size) begin
               underflow_detected = 1'b1;
             count_next = auto_reload ? load_value : (count_reg - step_size + (1 << WIDTH)); // 1-2+2^3=7
               direction_detected = 1'b1;
               end else begin
               count_next = count_reg - step_size;
                end
                end
        end
        
        default: count_next = count_reg;
      endcase
    end 
    
    
    if (serial_enable) begin
        if (index == WIDTH - 1) begin
            index_next = 0;
        end else begin
            index_next = index + 1;
        end
    end else begin
        index_next = 0;
    end
  end
    
//  end
  
  
  // latch to prevent the glitchs
  
  always_latch begin
    if (~clk) begin
       clk_enable <= enable;
    end
end
  
 assign gated_clk = clk & clk_enable;
 // assign gated_clk = clk & (clk_enable | load | serial_enable);
  
// Synchronous logic
    
  always_ff @(posedge gated_clk or negedge rst_n)begin
    
    if(!rst_n)begin
      count_reg <= {WIDTH{1'b0}};
      direction <= 1'b0;
      max_reg <= {WIDTH{1'b0}};
      min_reg <= {WIDTH{1'b1}};
      overflow_reg <= {WIDTH{1'b0}};
      underflow_reg <= {WIDTH{1'b0}};
      direction_reg <= {WIDTH{1'b0}};
      overflow <= 1'b0;
      underflow <= 1'b0;
      irq <=0;
      shift_serial_reg <=0;
      index <= 0; 
     // clk_enable <= 1'b0;

    end
 else begin
   
   if(load)begin
     count_reg <= load_value;
     max_reg <= load_value;
     min_reg <= load_value;
   end
   
   else if (enable) begin
     count_reg <= count_next;
     // Update max/min values
     if (count_next > max_reg) max_reg <= count_next;
     if (count_next < min_reg) min_reg <= count_next;
    
    // Update overflow/underflow counts
     if (overflow_detected) overflow_reg <= overflow_reg + 1;
     
     if (underflow_detected) underflow_reg <= underflow_reg + 1;
     
     // update direction change 
    if (mode == 2'b10 && direction_detected) begin
      direction <= ~direction;
      direction_reg <= direction_reg + 1 ;
    end
     
   end
   
   index <= index_next;
   
   if (serial_enable) begin
        // Load the counter value when starting serial output or when index wraps
        if (index == 0) begin
            shift_serial_reg <= count_reg;
        end
   end
   
   
    
 end

   // pulses
    
    overflow <= overflow_detected;
    underflow <= underflow_detected;
    irq <= overflow_detected || underflow_detected;
    
  
    
  end//always
  
  
  // serial output 
  assign serial_out = serial_enable ?  shift_serial_reg[WIDTH-1-index] : 1'b0;
  
  // PWM output
  assign pwm_out = (count_reg < pwm_compare) ? 1'b1 : 1'b0;
  
  // Terminal Count Detection
  
  assign terminal_flag = (count_reg == terminal_value ) ? 1'b1 : 1'b0;
  
  
 
  assign count = count_reg;
  assign max_value = max_reg;
  assign min_value = min_reg;
  assign overflow_count = overflow_reg;
  assign underflow_count = underflow_reg;
  assign direction_changes = direction_reg;

endmodule
