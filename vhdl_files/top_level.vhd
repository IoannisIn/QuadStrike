library ieee;
use ieee.std_logic_1164.all;    -- Standard logic definitions (std_logic, std_logic_vector, etc.)
use ieee.numeric_std.all;       -- Numeric operations for unsigned, conversions

-- Top-level module: integrates debounce, timers, LFSR, FSM, and display
-- for a 4-player reaction timer game on a 7-segment hex display and LEDs.
entity top_level is
    port(
        CLOCK_50    : in  std_logic;                    -- 50 MHz system clock
        KEY         : in  std_logic_vector(2 downto 0); -- Push-buttons: [0]=ready, [1]=react, [2]=reset
        HEX5,HEX4,  -- 7-segment display outputs for HEX5 down to HEX0
        HEX3,HEX2,HEX1,HEX0 : out std_logic_vector(0 to 6);
        LEDR        : out std_logic_vector(3 downto 0)  -- One-hot player status LEDs
    );
end entity top_level;

architecture rtl of top_level is

    -- Type definitions for grouped signal arrays
    type seg7_arr6_t is array (0 to 5) of std_logic_vector(6 downto 0);  -- 6-digit segment patterns
    type seg7_arr4_t is array (0 to 3) of std_logic_vector(6 downto 0);  -- 4-digit segment patterns
    type bcd_arr4_t  is array (0 to 3) of std_logic_vector(3 downto 0);  -- 4 BCD digits

    -- Debounced button signals
    signal btn_rdy, btn_react, btn_rst : std_logic;
    -- Millisecond tick signal
    signal tick_1ms                    : std_logic;
    -- Random number output from LFSR
    signal rnd_out                     : std_logic_vector(15 downto 0);
    -- Reaction timer interface signals
    signal start_t, stop_t, busy_t, done_t : std_logic;
    signal elapsed_time                : unsigned(13 downto 0);

    -- FSM control outputs
    signal zero_phase_sig              : std_logic;        -- high during zero-sequence or random wait
    signal seq_idx_sig                 : unsigned(2 downto 0); -- current index in zero chase
    signal show_win_sig                : std_logic;        -- high during winner display
    signal win_idx_sig                 : unsigned(1 downto 0); -- winning player index
    signal winner_time_sig             : unsigned(13 downto 0);-- winning reaction time
    signal player_leds_sig             : std_logic_vector(3 downto 0); -- one-hot for active/winner
    signal init_phase_sig              : std_logic;        -- high during initial flash
    signal flash_on_sig                : std_logic;        -- toggles LED pattern during init

    -- Live-time display digits and decimal points
    signal d3,d2,d1,d0                  : std_logic_vector(3 downto 0);
    signal dp_time                     : std_logic_vector(3 downto 0);
    signal bcd_digits                  : bcd_arr4_t;
    signal seg_time                    : seg7_arr4_t;      -- 4-digit segment patterns for elapsed time

    -- Zero-sequence display patterns
    signal seg_zero                    : seg7_arr6_t;      -- 6-digit zeros

    -- Winner display segment for winner number
    signal seg_winner                  : std_logic_vector(6 downto 0);
    -- Winner time display
    signal w_d3,w_d2,w_d1,w_d0         : std_logic_vector(3 downto 0);
    signal w_dp                        : std_logic_vector(3 downto 0);
    signal seg_wt                      : seg7_arr4_t;

    -- Constant for blank (all segments off)
    constant BLANK : std_logic_vector(6 downto 0) := (others=>'1');

