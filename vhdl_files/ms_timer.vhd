library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ms_timer is
    port (
        clk     : in std_logic;
        reset   : in std_logic;
        tick_1ms: out std_logic
    );
end entity;

architecture rtl of ms_timer is
    constant MAX_COUNT : integer := 50000 - 1;
    signal count : integer range 0 to MAX_COUNT := 0;
    signal tick : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                count <= 0;
                tick <= '0';
            elsif count = MAX_COUNT then
                count <= 0;
                tick <= '1';
            else
                count <= count + 1;
                tick <= '0';
            end if;
        end if;
    end process;

    tick_1ms <= tick;
end architecture;
