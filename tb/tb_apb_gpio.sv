// tb_apb_gpio.sv
// Testbench for the PULP Platform apb_gpio IP.
// Drives APB write transactions to set all 32 pads to output mode,
// then walks the four required GPIO output patterns through PADOUT.

`timescale 1ns/1ps

module tb_apb_gpio;

    localparam APB_ADDR_WIDTH = 12;
    localparam PAD_NUM        = 32;
    localparam NBIT_PADCFG    = 4;

    // Register offsets from apb_gpio.sv (REG_* defines)
    localparam ADDR_PADDIR_00_31 = 12'h00;
    localparam ADDR_PADOUT_00_31 = 12'h0C;

    logic                      HCLK;
    logic                      HRESETn;
    logic                      dft_cg_enable_i;

    logic [APB_ADDR_WIDTH-1:0] PADDR;
    logic                [31:0] PWDATA;
    logic                      PWRITE;
    logic                      PSEL;
    logic                      PENABLE;
    logic                [31:0] PRDATA;
    logic                      PREADY;
    logic                      PSLVERR;

    logic   [PAD_NUM-1:0]      gpio_in;
    logic   [PAD_NUM-1:0]      gpio_in_sync;
    logic   [PAD_NUM-1:0]      gpio_out;
    logic   [PAD_NUM-1:0]      gpio_dir;
    logic   [PAD_NUM-1:0][NBIT_PADCFG-1:0] gpio_padcfg;
    logic                      interrupt;

    // ---------------------------------------------------------------
    // DUT instantiation
    // ---------------------------------------------------------------
    apb_gpio #(
        .APB_ADDR_WIDTH ( APB_ADDR_WIDTH ),
        .PAD_NUM        ( PAD_NUM        ),
        .NBIT_PADCFG    ( NBIT_PADCFG    )
    ) uut (
        .HCLK            ( HCLK            ),
        .HRESETn         ( HRESETn         ),
        .dft_cg_enable_i ( dft_cg_enable_i ),
        .PADDR           ( PADDR           ),
        .PWDATA          ( PWDATA          ),
        .PWRITE          ( PWRITE          ),
        .PSEL            ( PSEL            ),
        .PENABLE         ( PENABLE         ),
        .PRDATA          ( PRDATA          ),
        .PREADY          ( PREADY          ),
        .PSLVERR         ( PSLVERR         ),
        .gpio_in         ( gpio_in         ),
        .gpio_in_sync    ( gpio_in_sync    ),
        .gpio_out        ( gpio_out        ),
        .gpio_dir        ( gpio_dir        ),
        .gpio_padcfg     ( gpio_padcfg     ),
        .interrupt       ( interrupt       )
    );

    // ---------------------------------------------------------------
    // Clock generation: 100 MHz (10 ns period)
    // ---------------------------------------------------------------
    initial HCLK = 1'b0;
    always #5 HCLK = ~HCLK;

    // ---------------------------------------------------------------
    // APB write task
    // Follows the standard two-phase APB protocol:
    //   SETUP  : PSEL=1, PENABLE=0, address/data/PWRITE valid
    //   ACCESS : PSEL=1, PENABLE=1, transfer completes when PREADY=1
    // apb_gpio ties PREADY high, so ACCESS always completes in one cycle.
    // ---------------------------------------------------------------
    task automatic apb_write(input [APB_ADDR_WIDTH-1:0] addr, input [31:0] data);
        begin
            @(posedge HCLK);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b1;
            PADDR   <= addr;
            PWDATA  <= data;
            @(posedge HCLK);
            PENABLE <= 1'b1;
            @(posedge HCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
        end
    endtask

    // ---------------------------------------------------------------
    // Stimulus
    // ---------------------------------------------------------------
    initial begin
        // Idle / reset values
        dft_cg_enable_i = 1'b0;
        gpio_in         = 32'h0;
        PSEL            = 1'b0;
        PENABLE         = 1'b0;
        PWRITE          = 1'b0;
        PADDR           = '0;
        PWDATA          = '0;
        HRESETn         = 1'b0;

        repeat (4) @(posedge HCLK);
        HRESETn = 1'b1;
        repeat (2) @(posedge HCLK);

        $display("=====================================================");
        $display(" T=%0t : Configuring all 32 pads as OUTPUT (PADDIR=1)", $time);
        $display("=====================================================");
        apb_write(ADDR_PADDIR_00_31, 32'hFFFF_FFFF);
        repeat (2) @(posedge HCLK);

        // ---- Pattern 1: all 32 GPIOs to 1 ----
        $display("-----------------------------------------------------");
        $display(" T=%0t : PATTERN 1 - all 32 GPIOs = 1", $time);
        $display("-----------------------------------------------------");
        apb_write(ADDR_PADOUT_00_31, 32'hFFFF_FFFF);
        repeat (4) @(posedge HCLK);
        $display(" gpio_out = 32'b%b (0x%08h)", gpio_out, gpio_out);

        // ---- Pattern 2: upper 16 = 1, lower 16 = 0 ----
        $display("-----------------------------------------------------");
        $display(" T=%0t : PATTERN 2 - upper 16 = 1, lower 16 = 0", $time);
        $display("-----------------------------------------------------");
        apb_write(ADDR_PADOUT_00_31, 32'hFFFF_0000);
        repeat (4) @(posedge HCLK);
        $display(" gpio_out = 32'b%b (0x%08h)", gpio_out, gpio_out);

        // ---- Pattern 3: alternate GPIOs (pin0=1, pin1=0, pin2=1, ...) ----
        $display("-----------------------------------------------------");
        $display(" T=%0t : PATTERN 3 - alternating pins (0=H,1=L,2=H,...)", $time);
        $display("-----------------------------------------------------");
        apb_write(ADDR_PADOUT_00_31, 32'h5555_5555);
        repeat (4) @(posedge HCLK);
        $display(" gpio_out = 32'b%b (0x%08h)", gpio_out, gpio_out);

        // ---- Pattern 4: all IOs to 0 ----
        $display("-----------------------------------------------------");
        $display(" T=%0t : PATTERN 4 - all 32 GPIOs = 0", $time);
        $display("-----------------------------------------------------");
        apb_write(ADDR_PADOUT_00_31, 32'h0000_0000);
        repeat (4) @(posedge HCLK);
        $display(" gpio_out = 32'b%b (0x%08h)", gpio_out, gpio_out);

        $display("=====================================================");
        $display(" All four GPIO test patterns applied. Ending simulation.");
        $display("=====================================================");
        repeat (4) @(posedge HCLK);
        $finish;
    end

    // ---------------------------------------------------------------
    // Waveform dump for Questa (vsim -do) or any VCD-capable viewer
    // ---------------------------------------------------------------
    initial begin
        $dumpfile("sim/apb_gpio_tb.vcd");
        $dumpvars(0, tb_apb_gpio);
    end

endmodule
