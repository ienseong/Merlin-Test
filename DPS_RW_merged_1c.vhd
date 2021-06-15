-- added
--11.3.3 from parallel to serial

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DPS_1 is
	generic (N:integer :=16
	 );
	 
	port (
		-- Users to add ports here
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
           o_trx_done: out std_logic
           
	);
end DPS_1;

architecture arch_imp of DPS_1 is
	
 	type DPS_state is(st_idle,st_tx_wr_bit,st_tx_rstr_bit,st_send_addr,st_hiz1,st_start_bit,--
 	                  st_send_data,st_tx_stop_bit,st_hiz2, st_trx_done);
 	signal st_reg: DPS_state:=st_idle;
 	
 	type DPS_reg_state is(st_reg_per_ch_res, st_reg_cent_res, st_reg_ch_dc_level);
 	signal st_reg_map: DPS_reg_state:=st_reg_per_ch_res;
 	                  
 	
-- 	signal s_clk_cnt:integer range 0 to 40:=0;
 	signal s_bit_idx:integer range 0 to N-1:=0;

 	signal s_tx_addr:std_logic_vector(N-1 downto 0):=(others => '0');
 	signal s_tx_data:std_logic_vector(N-1 downto 0):=(others => '0');
 	signal s_rx_data:std_logic_vector(N-1 downto 0):=(others => '0');
 	
 	-- parsing
    
    signal reg_cent_bit: std_logic_vector(1 downto 0);
    signal ch_addr: std_logic_vector(7 downto 0);
    signal ch_res_addr: std_logic_vector(5 downto 0);
    signal cent_res_addr: std_logic_vector(6 downto 0);
    
    signal ch_dc_level_dest: std_logic_vector(7 downto 0);
 	signal ch_dc_level_func: std_logic_vector(1 downto 0);
 	signal ch_dc_level_addr: std_logic_vector(3 downto 0);
 	
 	-- control register
 	-- 0. Source Feedback Selection
 	-- 1. DPS Control/Misc
 	-- 2. Clamp and Alarm Cont
    
    -- 2. Clamp and Alarm Cont
    
 	signal WE: std_logic_vector(5 downto 0);
 	signal Sel_RT_D: std_logic_vector(5 downto 0);
 	signal CPU_D1: std_logic_vector(5 downto 0);
 	signal CPU_D0: std_logic_vector(5 downto 0);
 	signal WE: std_logic_vector(5 downto 0);-- common
 	signal FVR: std_logic_vector(5 downto 0);
 	signal WE: std_logic_vector(5 downto 0);-- common
 	signal FI_FV: std_logic_vector(5 downto 0);
 	signal WE: std_logic_vector(5 downto 0);-- common
 	signal Sel_V_FB1: std_logic_vector(5 downto 0);
 	signal Sel_V_FB0: std_logic_vector(5 downto 0);
 	signal WE: std_logic_vector(5 downto 0);-- common
 	signal Sel_VForce: std_logic_vector(5 downto 0);
 	signal WE: std_logic_vector(5 downto 0);-- common
 	signal Tight_Loop: std_logic_vector(5 downto 0);
 	 	
    -- 3. Status Read Check
    signal Tight_Loop: std_logic_vector(5 downto 0);

    -- 4. Diagnostics and Calib 
    -- 5. Measurement Unit Source Selection
    -- 6. Offset Adjust
    -- 7. Gain Adjust
    -- 8. CME Adjust IR0
    -- 9. CME Adjust IR1
    -- 10. CME Adjust IR2
    -- 11. CME Adjust IR3 / Low voltage
    -- 12. CME Adjust IR3 / High voltage 
    -- 13. CME Adjust IR4 / Low voltage
    -- 14. CME Adjust IR4 / High voltage
    -- 15. CME Adjust IR5
    -- 16. CME Adjust IR5{
 	
 	
 	signal s_tx_done:std_logic:='0';
 	signal s_rx_done:std_logic:='0';
 	
 	signal s_rstr_bit : STD_LOGIC:='0';--restricted
 	signal s_tx_stop_bit : STD_LOGIC:='0';

 	signal reg_read_data: std_logic_vector(N-1 downto 0):= x"F731";
 	
 	begin
    
    s_tx_addr<=i_tx_addr;
    s_tx_data<=i_tx_data;
    
    o_trx_done <= s_tx_done or s_rx_done;
       
 	p_tx_rx_stm: process(clk, rst)
 	begin
 	  if(rst = '0') then
          s_bit_idx<=0;
                  
          o_STB<='0';
          o_STB<='0';
          s_tx_done <='0';
	       
	  elsif(rising_edge(clk)) then 
        case st_reg is
              when st_idle =>
                  s_bit_idx<=0;
                  
                  o_STB<='0';
                  o_SDIO<='0';
                  s_tx_done <='0';
                  
                  if (i_cmd='1') then
                    o_STB<='1'; -- start
                    o_SDIO<=i_WR;
                    
                    st_reg<=st_tx_wr_bit;
                  else
                    st_reg<=st_idle;
                  end if;
              
              when st_tx_wr_bit =>
                o_SDIO<=s_rstr_bit;
                st_reg<=st_tx_rstr_bit;
              
              when st_tx_rstr_bit =>
                st_reg<=st_send_addr;
                
                o_SDIO<= s_tx_addr(s_bit_idx);
                
              when st_send_addr =>
                s_bit_idx<= s_bit_idx +1;
                
                if( s_bit_idx < N-1) then
                    st_reg<=st_send_addr;
                    o_SDIO<= s_tx_addr(s_bit_idx+1);
                elsif(s_bit_idx = N-1) then
                    s_bit_idx<= 0;
                    
                    -- different routine wrt write and read
                    if(i_WR='1') then--write
                        o_SDIO<= s_tx_data(0);
                        st_reg<=st_send_data;
                    else --read
                        st_reg<=st_hiz1;
                    end if;
                end if;
                
              when st_hiz1 => -- read mode
                if( s_bit_idx < 1) then
                    o_SDIO<= '0';
                    s_bit_idx<= 0;
                    st_reg<=st_start_bit;
                else
                    s_bit_idx<= 0;
                    st_reg<=st_start_bit;
                end if;
                
             when st_start_bit =>
                if(i_WR='0') then--Memory read Cycle write
                    if(i_mem_read = '1') then -- memory read
                        if( s_bit_idx < 2) then
                            s_bit_idx<= s_bit_idx +1;
                            o_SDIO<= '0';
                        else
                            s_bit_idx<= 0;
                            o_SDIO<=reg_read_data(0);
                            s_rx_data(0)<= o_SDIO;
                            
                            st_reg<=st_send_data;    
                        end if;
                        
                    else -- register read
                        s_bit_idx<= 0;
                        if( s_bit_idx < 1) then
                            o_SDIO<=reg_read_data(0);
                            s_rx_data(0)<= o_SDIO;
                            st_reg<=st_send_data;
                        end if;
                    end if;
                
                else -- write
                    s_bit_idx<= 0;
                    st_reg<=st_send_data;
                end if;
                  
              when st_send_data =>
                s_bit_idx<= s_bit_idx +1;
                
                if( i_WR='1' and s_bit_idx < N-1) then -- write
                    st_reg<=st_send_data;
                    o_SDIO<= s_tx_data(s_bit_idx+1);
                    
                elsif( i_WR='0' and s_bit_idx < N-1) then --read
                    o_SDIO<= reg_read_data(s_bit_idx+1);
                    s_rx_data(s_bit_idx)<= o_SDIO;
                    st_reg<=st_send_data;
                else
                    if(i_WR='0') then --only when read
                        s_rx_data(s_bit_idx)<= o_SDIO;
                    end if;

                    s_bit_idx<= 0;
                    s_tx_stop_bit <='1';
                    o_SDIO<= s_tx_stop_bit;
                    st_reg<= st_tx_stop_bit;
                end if;
                                    
              when st_tx_stop_bit =>
                if(i_WR='1') then
                    s_tx_done <='1';
                    st_reg<=st_trx_done;
                else
                    st_reg<= st_hiz2;
                end if;
                
                o_STB<='0';
                o_SDIO<= '0';
                s_tx_stop_bit <='0';
              
              when st_hiz2 =>
                s_rx_done <='1';
                o_SDIO<= '0';

--                reg_read_data <= std_logic_vector(unsigned( reg_read_data) + 1);
                reg_read_data <= std_logic_vector(unsigned( reg_read_data)+7);
--                reg_read_data <= std_logic_vector(unsigned( reg_read_data));
                
                i_rx_data <= s_rx_data;-- transfer to rx vector
                st_reg<=st_trx_done;
                  
              when st_trx_done =>
                s_tx_done <='0';
                s_rx_done <='0';
                st_reg<=st_idle;
                
              when others =>
                st_reg <=st_idle;
          end case;
       end if;
 	end process;
 	
 	reg_cent_bit <= s_tx_addr(15 downto 14);
 	
 
 
 
DPS_reg_res_ctrl: process(clk, rst)
begin
	 case reg_cent_bit is
		when  X"10"=> -- per channel resource register
			if(i_WR='1') then -- write
				s_tx_addr(13 downto 6)	<= ch_addr;
				s_tx_addr(5 downto 0)   <= ch_res_addr ;
			else              -- read
				ch_addr 			    <= s_rx_data(13 downto 6);
				ch_res_addr 		    <= s_rx_data(5 downto 0);
			end if;
			  
		when  X"11"=>-- central resource register
			if(i_WR='1') then -- write
				s_tx_addr(6 downto 0)   <= cent_res_addr;
			else              -- read
				cent_res_addr 			<= s_rx_data(13 downto 6);
			end if;
			
		when  X"00"=>-- channel #DC level storage
			if(i_WR='1') then -- write 
				s_tx_addr(13 downto 6)	<= ch_dc_level_dest;
				s_tx_addr(5 downto 4)   <= ch_dc_level_func;
				s_tx_addr(3 downto 0)   <= ch_dc_level_addr;
			else                -- read
				ch_dc_level_dest 		<= s_rx_data(13 downto 6);
				ch_dc_level_func 		<= s_rx_data(5 downto 4);
				ch_dc_level_addr 		<= s_rx_data(3 downto 0);
			end if;
	 end case;
end process;
	
 per_ch_ctrl_read: process(clk, rst) -- read from per channel resource register
    begin
        if(reg_cent_bit="10") then
            case to_unsigned(ch_res_addr)is
                when 0 => -- source and feedback selection
                    ch_WE0_14  			<= s_rx_data(14); 
                    Sel_RT_D   			<= s_rx_data(13); 
                    CPU_D10    			<= s_rx_data(12 downto 11);  
                    
                    ch_WE0_10  			<= s_rx_data(10);
                    FVR        			<= s_rx_data(9);
                    
                    ch_WE0_8   			<= s_rx_data(8);
                    FI_FV      			<= s_rx_data(7);
                    
                    ch_WE0_6      		<= s_rx_data(6);
                    Sel_V_FB10  		<= s_rx_data(5 downto 4);
                    
                    ch_WE0_3      		<= s_rx_data(3);
                    Sel_VForce 			<= s_rx_data(2);
                    
                    ch_WE0_1      		<= s_rx_data(1);
                    Tight_Loop 			<= s_rx_data(0);
                                              
                when 1 => -- DPS Control/Misc
                    ch_WE1_15      		<= s_rx_data(15);
                    Con_Res    			<= s_rx_data(14 downto 12);
                    Con_Res_adj			<= s_rx_data(11);
                    Con_Cap    			<= s_rx_data(10 downto 6);
                    
                    ch_WE1_5      	 	<= s_rx_data(5);
                    FV_Mode    			<= s_tx_datas_rx_data(4);
                    
                    ch_WE1_3      		<= s_rx_data(3);
                    Sel_DPS_En 			<= s_rx_data(2);
                    Sel_RT_En  			<= s_rx_data(1);
                    CPU_En     			<= s_rx_data(0);
                    
                    
                when 2 => -- Clamp and Alarm Cont
                    ch_WE2_14      		<= s_rx_data(14);

--                    Kel_Al_Reset<= s_rx_data(13); -- write only
--                    Cl_Reset    <= s_rx_data(12);
                    
                    ch_WE2_11      		<= s_rx_data(11);
                    Sel_Kel_Al     		<= s_rx_data(10);
                    
                    ch_WE2_9       		<= s_rx_data(9);
                    CPU_OV_OI_En   		<= s_rx_data(8);
                    CPU_Kel_Al_En  		<= s_rx_data(7);
                    CPU_OT_Dis     		<= s_rx_data(6);
                    
                    ch_WE2_5       		<= s_rx_data(5);
                    Sel_MI4        		<= s_rx_data(4);
                    Sel_MI_Cl      		<= s_rx_data(3);
                    Cl_Al_En       		<= s_rx_data(2);
                    Cl_En          		<= s_rx_data(1);
                    Sel_Cl_Al      		<= s_rx_data(0);
                    
                    
                when 3 => -- Status Read Check
                    L_OT_Al     		<= s_rx_data(13);
                    RT_OT_Al    		<= s_rx_data(12);
                    
                    -- read only
                    Sel_FV10       		<= s_rx_data(11 downto 10);
                    DPS_En         		<= s_rx_data(9);
                    Cham_Alarm     		<= s_rx_data(8);                    
                    L_OV_Vch_Ol_Src		<= s_rx_data(7);                    
                    RT_Ol_Src      		<= s_rx_data(6);
                    OV_Vch_Ol_Src  		<= s_rx_data(5);
                    L_OV_Vcl_Ol_Snk		<= s_rx_data(4);
                    RT_Ol_Snk      		<= s_rx_data(3);
                    Ol_Snk         		<= s_rx_data(2);
                    L_Kel_Al       		<= s_rx_data(1);
                    RT_Kel_Al      		<= s_rx_data(0);
                    
                    
                when 4 => -- Diagnostics and Calib
                    ch_WE4_15      		<= s_rx_data(15);
                    Kelvin         		<= s_rx_data(14 downto 11);
                    
                    ch_WE4_10      		<= s_rx_data(10);
                    Con_EF_ES      		<= s_rx_data(9);
                    Con_FS      		<= s_rx_data(8);
                    Con_ES_F    		<= s_rx_data(7);
                    Con_ES_S    		<= s_rx_data(6);
                    Con_EF_F    		<= s_rx_data(5);
                    
                    ch_WE4_4    		<= s_rx_data(4);
                    Sel_Diag    		<= s_rx_data(3 downto 0);
                    
                     
                when 5 => -- Measurement Unit Source Selection
                    ch_WE5_15   		<= s_rx_data(15);
                    Bbias       		<= s_rx_data(14);
                    Sel_G_Out   		<= s_rx_data(13);
                    
                    ch_WE5_12   		<= s_rx_data(12);
                    IR          		<= s_rx_data(11 downto 6);
                    
                    ch_WE5_5    		<= s_rx_data(5);
                    Sel_MU_Neg10		<= s_rx_data(4 downto 3);
                    
                    ch_WE5_2    		<= s_rx_data(2);
                    Sel_MU_Pos10		<= s_rx_data(1 downto 0);
                    
                    
                when 6 => -- Offset Adjust
                    ch_WE6_8    		<= s_rx_data(8);
                    OS          		<= s_rx_data(7 downto 0);
                    
                when 7 => -- Gain Adjust
                    ch_WE7_8    		<= s_rx_data(8);
                    Av          		<= s_rx_data(7 downto 0);
                    
                when 8 => -- CME Adjust IR0
                    ch_WE8_8    		<= s_rx_data(8);
                    CME_Adj0    		<= s_rx_data(7 downto 0);
                    
                when 9 => -- CME Adjust IR1
                    ch_WE9_8    		<= s_rx_data(8);
                    CME_Adj1    		<= s_rx_data(7 downto 0);
                    
                when 10 => -- CME Adjust IR2
                    ch_WE10_8    		<= s_rx_data(8);
                    CME_Adj2     		<= s_rx_data(7 downto 0);
                    
                when 11 => -- CME Adjust IR3 / Low voltage
                    ch_WE11_8    		<= s_rx_data(8);
                    CME_LAdj3    		<= s_rx_data(7 downto 0);
                    
                when 12 => -- CME Adjust IR3 / High voltage 
                    ch_WE12_8    		<= s_rx_data(8);
                    CME_HAdj3    		<= s_rx_data(7 downto 0);
                    
                when 13 => -- CME Adjust IR4 / Low voltage
                    ch_WE13_8    		<= s_rx_data(8);
                    CME_HAdj4    		<= s_rx_data(7 downto 0);
                
                when 14 => -- CME Adjust IR4 / High voltage
                    ch_WE14_8    		<= s_rx_data(8);
                    CME_Adj4     		<= s_rx_data(7 downto 0);
                
                when 15 => -- CME Adjust IR5
                    ch_WE15_8    		<= s_rx_data(8);
                    CME_Adj5     		<= s_rx_data(7 downto 0);
                    
                when 17 => -- Per channel Measurement Unit Ctrl/Ganging
                    ch_WE17_8    		<= s_rx_data(8);
                    MUR10        		<= s_rx_data(7 downto 6);
                    
                    ch_WE17_5    		<= s_rx_data(5);
                    Sel_Mon_OE   		<= s_rx_data(4);
                    CPU_Mon_OE   		<= s_rx_data(3);
                
                when others => 
                
             end case;
        end if;        
    end process;
    
    
    cent_res_read: process(clk, rst) -- read from central resource register
    begin
        if(reg_cent_bit="11") then
            case to_unsigned(cent_res_addr)is
                when 0 => -- CPU_Reset(Blue_Write only)
                    cent_WE1_13			<= s_rx_data(13);
                    
                    cent_WE1_9       	<= s_rx_data(9);
                    MUR10            	<= s_rx_data(8 downto 7);
                    
                    cent_WE1_6       	<= s_rx_data(6);
                    Sel_Mon_OE       	<= s_rx_data(5);
                    CPU_Mon_OE       	<= s_rx_data(4);
                    
                    cent_WE1_3       	<= s_rx_data(3);
                    Sel_MU           	<= s_rx_data(2 downto 0);
                
                when 1 => -- Measurement Unit Control/Ganging
                    cent_WE2_13			<= s_rx_data(13);
                    
                    cent_WE2_9          <= s_rx_data(9);
                    MUR                 <= s_rx_data(8 downto 7);
                    
                    cent_WE2_6          <= s_rx_data(6);
                    Sel_Mon_OE          <= s_rx_data(5);
                    CPU_Mon_OE          <= s_rx_data(4);
                    
                    cent_WE2_3        	<= s_rx_data(3);
                    Sel_MU            	<= s_rx_data(2 downto 0);
                    
                
                when 2 => -- Measure Current Monitor/Central Level Select
                    cent_WE2_11       	<= s_rx_data(11);
                    CPU_Cent_D        	<= s_rx_data(10 downto 7);
                    
                    cent_WE1_6        	<= s_rx_data(6);
                    Sel_MI_Mon_OE     	<= s_rx_data(5);
                    CPU_MI_Mon_OE     	<= s_rx_data(4);
                    
                    cent_WE1_3        	<= s_rx_data(3);
                    Sel_Cent_MI       	<= s_rx_data(2 downto 0);
                
                
                when 3 => -- Alarm Control
                    L_OT              	<= s_rx_data(15);
                    RT_OT             	<= s_rx_data(14);
                    OT_Alarm          	<= s_rx_data(13);
                    
                    dc_WE3_10         	<= s_rx_data(10);
                    GBL_CPU_OT_DIS    	<= s_rx_data(9);
                    CPU_Alarm         	<= s_rx_data(8);
                    
                    dc_WE3_7          	<= s_rx_data(7);
                    CPU_Alarm_En      	<= s_rx_data(6);
                    
                    dc_WE3_5          	<= s_rx_data(5);
                    CPU_OT            	<= s_rx_data(4);
                    
                    dc_WE3_3          	<= s_rx_data(3);
                    CPU_Tj_En         	<= s_rx_data(2);
                    
                    dc_WE3_1          	<= s_rx_data(1);
                    Sel_OT_Alarm      	<= s_rx_data(0);
                    
                when 4 => -- Upper DAC Bit Calib
                    dc_WE4_12         	<= s_rx_data(12);
                    D14_Cal           	<= s_rx_data(11 downto 7);
                    
                    dc_WE4_6          	<= s_rx_data(6);
                    D15_Cal           	<= s_rx_data(5 downto 0);
                
                when 5 => -- Mid DAC Bit Calib
                    dc_WE5_13         	<= s_rx_data(13);
                    LSB_Auto_Cal      	<= s_rx_data(12);
                    
                    dc_WE5_11         	<= s_rx_data(11);
                    D11_Cal           	<= s_rx_data(10 downto 9);
                    
                    dc_WE5_8          	<= s_rx_data(8);
                    D12_Cal           	<= s_rx_data(7 downto 5);
                    
                    dc_WE5_4          	<= s_rx_data(4);
                    D13_Cal           	<= s_rx_data(3 downto 0);
                
                when 6 => -- DAC-N/DAC-P
                    DAC_N            	<= s_rx_data(14 downto 8);
                    DAC_P             	<= s_rx_data(7 downto 0);
                
                when 127 => -- Die ID (Yellow = Read only)
                    Prod_ID           	<= s_rx_data(15 downto 4);
                    Die_Rev           	<= s_rx_data(3 downto 0);
                    
                when others => -- source and feedback selection
                
                
                
             end case;
        end if;        
    end process;
    
  
    
    per_ch_ctrl_write: process(clk, rst) -- write to per channel resource register
    begin
        if(reg_cent_bit="10") then
            case to_unsigned(ch_res_addr)is
                when 2 => -- Clamp and Alarm Cont
                    Kel_Al_Reset		<= s_rx_data(13);
                    Cl_Reset    		<= s_rx_data(12);
                when others => 
                end case;
        end if;        
    end process;
    
    cent_res_write: process(clk, rst) -- write to central resource control register
    begin
        if(reg_cent_bit="11") then
            case to_unsigned(ch_res_addr)is
                when 2 => -- Clamp and Alarm Cont
                    Kel_Al_Reset		<= s_rx_data(13);
                    Cl_Reset    		<= s_rx_data(12);
                    
                when others => 
                end case;
        end if;        
    end process; 
    
    
    ch_DC_level_write: process(clk, rst) -- write to channel DC level storage
    begin
        if(reg_cent_bit="00") then
            case to_unsigned(ch_res_addr)is
                when 3 => -- source and feedback selection
                    cent_WE3_12       	<= s_rx_data(12);
                    OT_Flag_Reset     	<= s_rx_data(11);
                    
                when others => 
                end case;
        end if;        
    end process;      
    
    
         
      
    
    
         
    
    
    
                    
                    
--    A_ch_res_addr <= ch_res_addr; -- per ch res addr
--    A_cent_addr <= cent_res_addr; -- central res addr
    
    
--    p_ch_res_addr: process(clk, rst)
--    begin
--        A5_addr <=ch_res_addr(5);
--        A4_addr <=ch_res_addr(4);
--        A3_addr <=ch_res_addr(3);
--        A2_addr <=ch_res_addr(2);
--        A1_addr <=ch_res_addr(1);
--        A0_addr <=ch_res_addr(0);
--    end process;

--    p_ch_res_addr: process(clk, rst)
--    begin
--        A5_addr <=cent_res_addr(5);
--        A4_addr <=cent_res_addr(4);
--        A3_addr <=cent_res_addr(3);
--        A2_addr <=cent_res_addr(2);
--        A1_addr <=cent_res_addr(1);
--        A0_addr <=cent_res_addr(0);
--    end process;


    
    
    
    
    
    
end arch_imp;

