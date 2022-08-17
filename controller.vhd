library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity CONTROLLER is
    Port ( CLK_50M : in STD_LOGIC;
		  -- output to PS Controller
			  FX2_IOA : out STD_LOGIC_VECTOR (16 downto 1);
			  FX2_IOB : out STD_LOGIC_VECTOR (16 downto 1);
		  -- RS-232C port (DCE)
			  RS232_DCE_TXD	: out STD_LOGIC;
			  RS232_DCE_RXD	: in  STD_LOGIC;
			-- other on-board facilities
			  SW  		: in  STD_LOGIC_VECTOR (3 downto 0);
           BTN_EAST  : in  STD_LOGIC;
           --BTN_NORTH : in  STD_LOGIC;
           BTN_SOUTH : in  STD_LOGIC;
           --BTN_WEST  : in  STD_LOGIC;
			  --ROT_A : in STD_LOGIC;
			  --ROT_B : in STD_LOGIC;
			  --ROT_CENTER : in STD_LOGIC;
           LED 		: out  STD_LOGIC_VECTOR (7 downto 0)
		);
end CONTROLLER;

architecture Behavioral of CONTROLLER is
	signal CLK: std_logic := '0'; -- 60(59.94006)Hz
	signal CLK_1Hz: std_logic := '0';

	-- DCM
	COMPONENT clockx3
    port ( CLKIN_IN  : in  std_logic; 
          CLKFX_OUT  : out std_logic);
	END COMPONENT;
	signal CLK_30M: std_logic; --50*3/5 MHz
	
	--RS-232C send/recv
	COMPONENT rs232 is
    Port ( CLKTx		: in  STD_LOGIC;
           TxDATA		: in  STD_LOGIC_VECTOR (7 downto 0);
           TDR			: in  STD_LOGIC;
           TxD			: out STD_LOGIC;
           TxREADY	: out STD_LOGIC;
			  CLKRx		: in  STD_LOGIC;
           RxD			: in  STD_LOGIC;
           RxDATA		: out STD_LOGIC_VECTOR (7 downto 0);
           RxREADY	: out STD_LOGIC);
	end COMPONENT;
	signal CLK_9600Tx : std_logic := '0';
	signal RS232_TxDATA  : std_logic_vector (7 downto 0);
	signal RS232_TDR  : std_logic := '0';
	signal RS232_TxD_BUF : std_logic := '1';
	signal RS232_TxREADY : std_logic := '0';
	signal CLK_9600Rx : std_logic := '0';
	signal RS232_RxDATA : std_logic_vector (7 downto 0);
	signal RS232_RxD_BUF : std_logic := '1';
	signal RS232_RxREADY : std_logic := '0';
	signal BTN_EVENT : std_logic := '0';
	signal RS232_Char : std_logic_vector(7 downto 0) := "00000000";
	signal Command_Char : std_logic_vector(7 downto 0) := "00000000";
	
	-- blockRAM
	component blockram
		port (
			clka: 	IN std_logic;
			wea: 		IN std_logic_VECTOR(0 downto 0);
			addra: 	IN std_logic_VECTOR(12 downto 0);
			dina:		IN std_logic_VECTOR(7 downto 0);
			clkb:		IN std_logic;
			addrb:	IN std_logic_VECTOR(12 downto 0);
			doutb:	OUT std_logic_VECTOR(7 downto 0));
	end component;
	attribute syn_black_box : boolean;
	attribute syn_black_box of blockram: component is true;
	signal MEM_WAddr: std_logic_vector(14 downto 0) := "111111111111111";
	signal MEM_WData: std_logic_vector(7 downto 0) := "00000000";
	signal MEM_WEna: std_logic_vector(3 downto 0) := "0000";
	signal MEM_RAddr: std_logic_vector(12 downto 0) := "1111111111111";
	signal MEM_RData: std_logic_vector(31 downto 0);
	--
	signal Current_Input: std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

------------------------------------
-- simple command string decoder
-- 
--12345 6 7 8 9 10111213141516
--←↓↑→    L1L2R1R2□ × △ ○ SEST
function com_decode (char: std_logic_vector(7 downto 0)) return std_logic_vector is
begin
	case char is
		when "01011111" => return "00000000"; -- '_' -> 無入力
		when "00110001" => return "00000011"; -- 			方向'1'
		when "00110010" => return "00000010"; -- 			方向'2'
		when "00110011" => return "00001010"; -- 			方向'3'
		when "00110100" => return "00000001"; -- 			方向'4'
		when "00110101" => return "00000000"; -- 			方向'5'
		when "00110110" => return "00001000"; -- 			方向'6'
		when "00110111" => return "00000101"; -- 			方向'7'
		when "00111000" => return "00000100"; -- 			方向'8'
		when "00111001" => return "00001100"; -- 			方向'9'
		when "01000001" => return "00000100"; -- 'A' -> A
		when "01000010" => return "00001000"; -- 'B' -> B
		when "01000011" => return "00010000"; -- 'C' -> C
		when "01000100" => return "00100000"; -- 'D' -> D
		when "01000101" => return "00000001"; -- 'E' -> E
		when "01000110" => return "00000010"; -- 'F' -> 挑発(R2)
		when "01001000" => return "00001100"; -- 'H' -> A+B
		when "01010110" => return "00110000"; -- 'V' -> C+D
		when "01000111" => return "00010100"; -- 'G' -> A+C
		when "01010100" => return "00101000"; -- 'T' -> B+D
		when "01100001" => return "00000101"; -- 'a' -> A+E
		when "01100010" => return "00001001"; -- 'b' -> B+E
		when "01100011" => return "00010001"; -- 'c' -> C+E
		when "01100100" => return "00100001"; -- 'd' -> D+E
		when "01100101" => return "00000001"; -- 'e' -> E
		when "01100110" => return "00000011"; -- 'f' -> 挑発(R2)+E
		when "01101000" => return "00001101"; -- 'h' -> A+B+E
		when "01110110" => return "00110001"; -- 'v' -> C+D+E
		when "01100111" => return "00010101"; -- 'g' -> A+C+E
		when "01110100" => return "00101001"; -- 't' -> B+D+E
		when "01001100" => return "01000000"; -- 'L' ->	SE
		when "01010011" => return "10000000"; -- 'S' ->	ST
		when others => return "00000000";
	end case;
