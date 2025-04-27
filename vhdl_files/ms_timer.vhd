library ieee;
use ieee.std_logic_1164.all;    -- Standard logic definitions (std_logic)
use ieee.numeric_std.all;       -- Numeric operations (integer types)

-- Entity: Millisecond Timer
-- Generates a 1 ms periodic tick based on a high-frequency clock
entity ms_timer is
    port (
        clk      : in  std_logic;  -- System clock input (e.g., 50 MHz)
        reset    : in  std_logic;  -- Active-high synchronous reset
        tick_1ms : out std_logic   -- Output pulse: high for one clock cycle every 1 ms
    );
end entity ms_timer;

architecture rtl of ms_timer is
    -- Calculate number of clock cycles per millisecond
    -- For a 50 MHz clock, 50,000 cycles = 1 ms; subtract 1 for zero-based count
    constant MAX_COUNT : integer := 50000 - 1;

    -- Counter signal: increments each clock until MAX_COUNT, then wraps
    signal count : integer range 0 to MAX_COUNT := 0;

    -- Internal tick signal: asserted for one cycle when count rolls over
    signal tick  : std_logic := '0';
begin
    -- Process triggered on each rising clock edge
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- On reset, clear counter and deassert tick
                count <= 0;
                tick  <= '0';

            elsif count = MAX_COUNT then
                -- When count reaches the threshold, generate tick and reset counter
                count <= 0;
                tick  <= '1';

            else
                -- Otherwise, increment counter and keep tick low
                count <= count + 1;
                tick  <= '0';
            end if;
        end if;
    end process;

    -- Output assignment: present internal tick to external port
    tick_1ms <= tick;

end architecture rtl;  -- End of ms_timer module
