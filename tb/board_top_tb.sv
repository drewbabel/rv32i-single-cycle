module board_top_tb ();

  int          checks = 0;
  int          errors = 0;

  logic        clk = 1'b0;
  logic        rst;
  logic [15:0] sw;
  logic [15:0] led;
  logic        uart_rx = 1'b1;
  logic        uart_tx;

  always #5 clk = ~clk;

  board_top dut (
      .clk    (clk),
      .rst    (rst),
      .sw     (sw),
      .led    (led),
      .uart_rx(uart_rx),
      .uart_tx(uart_tx)
  );

  task automatic do_reset();
    rst = 1;
    sw  = 16'h0;
    repeat (2) @(posedge clk);
    rst = 0;
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  task automatic check(input string name, input logic [15:0] got, input logic [15:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s got %04x exp %04x", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, board_top_tb);
    $readmemh("tests/gpio_test.hex", dut.imem_inst.mem);
    do_reset();

    repeat (6) @(posedge clk);
    check("led store", led, 16'hABCD);

    verdict();
  end

endmodule
