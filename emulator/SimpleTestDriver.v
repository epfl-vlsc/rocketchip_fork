`ifndef RESET_DELAY
    `define RESET_DELAY 10
`endif
`ifndef MODEL
    `define MODEL SimpleHarness
`endif


module Main(
    input wire clk
);

    logic reset = 1'b0;

    logic [63:0] cycle_counter = 0;

    logic verbose = 1'b0;
    wire printf_cond = verbose && !reset;

    logic [63:0] max_cycles;

    initial begin

        if (!$value$plusargs("max-cycles=%d", max_cycles)) begin
            max_cycles = 1000;
        end
        verbose = $test$plusargs("verbose");

    end

    always_ff @(posedge clk) reset <= (cycle_counter < `RESET_DELAY);
    always_ff @(posedge clk) begin

        cycle_counter <= cycle_counter + 1;
        if (cycle_counter == max_cycles) begin
            $display("@%d: Timed out!", cycle_counter);
            $finish;
        end

    end
    `MODEL testHarness(
        .clock(clk),
        .reset(reset),
        .io_success()
    );

endmodule
