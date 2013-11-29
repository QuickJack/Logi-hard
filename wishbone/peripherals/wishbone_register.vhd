----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:29:34 07/31/2013 
-- Design Name: 
-- Module Name:    wishbone_register - Behavioral 
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library work ;
use work.logi_wishbone_peripherals_pack.all ;

entity wishbone_register is
	generic(
		  wb_size : natural := 16; -- Data port size for wishbone
		  nb_regs : natural := 1
	 );
	 port 
	 (
		  -- Syscon signals
		  gls_reset    : in std_logic ;
		  gls_clk      : in std_logic ;
		  -- Wishbone signals
		  wbs_add       : in std_logic_vector(15 downto 0) ;
		  wbs_writedata : in std_logic_vector( wb_size-1 downto 0);
		  wbs_readdata  : out std_logic_vector( wb_size-1 downto 0);
		  wbs_strobe    : in std_logic ;
		  wbs_cycle      : in std_logic ;
		  wbs_write     : in std_logic ;
		  wbs_ack       : out std_logic;
		  -- out signals
		  reg_out : out slv16_array(0 to nb_regs-1);
		  reg_in : in slv16_array(0 to nb_regs-1)
	 );
end wishbone_register;

architecture Behavioral of wishbone_register is
	signal reg_in_d, reg_out_d : slv16_array(0 to nb_regs-1) ;
	signal read_ack : std_logic ;
	signal write_ack : std_logic ;
begin
wbs_ack <= read_ack or write_ack;

write_bloc : process(gls_clk,gls_reset)
begin
    if gls_reset = '1' then 
        reg_out_d <= (others =>(others => '0'));
        write_ack <= '0';
    elsif rising_edge(gls_clk) then
        if ((wbs_strobe and wbs_write and wbs_cycle) = '1' ) then
            reg_out_d(conv_integer(wbs_add)) <= wbs_writedata;
            write_ack <= '1';
        else
            write_ack <= '0';
        end if;
    end if;
end process write_bloc;
reg_out <= reg_out_d ;


read_bloc : process(gls_clk, gls_reset)
begin
    if gls_reset = '1' then
        
    elsif rising_edge(gls_clk) then
		  reg_in_d <= reg_in ; -- latching inputs
        if (wbs_strobe = '1' and wbs_write = '0'  and wbs_cycle = '1' ) then
            read_ack <= '1';
				wbs_readdata <= reg_in_d(conv_integer(wbs_add)) ;
        else
            read_ack <= '0';
        end if;
		  
    end if;
end process read_bloc;

end Behavioral;

