library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
    port (
        clk     : in std_logic;
        btn_in  : in std_logic;
        btn_out : out std_logic
    );
end entity;

architecture rtl of debounce is
    signal sync_0, sync_1 : std_logic := '0';
    signal counter : integer range 0 to 49999 := 0;
    signal stable : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            sync_0 <= btn_in;
            sync_1 <= sync_0;
            
            if sync_1 = stable then
                counter <= 0;
            else
                counter <= counter + 1;
                if counter > 49999 then
                    stable <= sync_1;
                    counter <= 0;
                end if;
            end if;
            btn_out <= stable;
        end if;
    end process;
end architecture;
