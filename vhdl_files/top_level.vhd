library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_level is
    port(
        CLOCK_50    : in  std_logic;
        KEY         : in  std_logic_vector(2 downto 0);
        HEX5,HEX4,HEX3,HEX2,HEX1,HEX0    : out std_logic_vector(0 to 6);
        LEDR        : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of top_level is

    type seg7_arr6_t is array (0 to 5) of std_logic_vector(6 downto 0);
    type seg7_arr4_t is array (0 to 3) of std_logic_vector(6 downto 0);
    type bcd_arr4_t  is array (0 to 3) of std_logic_vector(3 downto 0);

    signal btn_rdy, btn_react, btn_rst : std_logic;
    signal tick_1ms                    : std_logic;
    signal rnd_out                     : std_logic_vector(15 downto 0);
    signal start_t, stop_t, busy_t, done_t : std_logic;
    signal elapsed_time                : unsigned(13 downto 0);

    signal zero_phase_sig              : std_logic;
    signal seq_idx_sig                 : unsigned(2 downto 0);
    signal show_win_sig                : std_logic;
    signal win_idx_sig                 : unsigned(1 downto 0);
    signal winner_time_sig             : unsigned(13 downto 0);
    signal player_leds_sig             : std_logic_vector(3 downto 0);
    signal init_phase_sig              : std_logic;
    signal flash_on_sig                : std_logic;

    signal d3,d2,d1,d0                  : std_logic_vector(3 downto 0);
    signal dp_time                     : std_logic_vector(3 downto 0);
    signal bcd_digits                  : bcd_arr4_t;
    signal seg_time                    : seg7_arr4_t;
    signal seg_zero                    : seg7_arr6_t;
    signal seg_winner                  : std_logic_vector(6 downto 0);

    signal w_d3,w_d2,w_d1,w_d0         : std_logic_vector(3 downto 0);
    signal w_dp                        : std_logic_vector(3 downto 0);
    signal seg_wt                      : seg7_arr4_t;

    constant BLANK : std_logic_vector(6 downto 0) := (others=>'1');

begin

    -- debounce
    db_rdy:   entity work.debounce port map(clk=>CLOCK_50, btn_in=>not KEY(0), btn_out=>btn_rdy);
    db_react: entity work.debounce port map(clk=>CLOCK_50, btn_in=>not KEY(1), btn_out=>btn_react);
    db_rst:   entity work.debounce port map(clk=>CLOCK_50, btn_in=>not KEY(2), btn_out=>btn_rst);

    -- 1 ms tick
    ms_i:     entity work.ms_timer port map(clk=>CLOCK_50, reset=>btn_rst, tick_1ms=>tick_1ms);

    -- LFSR
    lfsr_i:   entity work.lfsr   port map(clk=>CLOCK_50, reset=>btn_rst, enable=>'1', rnd_out=>rnd_out);

    -- reaction timer
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

    -- FSM
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
                     capture      => open,
                     show_winner  => show_win_sig,
                     winner_idx   => win_idx_sig,
                     winner_time  => winner_time_sig,
                     zero_phase   => zero_phase_sig,
                     seq_idx      => seq_idx_sig,
                     player_leds  => player_leds_sig,
                     init_phase   => init_phase_sig,
                     flash_on     => flash_on_sig
                 );

    -- live-time display
    disp_i:   entity work.display_controller
                 port map(ms_count=>elapsed_time, d3=>d3, d2=>d2, d1=>d1, d0=>d0, dp=>dp_time);

    bcd_digits(3) <= d3;
    bcd_digits(2) <= d2;
    bcd_digits(1) <= d1;
    bcd_digits(0) <= d0;

    gen_time: for i in 0 to 3 generate
        seg7_t: entity work.seg7_decoder port map(digit=>bcd_digits(i), seg=>seg_time(i));
    end generate;

    -- zero sequence
    gen_zero: for j in 0 to 5 generate
        seg7_z: entity work.seg7_decoder port map(digit=>"0000", seg=>seg_zero(j));
    end generate;

    -- winner index decoder
    win_dec: entity work.seg7_decoder
        port map(digit=>std_logic_vector(to_unsigned(to_integer(win_idx_sig)+1,4)),
                 seg  => seg_winner);

    -- winner-time display
    disp_w: entity work.display_controller
        port map(ms_count=>winner_time_sig, d3=>w_d3, d2=>w_d2, d1=>w_d1, d0=>w_d0, dp=>w_dp);

    gen_wt: for i in 0 to 3 generate
        signal digit_w : std_logic_vector(3 downto 0);
    begin
        digit_w <= w_d3 when i = 3 else
                   w_d2 when i = 2 else
                   w_d1 when i = 1 else
                   w_d0;
        seg7_w: entity work.seg7_decoder port map(digit=>digit_w, seg=>seg_wt(i));
    end generate;

    -- player LEDs
    LEDR <= player_leds_sig;

    -- multiplex HEX5–HEX0
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
            -- splash: flash “8” on all
            if flash_on_sig = '1' then
                HEX5<= "0000000"; HEX4<= "0000000"; HEX3<= "0000000";
                HEX2<= "0000000"; HEX1<= "0000000"; HEX0<= "0000000";
            else
                HEX5<= BLANK; HEX4<= BLANK; HEX3<= BLANK;
                HEX2<= BLANK; HEX1<= BLANK; HEX0<= BLANK;
            end if;

        elsif show_win_sig = '1' then
            -- WIN_SHOW: HEX5=winner#, HEX4–HEX1=winner_time, HEX0 blank
            HEX5    <= seg_winner;
            HEX4    <= BLANK;		
            HEX3    <= seg_wt(3);   
            HEX2    <= seg_wt(2);   
            HEX1    <= seg_wt(1);   
            HEX0    <= seg_wt(0);   

        elsif zero_phase_sig = '1' then
            -- sequential zeros
            if to_integer(seq_idx_sig)>=1 then HEX5<=seg_zero(5); else HEX5<=BLANK; end if;
            if to_integer(seq_idx_sig)>=2 then HEX4<=seg_zero(4); else HEX4<=BLANK; end if;
            if to_integer(seq_idx_sig)>=3 then HEX3<=seg_zero(3); else HEX3<=BLANK; end if;
            if to_integer(seq_idx_sig)>=4 then HEX2<=seg_zero(2); else HEX2<=BLANK; end if;
            if to_integer(seq_idx_sig)>=5 then HEX1<=seg_zero(1); else HEX1<=BLANK; end if;
            if to_integer(seq_idx_sig)>=6 then HEX0<=seg_zero(0); else HEX0<=BLANK; end if;
            
        elsif done_t = '1' then
            -- live reaction time on HEX3–HEX0
            HEX5<=BLANK; HEX4<=BLANK;
            HEX3<=seg_time(3); 
            HEX2<=seg_time(2); 
            HEX1<=seg_time(1); 
            HEX0<=seg_time(0); 

        else
            -- blank all
            HEX5<=BLANK; HEX4<=BLANK; HEX3<=BLANK;
            HEX2<=BLANK; HEX1<=BLANK; HEX0<=BLANK;
        end if;
    end process;

end architecture rtl;