begin

    -- Debounce each button: invert KEY inputs (active low) then filter
    db_rdy:   entity work.debounce port map(clk=>CLOCK_50, btn_in=>not KEY(0), btn_out=>btn_rdy);
    db_react: entity work.debounce port map(clk=>CLOCK_50, btn_in=>not KEY(1), btn_out=>btn_react);
    db_rst:   entity work.debounce port map(clk=>CLOCK_50, btn_in=>not KEY(2), btn_out=>btn_rst);

    -- Millisecond timer: generates tick_1ms pulse for every 1 ms
    ms_i:     entity work.ms_timer port map(clk=>CLOCK_50, reset=>btn_rst, tick_1ms=>tick_1ms);

    -- 16-bit LFSR: continuous random sequence generator
    lfsr_i:   entity work.lfsr port map(clk=>CLOCK_50, reset=>btn_rst, enable=>'1', rnd_out=>rnd_out);

    -- Reaction timer: measures time from start_t to stop_t using tick_1ms
    rt_i:     entity work.reaction_timer
                 port map(
                     clk        => CLOCK_50,
                     reset      => btn_rst,
                     start      => start_t,
                     stop       => stop_t,
                     tick_1ms   => tick_1ms,
                     elapsed_ms => elapsed_time,
                     busy       => busy_t,
                     done       => done_t
                 );

    -- FSM: controls game flow, issues start/stop pulses, captures times
    fsm_i:    entity work.fsm_control
                 port map(
                     clk          => CLOCK_50,
                     reset        => btn_rst,
                     ready        => btn_rdy,
                     react        => btn_react,
                     tick_1ms     => tick_1ms,
                     rnd          => rnd_out,
                     elapsed_in   => elapsed_time,
                     start_timer  => start_t,
                     stop_timer   => stop_t,
                     capture      => open,           -- unused buffer port
                     show_winner  => show_win_sig,
                     winner_idx   => win_idx_sig,
                     winner_time  => winner_time_sig,
                     zero_phase   => zero_phase_sig,
                     seq_idx      => seq_idx_sig,
                     player_leds  => player_leds_sig,
                     init_phase   => init_phase_sig,
                     flash_on     => flash_on_sig
                 );

    -- Convert elapsed time to BCD digits for live display
    disp_i:   entity work.display_controller
                 port map(ms_count=>elapsed_time, d3=>d3, d2=>d2, d1=>d1, d0=>d0, dp=>dp_time);

    -- Pack BCD digits into array
    bcd_digits(3) <= d3;
    bcd_digits(2) <= d2;
    bcd_digits(1) <= d1;
    bcd_digits(0) <= d0;

    -- Instantiate 7-seg decoder for each live-time digit
    gen_time: for i in 0 to 3 generate
        seg7_t: entity work.seg7_decoder port map(digit=>bcd_digits(i), seg=>seg_time(i));
    end generate gen_time;

    -- Precompute constant zero patterns for zero-sequence chase
    gen_zero: for j in 0 to 5 generate
        seg7_z: entity work.seg7_decoder port map(digit=>"0000", seg=>seg_zero(j));
    end generate gen_zero;

    -- Decode winner index (1–4) to segment pattern
    win_dec: entity work.seg7_decoder
        port map(
            digit=>std_logic_vector(to_unsigned(to_integer(win_idx_sig)+1,4)),
            seg  => seg_winner
        );

    -- Winner time display conversion
    disp_w: entity work.display_controller
        port map(ms_count=>winner_time_sig, d3=>w_d3, d2=>w_d2, d1=>w_d1, d0=>w_d0, dp=>w_dp);

    -- Decode each winner-time BCD digit
    gen_wt: for i in 0 to 3 generate
        signal digit_w : std_logic_vector(3 downto 0);
    begin
        -- select appropriate digit bus
        digit_w <= w_d3 when i = 3 else
                   w_d2 when i = 2 else
                   w_d1 when i = 1 else
                   w_d0;
        seg7_w: entity work.seg7_decoder port map(digit=>digit_w, seg=>seg_wt(i));
    end generate gen_wt;

    -- Drive player LEDs: one-hot indicating current or winning player
    LEDR <= player_leds_sig;

    -- Multiplex HEX5–HEX0 outputs based on game state
    process(
        init_phase_sig, flash_on_sig,
        show_win_sig,
        zero_phase_sig, seq_idx_sig,
        done_t,
        seg_zero, seg_time, dp_time,
        seg_winner, seg_wt, w_dp
    )
    begin
        if init_phase_sig = '1' then
            -- Initial splash: flash all "8" digits
            if flash_on_sig = '1' then
                HEX5<= "0000000"; HEX4<= "0000000"; HEX3<= "0000000";
                HEX2<= "0000000"; HEX1<= "0000000"; HEX0<= "0000000";
            else
                HEX5<= BLANK; HEX4<= BLANK; HEX3<= BLANK;
                HEX2<= BLANK; HEX1<= BLANK; HEX0<= BLANK;
            end if;
        elsif show_win_sig = '1' then
            -- Winner display: show player number and time
            HEX5    <= seg_winner;   -- player #
            HEX4    <= BLANK;        -- blank
            HEX3    <= seg_wt(3);    -- ms thousands
            HEX2    <= seg_wt(2);    -- ms hundreds
            HEX1    <= seg_wt(1);    -- ms tens
            HEX0    <= seg_wt(0);    -- ms ones
        elsif zero_phase_sig = '1' then
            -- Zero-sequence chase: light zeros progressively
            HEX5<= seg_zero(5) when to_integer(seq_idx_sig)>=1 else BLANK;
            HEX4<= seg_zero(4) when to_integer(seq_idx_sig)>=2 else BLANK;
            HEX3<= seg_zero(3) when to_integer(seq_idx_sig)>=3 else BLANK;
            HEX2<= seg_zero(2) when to_integer(seq_idx_sig)>=4 else BLANK;
            HEX1<= seg_zero(1) when to_integer(seq_idx_sig)>=5 else BLANK;
            HEX0<= seg_zero(0) when to_integer(seq_idx_sig)>=6 else BLANK;
        elsif done_t = '1' then
            -- Live reaction time: display on lower 4 digits
            HEX5<= BLANK; HEX4<= BLANK;
            HEX3<= seg_time(3); HEX2<= seg_time(2);
            HEX1<= seg_time(1); HEX0<= seg_time(0);
        else
            -- Default: blank all displays
            HEX5<= BLANK; HEX4<= BLANK; HEX3<= BLANK;
            HEX2<= BLANK; HEX1<= BLANK; HEX0<= BLANK;
        end if;
    end process;

end architecture rtl;  -- End of top_level
