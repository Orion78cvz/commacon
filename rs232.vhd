----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    01:58:53 03/25/2010 
-- Design Name: 
-- Module Name:    rs232 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity rs232 is
    Port (
			  CLKTx		: in	STD_LOGIC;
           TxDATA 	: in	STD_LOGIC_VECTOR (7 downto 0);
           TDR 		: in	STD_LOGIC;
           TxD 		: out	STD_LOGIC;
           TxREADY	: out	STD_LOGIC;
			  CLKRx 		: in	STD_LOGIC;
           RxD 		: in	STD_LOGIC;
           RxDATA 	: out	STD_LOGIC_VECTOR (7 downto 0);
           RxREADY 	: out	STD_LOGIC
	);
end rs232;

architecture Behavioral of rs232 is
	signal sendbuf : std_logic_vector(7 downto 0);
	signal ssreg : std_logic_vector(8 downto 0) := "000000000";
	signal recvbuf : std_logic_vector(7 downto 0);
	signal rsreg : std_logic_vector(8 downto 0) := "000000000";
begin
	to_serial: process (CLKTx)
	begin
		if (CLKTx'event and CLKTx = '1') then
			if (ssreg =	"000000000") then
				if (TDR = '0') then	-- idle state
					TxD <= '1';
					TxREADY <= '1';
				else						-- start!
					sendbuf <= TxDATA;
					ssreg <= "000000001";
					TxD <= '0'; -- start bit
					TxREADY <= '0';
				end if;
			else
				if    (ssreg(8) = '1') then -- stop bit
					TxD <= '1';
				elsif (ssreg(7) = '1') then -- sending data bits
					TxD <= sendbuf(7);
				elsif (ssreg(6) = '1') then
					TxD <= sendbuf(6);
				elsif (ssreg(5) = '1') then
					TxD <= sendbuf(5);
				elsif (ssreg(4) = '1') then
					TxD <= sendbuf(4);
				elsif (ssreg(3) = '1') then
					TxD <= sendbuf(3);
				elsif (ssreg(2) = '1') then
					TxD <= sendbuf(2);
				elsif (ssreg(1) = '1') then
					TxD <= sendbuf(1);
				elsif (ssreg(0) = '1') then
					TxD <= sendbuf(0);
				end if;
				
				ssreg <= ssreg(7 downto 0) & '0';
				TxREADY <= '0';
			end if;
		end if;
	end process;

	to_parallel: process (CLKRx)
	begin
		if (CLKRx'event and CLKRx = '1') then
			if (rsreg =	"000000000") then	-- idle state
				if (RxD = '0') then  -- start!
					rsreg <= "000000001";
					RxREADY <= '0';
				else						-- waiting
					null;
				end if;
			else
				if    (rsreg(8) = '1') then
					if (RxD = '1') then  -- stop bit
						RxDATA <= recvbuf;
						RxREADY <= '1';
					end if;
				elsif (rsreg(7) = '1') then -- receiving data bits
					recvbuf(7) <= RxD;
				elsif (rsreg(6) = '1') then
					recvbuf(6) <= RxD;
				elsif (rsreg(5) = '1') then
					recvbuf(5) <= RxD;
				elsif (rsreg(4) = '1') then
					recvbuf(4) <= RxD;
				elsif (rsreg(3) = '1') then
					recvbuf(3) <= RxD;
				elsif (rsreg(2) = '1') then
					recvbuf(2) <= RxD;
				elsif (rsreg(1) = '1') then
					recvbuf(1) <= RxD;
				elsif (rsreg(0) = '1') then
					recvbuf(0) <= RxD;
				end if;
				
				rsreg <= rsreg(7 downto 0) & '0';
			end if;
		end if;
	end process;


end Behavioral;

