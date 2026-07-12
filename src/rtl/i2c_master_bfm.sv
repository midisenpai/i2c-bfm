module i2c_master_bfm(scl, sda);
   output logic scl;
   inout  logic sda;

   parameter int clk_freq = 400000;
   time      period = 1s/(clk_freq);

   const logic READ_C  = 1'b1;
   const logic WRITE_C = 1'b0;

   logic     clk = 0;
   logic     read_ack;
   logic     write_ack;

   logic     sda_out;
   logic     sda_in;
   logic     sda_z   = 1'b0;


   // assign sda = (sda_z == 1'b1) ? sda_out : 'bz;
   assign sda = (sda_z == 1'b1) ? 'bz : sda_out;
   assign sda_in = sda;

   initial begin
      forever begin
	 #(period/2) clk = ~clk;
      end
   end


   task addr_phase;
      input  logic [6:0] addr;
      input  logic	 rw;
      output logic	 ack;

      begin
	 $timeformat(-9, 2, " ns", 20);
	 $display("%t: I2C Master - Address Phase - '%x'", $time, addr);
	 sda_z <= 1'b0;

	 @(posedge clk);
	 sda_out <= 0;

	 @(negedge clk);
	 scl = 0;

	 @(posedge clk);
	 @(negedge clk);

	 for(int i=6; i>=0; i--) begin
	    // $display("%t: I2C Master - Address Phase Bit - '%b'", $time, addr[i]);

	    // Address on falling edge
	    sda_out <= addr[i];
	    @(posedge clk);
	    scl = 1'b1;
	    @(negedge clk);
	    scl = 1'b0;
	 end

	 sda_out <= rw;
	 @(posedge clk);
	 scl = 1'b1;

	 @(negedge clk);
	 scl = 1'b0;
	 sda_z <= 1'b1; // TODO: HIGH Z

	 // Read Ack
	 @(posedge clk);
	 scl = 1'b1;
	 ack = sda_out;

	 @(negedge clk);
	 scl = 1'b0;
      end
   endtask // addr_phase


   task m_write_data;
      input [6:0] wr_addr;
      input [7:0] wr_data;

      begin
	 // Perform address write
	 addr_phase(.addr(wr_addr), .rw(WRITE_C), .ack(write_ack));

	 $timeformat(-9, 2, " ns", 20);
	 $display("%t: I2C Master - Write Phase - '%x'", $time, wr_data);
	 sda_z <= 1'b0;

	 // Write data
	 for(int i=7; i>=0; i--) begin
	    // Data on falling edge
	    sda_out <= wr_data[i];
	    @(posedge clk);
	    scl = 1'b1;
	    @(negedge clk);
	    scl = 1'b0;
	 end

	 // High-z for ack
	 sda_z <= 1'b1; // TODO: HIGH Z

	 // Read ack
	 @(posedge clk);
	 scl = 1'b1;
	 write_ack = sda_in;

	 // Return master line control
	 @(negedge clk);
	 scl = 1'b0;
	 sda_z   <= 1'b0;
	 sda_out <= 1'b0;

	 @(posedge clk);

	 @(posedge clk);
	 scl = 1'b1;

	 @(negedge clk);
	 sda_out <= 1'b1;
      end
   endtask // m_write_data


   task m_read_data;
      input  [6:0] rd_addr;
      output [7:0] rd_data;
      input  int   num_bytes;
      input  logic ack;

      begin
	 // Perform address write
	 addr_phase(.addr(rd_addr), .rw(READ_C), .ack(read_ack));

	 $timeformat(-9, 2, " ns", 20);
	 // $display("%t: I2C Master - Read Phase", $time);

	 for(int x=0; x<num_bytes; x++) begin
	    sda_z <= 1'b1; // TODO: HIGH Z

	    // Write data
	    for(int i=7; i>=0; i--) begin
	       @(posedge clk);
	       scl = 1'b1;
	       rd_data = {rd_data[6:0], sda_in};
	       @(negedge clk);
	       scl = 1'b0;
	    end

	    // Set ack value
	    sda_z   <= 1'b0;
	    sda_out <= ack;
	    @(posedge clk);
	    scl = 1'b1;

	    if(x == num_bytes-1) begin
	       // If last byte, retain control of lines
	       @(negedge clk);
	       scl = 1'b0;
	       sda_in <= 1'b0;
	    end else begin
	       // Return master line control
	       @(negedge clk);
	       scl = 1'b0;
	       sda_z <= 1'b1; // TODO: High Z
	    end
	    $display("%t: I2C Master - Read Phase Found: '%h'", $time, rd_data);
	 end

	 @(posedge clk);
	 @(posedge clk);
	 scl = 1'b1;

	 @(negedge clk);
	 // sda_in <= 1'b1;
	 sda_out <= 1'b1;
      end
   endtask // m_read_data

   initial
     begin
	sda_out <= 1'b1;
	sda_z   <= 1'b0;
	scl = 1'b1;
     end


endmodule // i2c_master_bfm
