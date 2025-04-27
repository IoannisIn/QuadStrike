library ieee;
use ieee.std_logic_1164.all;    -- Standard logic definitions (std_logic)
use ieee.numeric_std.all;       -- Numeric types and arithmetic (unsigned)

-- Entity: Reaction Timer
-- Measures elapsed time in milliseconds between start and stop events
entity reaction_timer is
    port (
        clk        : in  std_logic;                 -- System clock input
        reset      : in  std_logic;                 -- Synchronous reset (active high)
        start      : in  std_logic;                 -- Start measurement signal (pulse)
        stop       : in  std_logic;                 -- Stop measurement signal (pulse)
        tick_1ms   : in  std_logic;                 -- 1 ms timing tick input
        elapsed_ms : out unsigned(13 downto 0);     -- Output: elapsed time count
        busy       : out std_logic;                 -- High while timing is in progress
        done       : out std_logic                  -- High when measurement is complete
    );
end entity reaction_timer;

architecture rtl of reaction_timer is
    -- FSM states: IDLE waiting, RUN while counting, FIN when stopped
    type state_type is (IDLE, RUN, FIN);
    signal state : state_type := IDLE;              -- Current state, starts in IDLE

    -- Millisecond counter register
    signal count : unsigned(13 downto 0) := (others => '0');
begin
    -- Main sequential process: handles state transitions and counting
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset: return to IDLE, clear counter
                state <= IDLE;
                count <= (others => '0');

            else
                -- FSM behavior by state
                case state is

                    when IDLE =>
                        -- In IDLE, wait for start pulse to begin timing
                        if start = '1' then
                            count <= (others => '0');  -- reset count at start
                            state <= RUN;              -- move to RUN state
                        end if;

                    when RUN =>
                        -- In RUN, increment on each 1ms tick, or stop on stop pulse
                        if stop = '1' then
                            state <= FIN;             -- stop timing, move to FIN
                        elsif tick_1ms = '1' then
                            count <= count + 1;      -- increment elapsed count
                        end if;

                    when FIN =>
                        -- In FIN, measurement done; allow restart if start pulse
                        if start = '1' then
                            count <= (others => '0');  -- clear for new measurement
                            state <= RUN;              -- start new measurement
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- Output assignments
    elapsed_ms <= count;                           -- drive elapsed time output
    busy       <= '1' when state = RUN else '0';   -- high while counting
    done       <= '1' when state = FIN else '0';   -- high when measurement finished

end architecture rtl;  -- End of reaction_timer module
