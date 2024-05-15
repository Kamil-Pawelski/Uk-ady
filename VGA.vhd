------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; 

entity VGA is
    Port ( Clk_50MHz : in  STD_LOGIC;
           Res : in  STD_LOGIC;
           SampL : in  STD_LOGIC_VECTOR (15 downto 0);
           SampR : in  STD_LOGIC_VECTOR (15 downto 0);
           Srate_Tick : in  STD_LOGIC;
           VGA_R : out  STD_LOGIC;
           VGA_G : out  STD_LOGIC;
           VGA_B : out  STD_LOGIC;
           VGA_HS : out  STD_LOGIC;
           VGA_VS : out  STD_LOGIC);
end VGA;

architecture Behavioral of VGA is
	-- Visible area	800	16
	--	Front porch	56	1.12
	--	Sync pulse	120	2.4
	--	Back porch	64	1.28
	--	Whole line	1040	20.8 

    constant H_PX : unsigned(10 downto 0) := to_unsigned(1040, 11); -- (Visible area + Front porch + Sync pulse + Back porch) = Whole Frame 
    constant H_BS : unsigned(10 downto 0) := to_unsigned(856, 11); -- (Visible area + Front proch)
    constant H_AS : unsigned(10 downto 0) := to_unsigned(976, 11); -- (Visible area + Front porch + Sync pulse)
    
	 
	-- Visible area	600	12.48
	-- Front porch	37	0.7696
	-- Sync pulse	6	0.1248
	-- Back porch	23	0.4784
	-- Whole frame	666	13.8528
    constant V_PX : unsigned(10 downto 0) := to_unsigned(666, 11); -- (Visible area + Front porch + Sync pulse + Back porch) = Whole Frame
    constant V_BS : unsigned(10 downto 0) := to_unsigned(637, 11); -- (Visible area + Front proch)
    constant V_AS : unsigned(10 downto 0) := to_unsigned(643, 11); -- (Visible area + Front porch + Sync pulse)
    
    signal H_COUNTER : unsigned(10 downto 0) := (others => '0'); 
    signal V_COUNTER : unsigned(10 downto 0) := (others => '0'); 
    signal WRITE_COUNTER : unsigned(10 downto 0) := (others => '0'); 
	 -- osobny licznik adresu zapisu
	 -- Write address 10 bitowy sygnal
	 --
    signal V_ENABLE : std_logic := '0'; -- Sygna do uruchomienia countera dla pionowego
    signal VIDEO_ON : std_logic := '0'; -- Sygna wczenia wyjcia wideo
	 
    type rom_type is array (799 downto 0) of std_logic_vector (8 downto 0);                 
    signal ROM : rom_type := (others => "011111111");  -- Rom  
	
	 signal WRITE_ENABLE : std_logic := '0'; -- Sygna kontrolny wczajcy zapis do pamici ROM
	 

begin

	process(Clk_50MHz, Res)
    begin
        if Res = '1' then
            WRITE_ENABLE <= '0'; -- Wyczenie zapisu podczas resetowania ukadu
        elsif rising_edge(Clk_50MHz) then
            if Srate_Tick = '1' then
                WRITE_ENABLE <= '1'; -- Wczenie zapisu do pamici ROM gdy sygna prbkowania jest aktywny
            else
                WRITE_ENABLE <= '0'; -- Wyczenie zapisu, gdy sygna prbkowania jest nieaktywny
            end if;
        end if;
    end process;

  process(Clk_50MHz)
	begin
    if rising_edge(Clk_50MHz) and WRITE_ENABLE = '1' then
             WRITE_COUNTER <= WRITE_COUNTER + 1;
           ROM(to_integer(WRITE_COUNTER)) <= SampL(15 downto 7);  -- Zapisanie 9 MSB do ROM
    end if;
	end process;
    
	   
    process(Clk_50MHz, Res) -- Proces dla sygnau poziomego
    begin
        if Res = '1' then
            H_COUNTER <= (others => '0');
        elsif rising_edge(Clk_50MHz) then
            if H_COUNTER = H_PX - 1 then -- Licznik osign koniec liczby pikseli
                H_COUNTER <= (others => '0'); -- Wyzerowanie licznika
                V_ENABLE <= '1'; -- Wczenie licznika pionowego
            else
                H_COUNTER <= H_COUNTER + 1; -- Inkrementacja licznika poziomego
                V_ENABLE <= '0'; 
            end if;
        end if;
    end process;  
    
    process(Clk_50MHz, Res)
    begin
        if Res = '1' then
            V_COUNTER <= (others => '0');
        elsif rising_edge(Clk_50MHz) and V_ENABLE = '1' then
            if V_COUNTER = V_PX - 1 then -- Licznik osign koniec liczby pikseli
                V_COUNTER <= (others => '0'); -- Wyzerowanie licznika pionie
            else
                V_COUNTER <= V_COUNTER + 1; -- Inkrementacja licznika pionowego
            end if;
        end if;
    end process;
	 
	 VGA_HS <= '0' when (H_COUNTER >= H_BS and H_COUNTER < H_AS) else '1'; -- Sygna HS jest aktywny w czasie synchronizacji poziomej
    VGA_VS <= '0' when (V_COUNTER >= V_BS and V_COUNTER < V_AS) else '1'; -- Sygna VS jest aktywny w czasie synchronizacji pionowej

    VIDEO_ON <= '1' when (((to_integer(H_COUNTER) >= 0) and (to_integer(H_COUNTER) < 800)) -- Wczenie sygnau dla naszej widocznoci ekranu
                  and ((to_integer(V_COUNTER) >= 0)  and (to_integer(V_COUNTER) < 600))) else '0';
	

	process (H_COUNTER, V_COUNTER, VIDEO_ON)
	begin
		 if VIDEO_ON = '1' then
			  if H_COUNTER < 800 and V_COUNTER < 600 then
					if V_COUNTER = unsigned(ROM(to_integer(H_COUNTER))) then
						 VGA_R <= '1';
						 VGA_G <= '1';
						 VGA_B <= '1';
					else
						 VGA_R <= '0';
						 VGA_G <= '0';
						 VGA_B <= '0';
					end if;
			  else
					VGA_R <= '0';
					VGA_G <= '0';
					VGA_B <= '0';
			  end if;
		 else
			  VGA_R <= '0';
			  VGA_G <= '0';
			  VGA_B <= '0';
		 end if;
	end process;
end Behavioral;
