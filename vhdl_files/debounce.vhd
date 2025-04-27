library ieee;
use ieee.std_logic_1164.all;      -- Standard logic definitions (std_logic, std_logic_vector, etc.)
use ieee.numeric_std.all;         -- Numeric operations (integer arithmetic)

-- Entity declaration for a simple button debouncer
entity debounce is
    port (
        clk     : in  std_logic;    -- System clock input
        btn_in  : in  std_logic;    -- Raw (noisy) button input
        btn_out : out std_logic     -- Debounced (stable) button output
    );
end entity debounce;

-- Architecture: registers the button input, filters out glitches by requiring
-- the signal to remain stable for a fixed number of clock cycles
architecture rtl of debounce is
    -- Two-stage synchronizer signals to safely sample an asynchronous input
    signal sync_0, sync_1 : std_logic := '0';
    
    -- Counter to measure how long the input remains at a new level
    -- Range is chosen to span up to 50,000 clock cycles (e.g., 1 ms at 50 MHz)
    signal counter : integer range 0 to 49999 := 0;
    
    -- Holds the last debounced (stable) value of the button
    signal stable : std_logic := '0';
begin
    -- Main process triggers on the rising edge of the clock
    process(clk)
    begin
        if rising_edge(clk) then
            -- First stage: sample raw asynchronous input
            sync_0 <= btn_in;
            -- Second stage: further synchronize to clock domain
            sync_1 <= sync_0;
            
            -- If the synchronized input matches the stored stable value,
            -- there's no change, so reset the counter
            if sync_1 = stable then
                counter <= 0;
            else
                -- Input differs from stable: increment counter to confirm change
                counter <= counter + 1;
                -- Once counter exceeds threshold, accept new level as stable
                if counter > 49999 then
                    stable <= sync_1;   -- Update debounced output
                    counter <= 0;       -- Reset counter for next detection
                end if;
            end if;

            -- Assign the debounced signal to the output port
            btn_out <= stable;
        end if;
    end process;
end architecture rtl;  -- End of debounce module
