library ieee;
use ieee.std_logic_1164.all;    -- Standard logic definitions (std_logic, std_logic_vector, etc.)
use ieee.numeric_std.all;         -- Numeric operations for vector/integer conversions

-- Entity declaration: 16-bit Linear Feedback Shift Register
entity lfsr is
    port (
        clk     : in  std_logic;                     -- System clock input
        reset   : in  std_logic;                     -- Asynchronous reset (active high)
        enable  : in  std_logic;                     -- Enable signal for shifting
        rnd_out : out std_logic_vector(15 downto 0)  -- Current LFSR state output
    );
end entity lfsr;

-- Architecture: implements a Fibonacci LFSR with taps at bits 16, 14, 13, and 11
architecture rtl of lfsr is
    -- Internal register holding current LFSR state (initialized to a non-zero seed)
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"ACE1";
begin
    -- Sequential process: updates LFSR on each rising clock edge when enabled
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset condition: reload the initial seed value
                lfsr_reg <= x"ACE1";
            elsif enable = '1' then
                -- Shift left by one bit and insert new feedback bit at LSB
                -- Feedback polynomial: x^16 + x^14 + x^13 + x^11 + 1
                -- XOR taps: bit 15, bit 13, bit 12, and bit 10 (0-based indices)
                lfsr_reg <= lfsr_reg(14 downto 0) & 
                            (lfsr_reg(15) xor lfsr_reg(13) xor lfsr_reg(12) xor lfsr_reg(10));
            end if;
        end if;
    end process;

    -- Output the current LFSR state on every cycle
    rnd_out <= lfsr_reg;
end architecture rtl;  -- End of LFSR module
