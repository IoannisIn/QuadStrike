library ieee;
use ieee.std_logic_1164.all;    -- Standard logic definitions (std_logic, std_logic_vector, etc.)

-- Entity: 7-Segment Decoder
-- Converts a 4-bit binary digit (0–9) into the corresponding 7-segment display pattern
entity seg7_decoder is
    port (
        digit : in  std_logic_vector(3 downto 0); -- 4-bit input representing decimal digit 0–9
        seg   : out std_logic_vector(6 downto 0)  -- 7 segment outputs: a b c d e f g
    );
end entity seg7_decoder;

architecture rtl of seg7_decoder is
begin
    -- Combinational process: update segments whenever the input digit changes
    process(digit)
    begin
        case digit is
            -- Each 7-bit vector corresponds to segments (a–g) active low (0 = on, 1 = off)
            when "0000" => seg <= "0000001"; -- "0": segments a,b,c,d,e,f on; g off
            when "0001" => seg <= "1001111"; -- "1": segments b,c on; others off
            when "0010" => seg <= "0010010"; -- "2": segments a,b,d,e,g on
            when "0011" => seg <= "0000110"; -- "3": segments a,b,c,d,g on
            when "0100" => seg <= "1001100"; -- "4": segments b,c,f,g on
            when "0101" => seg <= "0100100"; -- "5": segments a,c,d,f,g on
            when "0110" => seg <= "0100000"; -- "6": segments a,c,d,e,f,g on
            when "0111" => seg <= "0001111"; -- "7": segments a,b,c on
            when "1000" => seg <= "0000000"; -- "8": all segments (a–g) on
            when "1001" => seg <= "0000100"; -- "9": segments a,b,c,d,f,g on
            when others =>
                -- For invalid inputs (10–15), turn all segments off (blank)
                seg <= "1111111";
        end case;
    end process;

end architecture rtl;  -- End of seg7_decoder
