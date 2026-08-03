`timescale 1 ns / 1 ns      // unit / precision for # delays
`default_nettype none       // undeclared identifiers are an error

module tb_cam;

    // Local parameters
    localparam int CLK_PERIOD      = 10;
    localparam int CLK_HALF_PERIOD = CLK_PERIOD / 2;

    // Signals
    logic        clk;
    logic        rst_n;
    logic        wr_en;
    logic [1:0]  wr_addr;
    logic [31:0] wr_data;
    logic [31:0] search_key;
    logic        match;

    int errors = 0;    // failed checks, read by the final verdict

    // Module
    cam dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (wr_en),
        .wr_addr    (wr_addr),
        .wr_data    (wr_data),
        .search_key (search_key),
        .match      (match)
    );

    // Clock
    initial clk = 1'b0;
    always  #CLK_HALF_PERIOD clk = ~clk;

    // Tasks
    // write one entry, taking effect at the next rising edge
    task automatic write_entry (input logic [1:0] a, input logic [31:0] d);
        wr_en   = 1'b1;
        wr_addr = a;
        wr_data = d;
        @(posedge clk);
        #1;
        wr_en = 1'b0;
    endtask

    // drive a key and check match against the expected value
    task automatic check_search (input logic [31:0] k,
                                 input logic        exp,
                                 input string       name);
        search_key = k;
        #1;
        if (match !== exp) begin
            errors++;
            $display("FAIL: %s (key=%08h match=%0b expected=%0b)", name, k, match, exp);
        end
        else begin
            $display("ok:   %s", name);
        end
    endtask

    // Stimulus
    initial begin
        wr_en      = 1'b0;
        wr_addr    = '0;
        wr_data    = '0;
        search_key = '0;

        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        rst_n = 1'b1;

        // no entry is valid after reset, so every key misses
        check_search(32'h0000_0000, 1'b0, "miss after reset, key zero");
        check_search(32'hDEAD_BEEF, 1'b0, "miss after reset, arbitrary key");
        
        // every entry is searchable, not just one
        write_entry(2'd0, 32'h1111_1111);
        write_entry(2'd1, 32'h2222_2222);
        write_entry(2'd2, 32'h3333_3333);
        write_entry(2'd3, 32'h4444_4444);
        check_search(32'h1111_1111, 1'b1, "hit on entry 0");
        check_search(32'h2222_2222, 1'b1, "hit on entry 1");
        check_search(32'h3333_3333, 1'b1, "hit on entry 2");
        check_search(32'h4444_4444, 1'b1, "hit on entry 3");

        // a written value is found
        write_entry(2'd2, 32'h0000_ABCD);
        check_search(32'h0000_ABCD, 1'b1, "hit on written entry");
        check_search(32'h0000_ABCE, 1'b0, "miss on key never written");

        // wr_en low: address and data change but nothing is stored
        wr_addr = 2'd3;
        wr_data = 32'hAAAA_AAAA;
        @(posedge clk);
        #1;
        check_search(32'hAAAA_AAAA, 1'b0, "miss when wr_en was low");



        // overwriting an entry retires the old value
        write_entry(2'd2, 32'h5555_5555);
        check_search(32'h0000_ABCD, 1'b0, "miss on overwritten value");
        check_search(32'h5555_5555, 1'b1, "hit on new value");

        // duplicates collapse to a single match
        write_entry(2'd1, 32'h5555_5555);
        check_search(32'h5555_5555, 1'b1, "hit with value in two entries");

        // no write forwarding: a write and a search in the same cycle
        // see the entry as it was before the write
        search_key = 32'h9999_9999;
        wr_en      = 1'b1;
        wr_addr    = 2'd0;
        wr_data    = 32'h9999_9999;
        #1;
        if (match !== 1'b0) begin
            errors++;
            $display("FAIL: same-cycle write is not visible to search");
        end
        else begin
            $display("ok:   same-cycle write is not visible to search");
        end
        @(posedge clk);
        #1;
        wr_en = 1'b0;
        check_search(32'h9999_9999, 1'b1, "hit on the cycle after the write");

        // reset clears validity, so everything misses again
        rst_n = 1'b0;
        @(posedge clk);
        #1;
        rst_n = 1'b1;
        check_search(32'h5555_5555, 1'b0, "miss after reset clears validity");

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d error(s)", errors);
        $finish;
    end

endmodule


`default_nettype wire       // restore the default
