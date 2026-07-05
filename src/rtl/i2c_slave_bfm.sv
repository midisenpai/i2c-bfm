module i2c_slave_bfm(scl, sda);
  parameter BFM_NAME = "I2C Slave BFM";

  input logic scl;
  inout logic sda;

  parameter   clk_freq;
  time        period = 1s/clk_freq;

  const logic READ_C  = 1'b1;
  const logic WRITE_C = 1'b0;

  logic [6:0] addr;
  logic [7:0] rd_data;
  logic [7:0] wr_data = 8'h5b;
  logic       rw;
  logic       rd_ack = 1'b0;

  logic       sda_out;
  logic       sda_in;
  logic       sda_z   = 1'b1;

  assign sda = (sda_z == 1'b1) ? 'bz : 'b0;
  assign sda_in = sda;

  task i2c_s_await_transaction;
    begin
      $timeformat(-9, 2, " ns", 20);

      // Wait for falling edge of sda
      @(negedge sda_in);

      // Ensure sda negedge precedes scl negedge
      assert (scl == 1'b1);

      // Ensure sda remains low until scl negedge
      @(negedge scl or sda_in == 1'b1);
      assert (sda_in == 1'b0);

      $display("%t: %s - Transaction begin detected", $time, BFM_NAME);
    end
  endtask // i2c_s_await_transaction


  task i2c_s_addr_phase;
    begin
      $timeformat(-9, 2, " ns", 20);
      // $display("%t: I2C Slave - Address Phase", $time);

      // Read 7-bit address
      for(int i=0; i<7; i++) begin
	@(posedge scl);
        // Wait a small arbitrary amount of time, i2c is meant to be sampled
        // while SCL is high, not on it's rising edge. Data should not change
        // during SCL high though and with relatviely low protocol frequencies
        // relative to the simulation speed this shouldn't be an issue unless
        // you bring your frequency up to the precision of the simulator. And
        // if you do that, just bring your i2c frequency down just a smidge or
        // two.
        #1;
	addr = {addr[5:0], sda_in};
      end

      $display("%t: %s - Address found '%h'", $time, BFM_NAME, addr);

      // Read RW bit
      @(posedge scl);
      #1;
      rw <= sda_in;

      // Active low ACK bit
      // @(period/2);
      @(negedge scl);
      sda_z   <= 1'b0;
      sda_out <= 1'b0;

      // @(period);
      @(negedge scl);
      sda_z <= 1'b1;

    end
  endtask // i2c_s_addr_phase


  task wait_for_start;
    begin
      $timeformat(-9, 2, " ns", 20);

      while(1) begin
        // The SCL and SDA lines should be normally high
        while(scl != 1'b1 || sda_in != 1'b1);

        // Wait for a change
        @(edge scl or edge sda_in);

        // The SDA line should transition to low first
        assert(scl    == 1'b1);
        assert(sda_in == 1'b0);

        // Wait for a change
        @(edge scl or edge sda_in);

        // The SDA line should transition to low first
        assert(scl    == 1'b0);
        assert(sda_in == 1'b0);

        $display("%t: %s - Start pattern detected", $time, BFM_NAME);
      end
    end
  endtask // wait_for_start


  task i2c_rx_write_data;
    begin
      $timeformat(-9, 2, " ns", 20);
      $display("%t: %s - Write Phase", $time, BFM_NAME);

      while(1) begin
        // Read 8-bit data
        for(int i=0; i<8; i++) begin
	  @(posedge scl);
	  rd_data = {rd_data[6:0], sda_in};
          $display("%t: %s - Data %d found", $time, BFM_NAME, i);

          @(negedge scl or edge sda_in);
          // A data change during a high clock has occurred, indicating an
          // issue with the master or a stop.
          if(scl == 1'b1) begin
            $display("%t: %s - Early exit", $time, BFM_NAME);
            return;
          end
        end // for (int i=0; i<8; i++)

        $display("%t: %s - Begin ack...", $time, BFM_NAME);

        ////////////////////////////////
        // Active low ACK bit
        ////////////////////////////////
        // @(negedge scl);
        sda_z   <= 1'b0;
        sda_out <= 1'b0;

        @(negedge scl);
        sda_z   <= 1'b1;

        // // Wait for posedge scl or sda
        // @(posedge scl or posedge sda_in);
        // assert(sda_in == 1'b0);
        // assert(scl == 1'b1);

        // @(negedge scl or posedge sda_in);
        // assert(sda_in == 1'b1);
        // assert(scl == 1'b1);

        $display("%t: %s - Write Found '%h'", $time, BFM_NAME, rd_data);
      end // while (1)
    end
  endtask // read_data


  task m_write_data;
    begin
      $timeformat(-9, 2, " ns", 20);
      // $display("%t: I2C Slave - Write Phase", $time);

      while(1) begin
        // Read 8-bit data
        for(int i=0; i<8; i++) begin
	  @(posedge scl);
	  rd_data = {rd_data[6:0], sda_in};
        end

        ////////////////////////////////
        // Active low ACK bit
        ////////////////////////////////
        @(negedge scl);
        sda_z   <= 1'b0;
        sda_out <= 1'b0;

        @(negedge scl);
        sda_z   <= 1'b1;


        // Wait for posedge scl or sda
        @(posedge scl or posedge sda_in);
        assert(sda_in == 1'b0);
        assert(scl == 1'b1);

        @(negedge scl or posedge sda_in);
        assert(sda_in == 1'b1);
        assert(scl == 1'b1);

        $display("%t: %s - Write Found '%h'", $time, BFM_NAME, rd_data);
      end // while (1)
    end
  endtask // read_data


  task m_read_data;
    input logic [7:0] wr_data;

    begin
      do begin
	$timeformat(-9, 2, " ns", 20);
	$display("%t: %s - Read phase write data: '%h'", $time, BFM_NAME, wr_data);

	// Read 8-bit data
	for(int i=7; i>=0; i--) begin
          @(posedge scl);
	  sda_z = wr_data[i];
          $display("%t: %s - Data %d found", $time, BFM_NAME, i);
          #1;

          @(negedge scl or edge sda_in);
          // A data change during a high clock has occurred, indicating an
          // issue with the master or a stop.
          if(scl == 1'b1) begin
            $display("%t: %s - Early exit", $time, BFM_NAME);
            return;
          end
	end

        $display("%t: %s - Begin ack...", $time, BFM_NAME);

	// Active low ACK bit
	sda_z <= 1'b1;
	@(posedge scl);
        #10; // Wait for new value to settle
	rd_ack <= sda_in;
	@(negedge scl);

        if(rd_ack == '0) begin
          $display("%t: %s - Ack detected...", $time, BFM_NAME);
        end else begin
          $display("%t: %s - Nack detected...", $time, BFM_NAME);
        end

	// While the master acknowledges the transactions
      end while(rd_ack == 1'b0); // do begin
    end
  endtask // read_data


  // Main slave BFM operation
  initial begin
    sda_out <= 1'b0;
    sda_z   <= 1'b1;

    forever begin
      i2c_s_await_transaction();
      i2c_s_addr_phase();

      // If master write
      if(rw == WRITE_C) begin
	// m_write_data();
        i2c_rx_write_data();
      end else begin
	m_read_data(8'hAB);
      end
    end
  end
endmodule // i2c_slave_bfm
