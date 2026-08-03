`timescale 1 ns / 1 ns   // timescale for the compilation unit

module cam (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        wr_en,       // write strobe
    input  logic [1:0]  wr_addr,     // which of the 4 entries to write
    input  logic [31:0] wr_data,     // value stored into that entry
    input  logic [31:0] search_key,  // value to search for; match responds in the same cycle
    output logic        match        // high when search_key is in a valid entry
);

    localparam int DEPTH = 4;

    // DEPTH entries of 32 bits. Reset clears entry_valid only, so unwritten
    // entries are ignored by the search regardless of what they hold.
    logic [31:0]       entries [DEPTH];
    logic [DEPTH-1:0]  entry_valid;

    // hit[i] is high when entry i is valid and matches search_key
    logic [DEPTH-1:0]  hit;

    // write port: one entry per cycle, selected by wr_addr
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            entry_valid <= '0;
        end
        else if (wr_en) begin
            entries[wr_addr]     <= wr_data;
            entry_valid[wr_addr] <= 1'b1;
        end
    end

    // search port: all entries compared in parallel, same cycle
    always_comb begin
        for (int i = 0; i < DEPTH; i++) begin
            hit[i] = entry_valid[i] && (entries[i] == search_key);
        end
    end

    assign match = |hit;

endmodule
