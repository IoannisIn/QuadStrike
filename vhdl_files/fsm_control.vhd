library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm_control is
    port(
        clk          : in  std_logic;
        reset        : in  std_logic;
        ready        : in  std_logic;
        react        : in  std_logic;
        tick_1ms     : in  std_logic;
        rnd          : in  std_logic_vector(15 downto 0);
        elapsed_in   : in  unsigned(13 downto 0);
        start_timer  : out std_logic;
        stop_timer   : out std_logic;
        capture      : buffer std_logic;
        show_winner  : out std_logic;
        winner_idx   : buffer unsigned(1 downto 0);
        winner_time  : out unsigned(13 downto 0);
        zero_phase   : out std_logic;
        seq_idx      : out unsigned(2 downto 0);
        player_leds  : out std_logic_vector(3 downto 0);
        init_phase   : out std_logic;
        flash_on     : out std_logic
    );
end entity;

architecture rtl of fsm_control is
    -- FSM states
    type state_type is (INIT, IDLE, SEQ_ZERO, WAIT_RANDOM, WAIT_REACT, SHOW_TIME, WIN_SHOW);
    signal state       : state_type := INIT;
    -- edge detect for ready
    signal prev_ready  : std_logic := '0';
    -- player index
    signal player      : integer range 0 to 3 := 0;
    -- store times
    type time_arr     is array(0 to 3) of unsigned(13 downto 0);
    signal times       : time_arr := (others => (others => '0'));
    -- random delay
    signal rnd_delay   : integer := 0;
    signal rnd_count   : integer := 0;
    -- sequential-zero chase
    constant SEQ_DELAY : integer := 500;  -- ms per digit
    signal seq_count     : integer range 0 to SEQ_DELAY := 0;
    signal seq_count_out : unsigned(2 downto 0) := (others=>'0');
    signal seq_active    : std_logic := '0';
    -- INIT splash
    constant FLASH_PERIOD_MS : integer := 250;
    constant FLASH_CYCLES    : integer := 6;
    signal init_count  : integer range 0 to FLASH_PERIOD_MS := 0;
    signal flash_state : integer range 0 to FLASH_CYCLES    := 0;
begin

    process(clk)
        variable min_t : unsigned(13 downto 0);
        variable idx   : integer;
        variable rising_ready : boolean;
    begin
        if rising_edge(clk) then
            -- detect rising edge of ready
            rising_ready := (ready = '1' and prev_ready = '0');
            prev_ready   <= ready;

            -- de-assert control signals
            start_timer <= '0';
            stop_timer  <= '0';
            capture     <= '0';

            if reset = '1' then
                -- initialize everything
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

            else
                case state is
                    when INIT =>
                        if tick_1ms = '1' then
                            if init_count < FLASH_PERIOD_MS-1 then
                                init_count <= init_count + 1;
                            else
                                init_count <= 0;
                                if flash_state < FLASH_CYCLES-1 then
                                    flash_state <= flash_state + 1;
                                else
                                    state <= IDLE;
                                end if;
                            end if;
                        end if;

                    when IDLE =>
                        show_winner <= '0';
                        if rising_ready then
                            seq_active    <= '1';
                            seq_count     <= 0;
                            seq_count_out <= (others=>'0');
                            state         <= SEQ_ZERO;
                        end if;

                    when SEQ_ZERO =>
                        if tick_1ms = '1' then
                            seq_count <= seq_count + 1;
                            if seq_count = SEQ_DELAY-1 then
                                seq_count <= 0;
                                if seq_count_out < to_unsigned(6,3) then
                                    seq_count_out <= seq_count_out + 1;
                                end if;
                                if seq_count_out = to_unsigned(6,3) then
                                    seq_active <= '0';
                                    rnd_delay <= to_integer(unsigned(rnd(7 downto 0))) mod 2000 + 1000;
                                    rnd_count <= 0;
                                    state     <= WAIT_RANDOM;
                                end if;
                            end if;
                        end if;

                    when WAIT_RANDOM =>
                        if tick_1ms = '1' then
                            if rnd_count < rnd_delay then
                                rnd_count <= rnd_count + 1;
                            else
                                start_timer <= '1';
                                state       <= WAIT_REACT;
                            end if;
                        end if;

                    when WAIT_REACT =>
                        if react = '1' then
                            stop_timer <= '1';
                            capture    <= '1';
                            state      <= SHOW_TIME;
                        end if;

                    when SHOW_TIME =>
                        if capture = '1' then
                            times(player) <= elapsed_in;
                        end if;
                        if player < 3 then
                            if rising_ready then
                                player        <= player + 1;
                                seq_active    <= '1';
                                seq_count     <= 0;
                                seq_count_out <= (others=>'0');
                                state         <= SEQ_ZERO;
                            end if;
                        else
                            if rising_ready then
                                -- compute winner
                                min_t := times(0); idx := 0;
                                for i in 1 to 3 loop
                                    if times(i) < min_t then
                                        min_t := times(i); idx := i;
                                    end if;
                                end loop;
                                winner_idx  <= to_unsigned(idx,2);
                                winner_time <= times(idx);
                                show_winner <= '1';
                                state       <= WIN_SHOW;
                            end if;
                        end if;

                    when WIN_SHOW =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- outputs
    init_phase <= '1' when state = INIT else '0';
    flash_on   <= '1' when (flash_state mod 2 = 0 and state = INIT) else '0';
    zero_phase <= '1' when seq_active = '1' or state = WAIT_RANDOM else '0';
    seq_idx    <= seq_count_out;

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
    end process;

end architecture rtl;
