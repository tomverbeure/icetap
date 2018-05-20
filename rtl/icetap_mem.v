
`default_nettype none

module icetap_mem
    #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8
    )(
        input                       wr_clk,
        input                       wr_ena,
        input      [ADDR_WIDTH-1:0] wr_addr,
        input      [DATA_WIDTH-1:0] wr_data,
        
        input                       rd_clk,
        input                       rd_ena,
        input      [ADDR_WIDTH-1:0] rd_addr,
        output reg [DATA_WIDTH-1:0] rd_data
    );

    reg [DATA_WIDTH-1:0] mem[0:(2<<ADDR_WIDTH)-1];

    always @(posedge wr_clk) begin
        if (wr_ena) begin
            mem[wr_addr] <= wr_data;
        end
    end

    always @(posedge rd_clk) begin
        if (rd_ena) begin
            rd_data <= mem[rd_addr];
        end
    end

endmodule

