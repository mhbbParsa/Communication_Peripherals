# SystemVerilog Communication Peripherals
 
Two synthesizable SystemVerilog peripheral cores — an **I2C master controller** and an **SPI master** — each with a simple testbench. Written as a portfolio project; simulated in Verilog, not yet run on hardware.
 
## Contents
 
| File | Description |
|---|---|
| `I2C_controller.sv` | I2C master FSM: multi-byte read/write, ACK checking, bus-stall timeout. |
| `tb_I2C_controller.sv` | Testbench with a minimal open-drain bus model and slave that ACKs address + data bytes; drives one 2-byte write. |
| `SPI_master.sv` | Configurable SPI master: all 4 CPOL/CPHA modes, clock divider, CS setup/hold/idle timing. |
| `SPI_master_tb.sv` | Testbench driving randomized `tx_data` and `MISO` each cycle. |
 
---
 
## I2C_controller
 
Master-only I2C controller. Runs one transaction per `transmit` pulse: START → 7-bit address + R/W → (repeated) data byte + ACK → STOP.
 
**Features**
- Configurable transfer length via `BYTES_TO_TRANSFER`
- `CLOCK_DIVIDER` sets SCL frequency from `sys_clk`
- `TIMEOUT` aborts the transaction to STOP if a slave holds SCL low too long (basic clock-stretch timeout, not full clock-stretch support)
- ACK is checked after every byte; a NACK ends the transaction early
- 3-stage synchronizers on `sda_in`/`scl_in` for metastability
**Ports**
 
| Signal | Dir | Width | Description |
|---|---|---|---|
| `sys_clk` | in | 1 | System clock |
| `n_rst` | in | 1 | Async active-low reset |
| `transmit` | in | 1 | Pulse/hold high to start a transaction |
| `R_W` | in | 1 | 0 = write, 1 = read |
| `address` | in | 7 | Target 7-bit slave address |
| `data_out` | in | `8*BYTES_TO_TRANSFER` | Data to write (write transactions) |
| `sda_in`, `scl_in` | in | 1 | Bus lines as seen by the controller |
| `data_in` | out | `8*BYTES_TO_TRANSFER` | Data read from the bus (read transactions) |
| `sda_out`, `scl_out` | out | 1 | Bus drive signals — **must be wired open-drain with external pull-ups** at the top level, matching real I2C |
 
**Parameters:** `BYTES_TO_TRANSFER` (default 2), `CLOCK_DIVIDER` (default 1000), `TIMEOUT` (default 3000, in `sys_clk` cycles of stalled SCL)
 
**Known limitations**
- Testbench only exercises a write with an ACKing slave model — the read data path and a slave that actually stretches the clock aren't covered yet.
- A few internal registers (`sub_state`, `bit_ctr`, `byte_ctr`, `ack`, etc.) aren't cleared in the async reset block. Harmless in simulation (they land on a known value), but worth tying down before targeting real hardware where post-configuration state can be arbitrary.
---
 
## SPI_master
 
Configurable SPI master with independent setup/hold/idle timing and chip-select control.
 
**Features**
- All 4 SPI modes via `CPOL`/`CPHA`
- `CLOCK_DIVIDER` sets `sck` frequency from `sys_clk`
- `SETUP_CYCLES` / `HOLD_CYCLES` / `IDLE_CYCLES` — CS-to-clock and inter-frame timing, in `sys_clk` cycles
- `CS_BIT_MAX` — how far into the frame `n_cs` stays asserted (set to `DATA_WIDTH` to hold it for the whole frame)
- `tx_ready` / `rx_valid` handshake flags; back-to-back transfers if `transmit` is held high
**Ports**
 
| Signal | Dir | Width | Description |
|---|---|---|---|
| `sys_clk` | in | 1 | System clock |
| `n_rst` | in | 1 | Async active-low reset |
| `transmit` | in | 1 | Hold high to keep sending frames |
| `tx_data` | in | `DATA_WIDTH` | Word to transmit |
| `MISO` | in | 1 | Slave-in data line |
| `rx_data` | out | `DATA_WIDTH` | Last word received |
| `MOSI` | out | 1 | Master-out data line |
| `sck` | out | 1 | Serial clock |
| `n_cs` | out | 1 | Active-low chip select |
| `tx_ready` | out | 1 | High when `tx_data` can be loaded |
| `rx_valid` | out | 1 | Pulses high when `rx_data` is valid |
 
**Parameters:** `DATA_WIDTH` (default 16, must be ≥ 2), `CPOL` (1), `CPHA` (1), `CLOCK_DIVIDER` (6, must be even and ≥ 2), `SETUP_CYCLES` (1), `HOLD_CYCLES` (0), `IDLE_CYCLES` (1), `CS_BIT_MAX` (13)
 
**Known limitations**
- Testbench drives randomized `tx_data`/`MISO` and inspects the waveform — there's no self-checking scoreboard comparing expected vs. actual `rx_data`.
---
 
## Simulating
 
Both testbenches are plain SystemVerilog and should run in any SV-capable simulator (Vivado xsim, Questa/ModelSim, Verilator, Icarus Verilog with `-g2012`). Example with Icarus:
 
```bash
# I2C
iverilog -g2012 -o sim_i2c I2C_controller.sv tb_I2C_controller.sv
vvp sim_i2c
gtkwave tb.vcd     # tb_I2C_controller.sv dumps a VCD
 
# SPI
iverilog -g2012 -o sim_spi SPI_master.sv SPI_master_tb.sv
vvp sim_spi        # no VCD dump by default — add $dumpfile/$dumpvars to inspect waveforms
```
 
## Status
 
Simulation-only so far — neither core has been synthesized or run on an FPGA. Sharing as a reference / for feedback rather than as a drop-in verified IP block.
