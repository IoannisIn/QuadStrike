library ieee;
use ieee.std_logic_1164.all;    -- Standard logic definitions (std_logic, std_logic_vector, etc.)
use ieee.numeric_std.all;       -- Numeric operations (unsigned, integer conversions)

-- Entity declaration: top-level finite state machine for reaction-timer game control
entity fsm_control is
    port(
        clk          : in  std_logic;                     -- System clock
        reset        : in  std_logic;                     -- Asynchronous reset (active high)
        ready        : in  std_logic;                     -- Player "ready" button input
        react        : in  std_logic;                     -- Player "react" button input
        tick_1ms     : in  std_logic;                     -- 1 ms timing tick
        rnd          : in  std_logic_vector(15 downto 0); -- Random seed input
        elapsed_in   : in  unsigned(13 downto 0);         -- Elapsed ms from timer
        start_timer  : out std_logic;                     -- Pulse to start timing
        stop_timer   : out std_logic;                     -- Pulse to stop timing
        capture      : buffer std_logic;                  -- Capture signal for elapsed time
        show_winner  : out std_logic;                     -- Indicates winner display phase
        winner_idx   : buffer unsigned(1 downto 0);       -- Index of winning player (0–3)
        winner_time  : out unsigned(13 downto 0);         -- Winning elapsed time
        zero_phase   : out std_logic;                     -- Assert during zero-sequence or wait-random
        seq_idx      : out unsigned(2 downto 0);          -- Current zero-sequence LED index
        player_leds  : out std_logic_vector(3 downto 0);  -- One-hot LEDs for active player
        init_phase   : out std_logic;                     -- Assert during initial flash phase
        flash_on     : out std_logic                      -- Toggles LEDs during init flash
    );
end entity fsm_control;

architecture rtl of fsm_control is
    -- FSM state enumeration
    type state_type is (INIT, IDLE, SEQ_ZERO, WAIT_RANDOM, WAIT_REACT, SHOW_TIME, WIN_SHOW);
    signal state       : state_type := INIT;  -- Current FSM state, starts in INIT

    -- Edge detector for "ready" input
    signal prev_ready  : std_logic := '0';

    -- Index of current player (0 to 3)
    signal player      : integer range 0 to 3 := 0;

    -- Array to store each player's reaction time
    type time_arr     is array(0 to 3) of unsigned(13 downto 0);
    signal times       : time_arr := (others => (others => '0'));

    -- Variables for random delay before allowing reaction
    signal rnd_delay   : integer := 0;  -- Chosen delay in ms
    signal rnd_count   : integer := 0;  -- Counts up to rnd_delay

    -- Zero-sequence (chase) constants and signals
    constant SEQ_DELAY : integer := 500;  -- ms per LED in sequence
    signal seq_count     : integer range 0 to SEQ_DELAY := 0;  -- ms counter
    signal seq_count_out : unsigned(2 downto 0) := (others=>'0');  -- LED index 0–6
    signal seq_active    : std_logic := '0';  -- Assert while sequence running

    -- INIT flash parameters: flash period and number of cycles
    constant FLASH_PERIOD_MS : integer := 250;  -- ms per flash toggle
    constant FLASH_CYCLES    : integer := 6;    -- number of toggles
    signal init_count  : integer range 0 to FLASH_PERIOD_MS := 0;
    signal flash_state : integer range 0 to FLASH_CYCLES    := 0;
