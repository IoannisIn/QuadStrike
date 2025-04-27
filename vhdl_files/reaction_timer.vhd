library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reaction_timer is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        start       : in  std_logic;
        stop        : in  std_logic;
        tick_1ms    : in  std_logic;
        elapsed_ms  : out unsigned(13 downto 0);
        busy        : out std_logic;
        done        : out std_logic
    );
end entity;

architecture rtl of reaction_timer is
    type state_type is (IDLE, RUN, FIN);
    signal state   : state_type := IDLE;
    signal count   : unsigned(13 downto 0) := (others=>'0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                count <= (others=>'0');
            else
                case state is
                    when IDLE =>
                        if start = '1' then
                            count <= (others=>'0');
                            state <= RUN;
                        end if;
                    when RUN =>
                        if stop = '1' then
                            state <= FIN;
                        elsif tick_1ms = '1' then
                            count <= count + 1;
                        end if;
                    when FIN =>
                        if start = '1' then
                            count <= (others=>'0');
                            state <= RUN;
                        end if;
                end case;
            end if;
        end if;
    end process;

    elapsed_ms <= count;
    busy       <= '1' when state = RUN else '0';
    done       <= '1' when state = FIN else '0';
end architecture;