end com_decode;

function is_control_char (char: std_logic_vector(7 downto 0)) return std_logic is
begin -- コントロール文字列挙
	case char is
		when "00111011" => return '1';	-- ';'
		when "00011011" => return '1';	-- ESC
		when others => return '0';
	end case;
end is_control_char;


begin

clk30m_inst: clockx3 port map (
	CLKIN_IN => CLK_50M,
	CLKFX_OUT => CLK_30M
);

rs232_inst: rs232 port map (
	CLKTx => CLK_9600Tx,
	TxDATA => RS232_TxDATA,
	TDR => RS232_TDR,
	TxD => RS232_TxD_BUF,
	TxREADY => RS232_TxREADY,
	CLKRx => CLK_9600Rx,
	RxDATA => RS232_RxDATA,
	RxD => RS232_RxD_BUF,
	RxREADY => RS232_RxREADY
);

-- memory (4 way)
memory00 : blockram
	port map (
		clka => CLK_30M,
		clkb => CLK_30M,
		dina => MEM_WData,
		wea => MEM_WEna(0 downto 0),
		addra => MEM_WAddr(14 downto 2),
		addrb => MEM_RAddr(12 downto 0),
		doutb => MEM_RData(7 downto 0)
);
memory01 : blockram
	port map (
		clka => CLK_30M,
		clkb => CLK_30M,
		dina => MEM_WData,
		wea => MEM_WEna(1 downto 1),
		addra => MEM_WAddr(14 downto 2),
		addrb => MEM_RAddr(12 downto 0),
		doutb => MEM_RData(15 downto 8)
);
memory10 : blockram
	port map (
		clka => CLK_30M,
		clkb => CLK_30M,
		dina => MEM_WData,
		wea => MEM_WEna(2 downto 2),
		addra => MEM_WAddr(14 downto 2),
		addrb => MEM_RAddr(12 downto 0),
		doutb => MEM_RData(23 downto 16)
);
memory11 : blockram
	port map (
		clka => CLK_30M,
		clkb => CLK_30M,
		dina => MEM_WData,
		wea => MEM_WEna(3 downto 3),
		addra => MEM_WAddr(14 downto 2),
		addrb => MEM_RAddr(12 downto 0),
		doutb => MEM_RData(31 downto 24)
);

------------------------------------
-- clock test
--
gen_clock: process (CLK_50M)
	variable counter1 : integer := 0;
