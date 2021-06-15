-- read and wreite merged
-- addr/data increment


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.numeric_std.all;

entity DPS_1_tb is
--    port (
--        clk : in STD_LOGIC; 
--        rst  : in STD_LOGIC;
--    );
end DPS_1_tb;

architecture Behavioral of DPS_1_tb is
	component DPS_1
		generic (N:integer 
		--max_s_clk_cnt : integer := 50
		);
		port (
		   clk : in STD_LOGIC; 
           rst  : in STD_LOGIC;
           
--           i_clk_cnt : in std_logic_vector(5 downto 0);
           i_cmd : in std_logic;
           i_WR : in std_logic;
           i_mem_read : in std_logic;
           
           
           i_tx_addr: in std_logic_vector(N-1 downto 0);
           i_tx_data: in std_logic_vector(N-1 downto 0);
           i_rx_data: out std_logic_vector(N-1 downto 0);
           
           o_STB : out STD_LOGIC;
           o_SDIO : inout STD_LOGIC;
           o_trx_done : out std_logic
 	
    );
	end component;
	
	signal o_STB : STD_LOGIC:='0';
	signal o_SDIO : STD_LOGIC:='0';
	
    signal i_cmd_sig: std_logic := '0';
    signal i_WR_sig: std_logic := '1'; -- 0: read, 1: write
    
    signal o_STB_sig: std_logic := '0';
    signal o_SDIO_sig: std_logic := '1';
    
    signal i_tx_addr_sig: std_logic_vector(15 downto 0):= x"F731";
    signal i_tx_data_sig: std_logic_vector(15 downto 0):= x"E620";
    signal i_rx_data_sig: std_logic_vector(15 downto 0):= (others => '0');
    
    
    signal max_clk_cnt1: integer:=42;
	signal s_clk_cnt: integer range 0 to 42;
	signal s_clk_cnt_vec: std_logic_vector(5 downto 0):= (others => '0');
	
	signal clk_sig: std_logic  :='0';
	signal rst_sig: std_logic  :='1';
	
	signal sig_o_trx_done: std_logic  :='0';
	
	signal max_clk_cnt_sig: integer:=39;
	signal mem_read_sig : STD_LOGIC:='0'; --0: register, 1: memory
	
begin
    s_clk_cnt_vec <= std_logic_vector(to_unsigned(s_clk_cnt,6));
    
    
    process
		begin
		clk_sig <= '1';			-- clock cycle 10 ns
		wait for 10 ns;
		clk_sig <= '0';
		wait for 10 ns;
    end process;   
    
    process(clk_sig,rst_sig)
	begin
	   if(rst_sig = '0') then
	       s_clk_cnt <= 0;
	       
	   elsif(rising_edge(clk_sig)) then
	        if (s_clk_cnt=0) or (s_clk_cnt mod max_clk_cnt_sig=0) then 
                i_cmd_sig <='1';
                s_clk_cnt <=0;
            end if;

	        if i_cmd_sig='1' then
                  s_clk_cnt <=s_clk_cnt +1;
            end if;
            
            if (sig_o_trx_done='1') then
	            i_WR_sig <=not i_WR_sig;
	            s_clk_cnt <= 0;
            end if;
            
	   end if;
    end process;
    
    p_inc_data: process(i_WR_sig)
 	begin
        --i_tx_addr_sig <= std_logic_vector(unsigned( i_tx_addr_sig) + 1);
        -- i_tx_data_sig <= std_logic_vector(unsigned( i_tx_data_sig) + 1);
             
        if(i_WR_sig='1') then
            max_clk_cnt_sig<=36;--when write
        else
            mem_read_sig <= not mem_read_sig;
            
            if(mem_read_sig ='0') then
                max_clk_cnt_sig<=39;--when register read
            else
                max_clk_cnt_sig<=41;--when mem read
            end if;
        end if;
      
 	end process;
    
    DPS_Slave1: DPS_1
    generic map(N=>16
    )
    
    port map(
        clk => clk_sig,
        rst => rst_sig,
        
--        i_clk_cnt => s_clk_cnt_vec,
        i_cmd => i_cmd_sig,
        i_WR => i_WR_sig,
        i_mem_read => mem_read_sig, 
        
        i_tx_addr => i_tx_addr_sig,
        i_tx_data => i_tx_data_sig,
        i_rx_data => i_rx_data_sig,
        
        o_STB => o_STB_sig,
        o_SDIO => o_SDIO_sig,
        o_trx_done => sig_o_trx_done
    );

end Behavioral;



