library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lfsr is
    port (
        clk     : in std_logic;
        reset   : in std_logic;
        enable  : in std_logic;
        rnd_out : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of lfsr is
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"ACE1";
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                lfsr_reg <= x"ACE1";
            elsif enable = '1' then
                lfsr_reg <= lfsr_reg(14 downto 0) & 
                            (lfsr_reg(15) xor lfsr_reg(13) xor lfsr_reg(12) xor lfsr_reg(10));
            end if;
        end if;
    end process;

    rnd_out <= lfsr_reg;
end architecture;