begin
	if (CLK_50M'event and CLK_50M = '1') then
		counter1 := counter1 + 1;
		if (counter1 >= 25000000) then
			CLK_1Hz <= not CLK_1Hz;
			counter1 := 0;
		end if;
	end if;
	
end process;

gen_clock2: process (CLK_30M)
	variable counter60: integer := 0;
begin
	if (CLK_30M'event and CLK_30M = '1') then
		counter60 := counter60 + 1;
		if (counter60 >= 250250) then -- 厳密には60ではなく59.94006Hz
			CLK <= not CLK;
			counter60 := 0;
		end if;
	end if;
	
end process;


------------------------------------
-- RS-232C process
--
rs232_rtl: process (CLK_30M)
begin
	if (CLK_30M'event and CLK_30M = '1') then
		if (SW(3) = '0') then -- disabled
			RS232_DCE_TXD <= '1';
		else
			RS232_DCE_TXD <= RS232_DCE_RXD; -- echo
			RS232_RxD_BUF <= RS232_DCE_RXD;
		end if;
	end if;
end process;


recv232c: process (CLK_30M, RS232_RxREADY)
	variable clkcntRx: integer := 0;
	variable START_EVENT: std_logic := '0';
	variable old_RxReady: std_logic := '0';
begin
	if (CLK_30M'event and CLK_30M = '1') then
		clkcntRx := clkcntRx + 1;
		if (clkcntRx >= 3125) then
			clkcntRx := 0;
		end if;

		if (START_EVENT = '0' and RS232_RxD_BUF = '0') then -- start bit
			START_EVENT := '1';
			clkcntRx := 781;
		end if;
		
		if (old_RxReady = '0' and RS232_RxREADY = '1') then
			if (is_control_char(RS232_RxDATA(7 downto 0)) = '1') then
				RS232_Char <= RS232_RxDATA(7 downto 0);
			else
				RS232_Char <= RS232_RxDATA(7 downto 0);
				-- copy to memory
				case MEM_WAddr(1 downto 0) is -- 実際には書き込むアドレス-1
					when "11" => MEM_WEna <= "0001";
					when "00" => MEM_WEna <= "0010";
					when "01" => MEM_WEna <= "0100";
					when "10" => MEM_WEna <= "1000";
					when others => null;
				end case;
				MEM_WAddr <= MEM_WAddr + 1;
				MEM_WData <= RS232_RxDATA(7 downto 0);
				START_EVENT := '0';

				if (SW(2) = '1') then -- direct
					case MEM_WAddr(1 downto 0) is
						when "11" => Current_Input( 7 downto  0) <= RS232_RxDATA(7 downto 0);
						when "00" => Current_Input(15 downto  8) <= RS232_RxDATA(7 downto 0);
						when "01" => Current_Input(23 downto 16) <= RS232_RxDATA(7 downto 0);
						when "10" => Current_Input(31 downto 24) <= RS232_RxDATA(7 downto 0);
						when others => null;
					end case;
				end if;
			end if;
		else
			MEM_WEna <= "0000";
			if (Command_Char /= "00000000") then
				RS232_Char <= "00000000";
			end if;
		end if;

		old_RxReady := RS232_RxREADY;
		
		if (clkcntRx > 1562) then CLK_9600Rx <= '1'; else CLK_9600Rx <= '0'; end if;		
	end if;

	
end process;

------------------------------------
-- main process
--
run_command_seq: process (CLK, CLK_30M)
	variable RUNNING_EVENT: std_logic := '0';
	variable endaddr: std_logic_vector(12 downto 0) := "1111111111111";
	variable startaddr: std_logic_vector(12 downto 0) := "1111111111111";
begin	
	if (CLK'event and CLK = '1') then
		-- 4-byte alignment
		if (MEM_WAddr(1 downto 0) /= "11") then
			endaddr := MEM_WAddr(14 downto 2) - 1;
		else
			endaddr := MEM_WAddr(14 downto 2);
		end if;

		if (SW(2) = '1') then
			FX2_IOA( 8 downto 1) <= not com_decode(char => Current_Input( 7 downto 0));
			FX2_IOA(16 downto 9) <= not com_decode(char => Current_Input(15 downto 8));
			FX2_IOB( 8 downto 1) <= not com_decode(char => Current_Input(23 downto 16));
			FX2_IOB(16 downto 9) <= not com_decode(char => Current_Input(31 downto 24));
		else
			if (BTN_SOUTH = '1' or Command_Char = "00011011") then -- terminate
				MEM_RAddr <= endaddr;
			else
				if (RUNNING_EVENT = '0') then
					FX2_IOA(16 downto 1) <= "1111111111111111";
					FX2_IOB(16 downto 1) <= "1111111111111111";
					
					-- start!
					if ((BTN_EAST = '1' or Command_Char = "00111011") and MEM_RAddr /= endaddr) then
						RUNNING_EVENT := '1';
						startaddr := MEM_RAddr;
						MEM_RAddr <= MEM_RAddr + 1;
					end if;
				else
					FX2_IOA( 8 downto 1) <= not com_decode(char => MEM_RData( 7 downto 0));
					FX2_IOA(16 downto 9) <= not com_decode(char => MEM_RData(15 downto 8));
					FX2_IOB( 8 downto 1) <= not com_decode(char => MEM_RData(23 downto 16));
					FX2_IOB(16 downto 9) <= not com_decode(char => MEM_RData(31 downto 24));
					
					if (MEM_RAddr = endaddr) then
						RUNNING_EVENT := '0';
						if (SW(0) = '1') then -- loop mode
							MEM_RAddr <= startaddr;
						end if;
					else
						MEM_RAddr <= MEM_RAddr + 1; -- 二箇所でincrするのがなんだかなぁ
					end if;
				end if;
			end if;
		end if;

		if (Command_Char = "00000000") then
			if (RS232_Char /= "00000000") then
				Command_Char <= RS232_Char;
			end if;
		else
			Command_Char <= "00000000";
		end if;

	end if;

end process;

led_status: process (CLK_50M)
begin
	if (CLK_50M'event and CLK_50M = '1') then
		if (SW(3) = '0') then -- RS-232C disabled
			LED(7 downto 0) <= "00000000";
		else
			if (SW(1) = '1') then --適当に消費してるだけ
				LED(7 downto 0) <= MEM_RAddr(3 downto 0) & MEM_WAddr(3 downto 0);
			else
				if (SW(2) = '1') then
					LED(7 downto 0) <= "00111111";
				else
					LED(7 downto 0) <= "00001111";
				end if;
			end if;
		end if;
	end if;
end process;


end Behavioral;
