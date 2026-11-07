library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi_lite_gpio_v1_0 is
  Generic (
    C_S_AXI_ADDR_WIDTH : integer := 4;   -- 4 register x 4 byte = 16 byte
    C_S_AXI_DATA_WIDTH : integer := 32
  );
  Port (
    S_AXI_ACLK    : in  STD_LOGIC;
    S_AXI_ARESETN : in  STD_LOGIC;
    S_AXI_AWADDR  : in  STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_AWVALID : in  STD_LOGIC;
    S_AXI_AWREADY : out STD_LOGIC;
    S_AXI_WDATA   : in  STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_WVALID  : in  STD_LOGIC;
    S_AXI_WREADY  : out STD_LOGIC;
    S_AXI_BRESP   : out STD_LOGIC_VECTOR(1 downto 0);
    S_AXI_BVALID  : out STD_LOGIC;
    S_AXI_BREADY  : in  STD_LOGIC;
    S_AXI_ARADDR  : in  STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_ARVALID : in  STD_LOGIC;
    S_AXI_ARREADY : out STD_LOGIC;
    S_AXI_RDATA   : out STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP   : out STD_LOGIC_VECTOR(1 downto 0);
    S_AXI_RVALID  : out STD_LOGIC;
    S_AXI_RREADY  : in  STD_LOGIC;
    gpio_out      : out STD_LOGIC_VECTOR(15 downto 0);  -- ke LED
    sw            : in  STD_LOGIC_VECTOR(15 downto 0)   -- dari switch (TUGAS 1)
  );
end axi_lite_gpio_v1_0;

architecture Behavioral of axi_lite_gpio_v1_0 is
  signal awready_i, wready_i, bvalid_i : std_logic := '0';
  signal arready_i, rvalid_i           : std_logic := '0';
  signal aw_addr, ar_addr : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');

  signal reg0 : std_logic_vector(31 downto 0) := (others => '0'); -- LED (R/W)
  signal reg2 : std_logic_vector(31 downto 0) := (others => '0'); -- cadangan (R/W)
  signal reg3 : std_logic_vector(31 downto 0) := (others => '0'); -- cadangan (R/W)

  signal sw_meta, sw_sync : std_logic_vector(15 downto 0) := (others => '0');
  signal rdata_i : std_logic_vector(31 downto 0) := (others => '0');
  signal wren    : std_logic;
begin
  S_AXI_AWREADY <= awready_i;
  S_AXI_WREADY  <= wready_i;
  S_AXI_BVALID  <= bvalid_i;
  S_AXI_BRESP   <= "00";            -- OKAY
  S_AXI_ARREADY <= arready_i;
  S_AXI_RVALID  <= rvalid_i;
  S_AXI_RRESP   <= "00";            -- OKAY
  S_AXI_RDATA   <= rdata_i;

  gpio_out <= reg0(15 downto 0);

  -- Sinkronisasi 2 flip-flop untuk input switch (asinkron terhadap clock)
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      sw_meta <= sw;
      sw_sync <= sw_meta;
    end if;
  end process;

  ---------------------------------------------------------------- TULIS
  -- Terima alamat & data bersamaan (satu siklus awready/wready)
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        awready_i <= '0';
        wready_i  <= '0';
        aw_addr   <= (others => '0');
      else
        if awready_i = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' then
          awready_i <= '1';
          wready_i  <= '1';
          aw_addr   <= S_AXI_AWADDR;
        else
          awready_i <= '0';
          wready_i  <= '0';
        end if;
      end if;
    end if;
  end process;

  wren <= awready_i and S_AXI_AWVALID and wready_i and S_AXI_WVALID;

  -- Tulis ke register (reg1 read-only, jadi tidak ditulis)
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        reg0 <= (others => '0');
        reg2 <= (others => '0');
        reg3 <= (others => '0');
      elsif wren = '1' then
        case aw_addr(3 downto 2) is
          when "00"   => reg0 <= S_AXI_WDATA;
          when "10"   => reg2 <= S_AXI_WDATA;
          when "11"   => reg3 <= S_AXI_WDATA;
          when others => null;      -- "01" = reg1 (switch), read-only
        end case;
      end if;
    end if;
  end process;

  -- Response tulis (B channel)
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        bvalid_i <= '0';
      else
        if wren = '1' and bvalid_i = '0' then
          bvalid_i <= '1';
        elsif S_AXI_BREADY = '1' and bvalid_i = '1' then
          bvalid_i <= '0';
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------- BACA
  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        arready_i <= '0';
        ar_addr   <= (others => '0');
      else
        if arready_i = '0' and S_AXI_ARVALID = '1' then
          arready_i <= '1';
          ar_addr   <= S_AXI_ARADDR;
        else
          arready_i <= '0';
        end if;
      end if;
    end if;
  end process;

  process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        rvalid_i <= '0';
        rdata_i  <= (others => '0');
      else
        if arready_i = '1' and S_AXI_ARVALID = '1' and rvalid_i = '0' then
          rvalid_i <= '1';
          case ar_addr(3 downto 2) is
            when "00"   => rdata_i <= reg0;
            when "01"   => rdata_i <= x"0000" & sw_sync;  -- reg1: status switch
            when "10"   => rdata_i <= reg2;
            when others => rdata_i <= reg3;
          end case;
        elsif rvalid_i = '1' and S_AXI_RREADY = '1' then
          rvalid_i <= '0';
        end if;
      end if;
    end if;
  end process;

end Behavioral;
