library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_controller is
    port (
        ms_count : in  unsigned(13 downto 0);  -- 0..9999 ms
        d3       : out std_logic_vector(3 downto 0);
        d2       : out std_logic_vector(3 downto 0);
        d1       : out std_logic_vector(3 downto 0);
        d0       : out std_logic_vector(3 downto 0);
        dp       : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of display_controller is
    signal sec   : integer range 0 to 9;
    signal m100  : integer range 0 to 9;
    signal m10   : integer range 0 to 9;
    signal m1    : integer range 0 to 9;
begin
    process(ms_count)
        variable total_ms : integer;
        variable rmd      : integer;
    begin
        total_ms := to_integer(ms_count);
        sec      <= total_ms / 1000;
        rmd      := total_ms mod 1000;
        m100     <= rmd / 100;
        m10      <= (rmd / 10) mod 10;
        m1       <= rmd mod 10;

        d3 <= std_logic_vector(to_unsigned(sec, 4));
        d2 <= std_logic_vector(to_unsigned(m100,4));
        d1 <= std_logic_vector(to_unsigned(m10, 4));
        d0 <= std_logic_vector(to_unsigned(m1, 4));
        -- decimal point after digit 3 (“sec.”)
        dp <= "1000";  
    end process;
end architecture;