begin

    -- Main sequential process: handles state transitions and control signals
    process(clk)
        -- Variables for winner computation and edge detection
        variable min_t         : unsigned(13 downto 0);
        variable idx           : integer;
        variable rising_ready  : boolean;
    begin
        if rising_edge(clk) then
            -- Detect rising edge of ready button
            rising_ready := (ready = '1' and prev_ready = '0');
            prev_ready   <= ready;

            -- Default de-asserted outputs each cycle
            start_timer <= '0';
            stop_timer  <= '0';
            capture     <= '0';

            if reset = '1' then
                -- Reset: initialize all FSM registers and signals
                state         <= INIT;
                prev_ready    <= '0';
                player        <= 0;
                show_winner   <= '0';
                winner_idx    <= (others=>'0');
                winner_time   <= (others=>'0');
                rnd_count     <= 0;
                rnd_delay     <= 0;
                seq_active    <= '0';
                seq_count     <= 0;
                seq_count_out <= (others=>'0');
                init_count    <= 0;
                flash_state   <= 0;

            else  -- Normal operation
                case state is

                    when INIT =>  -- Initial LED flash sequence
                        if tick_1ms = '1' then
                            if init_count < FLASH_PERIOD_MS - 1 then
                                init_count <= init_count + 1;  -- count ms
                            else
                                init_count <= 0;
                                if flash_state < FLASH_CYCLES - 1 then
                                    flash_state <= flash_state + 1;  -- next toggle
                                else
                                    state <= IDLE;  -- done flashing, go idle
                                end if;
                            end if;
                        end if;

                    when IDLE =>  -- Wait for player to signal ready
                        show_winner <= '0';  -- clear winner display
                        if rising_ready then
                            seq_active    <= '1';  -- start zero-sequence
                            seq_count     <= 0;
                            seq_count_out <= (others=>'0');
                            state         <= SEQ_ZERO;
                        end if;

                    when SEQ_ZERO =>  -- Running LED chase before reaction window
                        if tick_1ms = '1' then
                            seq_count <= seq_count + 1;
                            if seq_count = SEQ_DELAY - 1 then
                                seq_count <= 0;
                                if seq_count_out < to_unsigned(6,3) then
                                    seq_count_out <= seq_count_out + 1;  -- advance LED
                                end if;
                                if seq_count_out = to_unsigned(6,3) then
                                    -- chase done: pick random delay then wait
                                    seq_active <= '0';
                                    rnd_delay  <= to_integer(unsigned(rnd(7 downto 0))) mod 2000 + 1000;
                                    rnd_count  <= 0;
                                    state      <= WAIT_RANDOM;
                                end if;
                            end if;
                        end if;

                    when WAIT_RANDOM =>  -- Random delay before allowing reaction
                        if tick_1ms = '1' then
                            if rnd_count < rnd_delay then
                                rnd_count <= rnd_count + 1;
                            else
                                start_timer <= '1';  -- begin reaction timing
                                state       <= WAIT_REACT;
                            end if;
                        end if;

                    when WAIT_REACT =>  -- Await player reaction
                        if react = '1' then
                            stop_timer <= '1';  -- stop the timer
                            capture    <= '1';  -- latch elapsed time
                            state      <= SHOW_TIME;
                        end if;

                    when SHOW_TIME =>  -- Record time and either next player or compute winner
                        if capture = '1' then
                            times(player) <= elapsed_in;  -- store elapsed time
                        end if;
                        if player < 3 then
                            if rising_ready then
                                -- move to next player
                                player        <= player + 1;
                                seq_active    <= '1';
                                seq_count     <= 0;
                                seq_count_out <= (others=>'0');
                                state         <= SEQ_ZERO;
                            end if;
                        else
                            if rising_ready then
                                -- all players done: find min time (winner)
                                min_t := times(0);
                                idx   := 0;
                                for i in 1 to 3 loop
                                    if times(i) < min_t then
                                        min_t := times(i);
                                        idx   := i;
                                    end if;
                                end loop;
                                winner_idx  <= to_unsigned(idx,2);
                                winner_time <= times(idx);
                                show_winner <= '1';
                                state       <= WIN_SHOW;
                            end if;
                        end if;

                    when WIN_SHOW =>
                        -- Hold winner display until reset
                        null;

                end case;
            end if;
        end if;
    end process;

    -- Concurrent output assignments based on current state/signals
    init_phase <= '1' when state = INIT else '0';
    flash_on   <= '1' when (flash_state mod 2 = 0 and state = INIT) else '0';
    zero_phase <= '1' when (seq_active = '1' or state = WAIT_RANDOM) else '0';
    seq_idx    <= seq_count_out;

    -- LED one-hot driver: highlights active player or winner
    player_leds_proc: process(player, state, winner_idx)
    begin
        if state = WIN_SHOW then
            case winner_idx is
                when "00" => player_leds <= "0001";
                when "01" => player_leds <= "0010";
                when "10" => player_leds <= "0100";
                when "11" => player_leds <= "1000";
                when others => player_leds <= "0000";
            end case;
        else
            case player is
                when 0 => player_leds <= "0001";
                when 1 => player_leds <= "0010";
                when 2 => player_leds <= "0100";
                when 3 => player_leds <= "1000";
                when others => player_leds <= "0000";
            end case;
        end if;
    end process player_leds_proc;

end architecture rtl;  -- End of FSM control module
