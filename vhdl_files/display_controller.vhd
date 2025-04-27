library ieee;
use ieee.std_logic_1164.all;    -- Standard logic definitions (std_logic, std_logic_vector, etc.)
use ieee.numeric_std.all;         -- Numeric operations (unsigned, to_integer, to_unsigned)

-- Entity declaration for a time-to-4-digit-display converter
entity display_controller is
    port (
        ms_count : in  unsigned(13 downto 0);  -- Input millisecond count (0..9999 ms)
        d3       : out std_logic_vector(3 downto 0); -- Thousands digit (seconds)
        d2       : out std_logic_vector(3 downto 0); -- Hundreds digit (hundred-milliseconds)
        d1       : out std_logic_vector(3 downto 0); -- Tens digit (tens of milliseconds)
        d0       : out std_logic_vector(3 downto 0); -- Ones digit (single milliseconds)
        dp       : out std_logic_vector(3 downto 0)  -- Decimal point control (active high)
    );
end entity display_controller;

-- Architecture: converts a raw millisecond count into four BCD digits and
-- toggles decimal point(s) as needed for display multiplexing or indication
architecture rtl of display_controller is
    -- Internal integer signals to hold extracted digits
    signal sec   : integer range 0 to 9;  -- Seconds digit (0..9 seconds)
    signal m100  : integer range 0 to 9;  -- Hundred-milliseconds digit (0..9)
    signal m10   : integer range 0 to 9;  -- Tens-of-milliseconds digit (0..9)
    signal m1    : integer range 0 to 9;  -- Milliseconds digit (0..9)
begin
    -- Combinational process: triggered whenever ms_count changes
    process(ms_count)
        -- Local variables for intermediate computation
        variable total_ms : integer;
        variable rmd      : integer;
    begin
        -- Convert unsigned ms_count to integer for arithmetic
        total_ms := to_integer(ms_count);
        -- Compute seconds digit (integer division by 1000)
        sec      <= total_ms / 1000;
        -- Remainder after subtracting seconds part (0..999 ms)
        rmd      := total_ms mod 1000;
        -- Extract hundred-milliseconds digit (0..9): divide by 100
        m100     <= rmd / 100;
        -- Tens-of-milliseconds: divide by 10, then take mod 10 to isolate
        m10      <= (rmd / 10) mod 10;
        -- Single-millisecond digit: remainder mod 10
        m1       <= rmd mod 10;
        -- Convert each digit back to 4-bit BCD and assign to outputs
        d3 <= std_logic_vector(to_unsigned(sec, 4));
        d2 <= std_logic_vector(to_unsigned(m100,4));
        d1 <= std_logic_vector(to_unsigned(m10, 4));
        d0 <= std_logic_vector(to_unsigned(m1, 4));
        -- Set decimal point pattern: active on most significant digit (d3) only
        -- "1000" means dp(3)='1', dp(2..0)='0'
        dp <= "1000";  
    end process;
end architecture rtl;  -- End of display_controller module
