----------------------------------------------------------------------------------
-- Company:LAAS-CNRS 
-- Author:Jonathan Piat <piat.jonathan@gmail.com> 
-- 
-- Create Date:    10:54:36 06/19/2012 
-- Design Name: 
-- Module Name:    fifo_peripheral - Behavioral 
-- Project Name: 
-- Target Devices: Spartan 6 
-- Tool versions: ISE 14.1 
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

library work ;
use work.utils_pack.all ;


--! peripheral with fifo interface to the logic
--! fifo B can be written from logic and read from bus
--! fifo A can be written from bus and read from logic
entity wishbone_fifo is
generic( ADDR_WIDTH: positive := 16; --! width of the address bus
			WIDTH	: positive := 16; --! width of the data bus
			SIZE	: positive	:= 128; --! fifo depth
			BURST_SIZE : positive := 4;
			SYNC_LOGIC_INTERFACE : boolean := false 
			); 
port(
	-- Syscon signals
	gls_reset    : in std_logic ;
	gls_clk      : in std_logic ;
	-- Wishbone signals
	wbs_add       : in std_logic_vector(ADDR_WIDTH-1 downto 0) ;
	wbs_writedata : in std_logic_vector( WIDTH-1 downto 0);
	wbs_readdata  : out std_logic_vector( WIDTH-1 downto 0);
	wbs_strobe    : in std_logic ;
	wbs_cycle      : in std_logic ;
	wbs_write     : in std_logic ;
	wbs_ack       : out std_logic;
		  
	-- logic signals  
	wrB, rdA : in std_logic ; --! logic side fifo control signal
	inputB: in std_logic_vector((WIDTH - 1) downto 0); --! data input of fifo B
	outputA	: out std_logic_vector((WIDTH - 1) downto 0); --! data output of fifo A
	emptyA, fullA, emptyB, fullB, burst_available_B	:	out std_logic --! fifo state signals
);
end wishbone_fifo;



architecture RTL of wishbone_fifo is

constant address_space_nbit : integer := MAX((nbit(BURST_SIZE)+1), 3);
signal fifoA_wr, fifoB_rd, srazA, srazB : std_logic ;
signal fifoA_in,  fifoB_out : std_logic_vector((WIDTH - 1) downto 0 ); 
signal nb_availableA, nb_availableB  :  unsigned((WIDTH - 1) downto 0 ); 
signal nb_availableA_latched, nb_availableB_latched : std_logic_vector((WIDTH - 1) downto 0  );
signal data_bus_out_t	: std_logic_vector((WIDTH - 1) downto 0); 


signal write_ack, read_ack : std_logic ;
begin

write_bloc : process(gls_clk,gls_reset)
begin
    if gls_reset = '1' then 
        write_ack <= '0';
    elsif rising_edge(gls_clk) then
        if ((wbs_strobe and wbs_write and wbs_cycle) = '1' ) then
            write_ack <= '1';
        else
            write_ack <= '0';
        end if;
    end if;
end process write_bloc;

read_bloc : process(gls_clk, gls_reset)
begin
    if gls_reset = '1' then
        
    elsif rising_edge(gls_clk) then
        if (wbs_strobe = '1' and wbs_write = '0'  and wbs_cycle = '1' ) then
            read_ack <= '1';
        else
            read_ack <= '0';
        end if;
    end if;
end process read_bloc;

wbs_ack <= read_ack or write_ack;


fifo_A : dp_fifo -- write from bus, read from logic
	generic map(N => SIZE , W => WIDTH, SYNC_RD => SYNC_LOGIC_INTERFACE, SYNC_WR => false)
	port map(
 		clk => gls_clk, resetn => (NOT gls_reset) , sraz => srazA , 
 		wr => fifoA_wr, rd => rdA,
		empty => emptyA,
		full => fullA ,
 		data_out => outputA , 
 		data_in => fifoA_in ,
		nb_available => nb_availableA(nbit(SIZE)   downto 0)
	); 
	
fifo_B : dp_fifo -- read from bus, write from logic
	generic map(N => SIZE , W => WIDTH, SYNC_WR => SYNC_LOGIC_INTERFACE, SYNC_RD => false)
	port map(
 		clk => gls_clk, resetn => (NOT gls_reset) , sraz => srazB , 
 		wr => wrB, rd => fifoB_rd,
		empty => emptyB,
		full => fullB ,
 		data_out => fifoB_out , 
 		data_in => inputB ,
		nb_available => nb_availableB(nbit(SIZE)  downto 0)
	); 


nb_availableB_latched  <= std_logic_vector(nb_availableB) ;	  
nb_availableA_latched <= std_logic_vector(nb_availableA) ;

nb_availableB((WIDTH - 1) downto (nbit(SIZE) + 1)) <= (others => '0') ;
nb_availableA((WIDTH - 1) downto (nbit(SIZE) + 1)) <= (others => '0') ;


data_bus_out_t <= fifoB_out when wbs_add(address_space_nbit-1) = '0'  else --fifo has (address_space_nbit-1) bits address space
				std_logic_vector(to_unsigned(SIZE, 16)) when wbs_add((address_space_nbit-1)) = '1' and wbs_add(1 downto 0)= "00" else
				( nb_availableA_latched) when wbs_add((address_space_nbit-1)) = '1' and wbs_add(1 downto 0)= "01" else
				( nb_availableB_latched) when wbs_add((address_space_nbit-1)) = '1' and wbs_add(1 downto 0)= "10"  else
				fifoB_out when wbs_add((address_space_nbit-1)) = '1' and wbs_add(1 downto 0)= "11" else -- peek !
				(others => '0');

wbs_readdata <= data_bus_out_t when wbs_strobe = '1' and wbs_write = '0'  and wbs_cycle = '1' else
					(others => 'Z');


fifoB_rd <= '1' when wbs_add((address_space_nbit-1)) = '0' and wbs_strobe = '1' and wbs_write = '0'  and wbs_cycle = '1' else
				'0' ;
				
fifoA_wr <= '1' when wbs_add((address_space_nbit-1)) = '0' and (wbs_strobe and wbs_write and wbs_cycle)= '1' else
				'0' ;
	
srazA <= '1' when wbs_strobe = '1' and wbs_write = '1' and wbs_cycle = '1' and wbs_add(address_space_nbit-1) = '1' and wbs_add(1 downto 0) = "01" else
			'0' ;

srazB <= '1' when wbs_strobe = '1' and wbs_write = '1' and wbs_cycle = '1' and wbs_add(address_space_nbit-1) = '1' and wbs_add(1 downto 0) = "10" else
			'0' ;
				
fifoA_in <= wbs_writedata ;

burst_available_B <= '1' when nb_availableB_latched > BURST_SIZE else
							'0' ;

end RTL;

