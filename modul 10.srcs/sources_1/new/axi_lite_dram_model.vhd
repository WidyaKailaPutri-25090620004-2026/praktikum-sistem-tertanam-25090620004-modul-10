library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Model memori mirip DRAM berantarmuka AXI4-Lite (UNTUK SIMULASI).
-- BUKAN MIG/DDR2 sungguhan: tidak ada PHY, kalibrasi, atau timing DDR.
-- Yang ditiru: latensi row hit / row closed / row conflict dan refresh berkala.
--
-- Pemetaan alamat (ADDR_WIDTH = 14 -> 16 KB = 4096 kata 32-bit):
--   addr(13:8) = ROW, addr(7:2) = COLUMN, addr(1:0) = byte (diabaikan)

entity axi_lite_dram_model is
  Generic (
    ADDR_WIDTH     : integer := 14;
    DATA_WIDTH     : integer := 32;
    T_RCD          : integer := 3;     -- ACTIVATE -> READ/WRITE (siklus)
    T_CL           : integer := 3;     -- latensi kolom (siklus)
    T_RP           : integer := 3;     -- PRECHARGE (siklus)
    REFRESH_PERIOD : integer := 400;   -- interval refresh (siklus)
    T_RFC          : integer := 20     -- lama refresh (siklus)
  );
  Port (
    S_AXI_ACLK    : in  STD_LOGIC;
    S_AXI_ARESETN : in  STD_LOGIC;
    S_AXI_AWADDR  : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
    S_AXI_AWVALID : in  STD_LOGIC;
    S_AXI_AWREADY : out STD_LOGIC;
    S_AXI_WDATA   : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    S_AXI_WVALID  : in  STD_LOGIC;
    S_AXI_WREADY  : out STD_LOGIC;
    S_AXI_BRESP   : out STD_LOGIC_VECTOR(1 downto 0);
    S_AXI_BVALID  : out STD_LOGIC;
    S_AXI_BREADY  : in  STD_LOGIC;
    S_AXI_ARADDR  : in  STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
    S_AXI_ARVALID : in  STD_LOGIC;
    S_AXI_ARREADY : out STD_LOGIC;
    S_AXI_RDATA   : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    S_AXI_RRESP   : out STD_LOGIC_VECTOR(1 downto 0);
    S_AXI_RVALID  : out STD_LOGIC;
    S_AXI_RREADY  : in  STD_LOGIC
  );
end axi_lite_dram_model;

architecture Behavioral of axi_lite_dram_model is
  constant ROW_LSB : integer := 8;

  type mem_t is array (0 to 2**(ADDR_WIDTH-2)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal mem : mem_t := (others => (others => '0'));

  type state_t is (IDLE, ACCESS_WAIT, RESP_W, RESP_R, REFRESH);
  signal state : state_t := IDLE;

  signal cnt      : integer range 0 to 1023  := 0;
  signal ref_cnt  : integer range 0 to 65535 := 0;
  signal row_open : std_logic := '0';
  signal open_row : unsigned(ADDR_WIDTH-ROW_LSB-1 downto 0) := (others => '0');
  signal is_write : std_logic := '0';
  signal lat_addr : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
  signal lat_wdata: std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

  signal awready_i, wready_i, bvalid_i, arready_i, rvalid_i : std_logic := '0';
  signal rdata_i : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
begin
  S_AXI_AWREADY <= awready_i;
  S_AXI_WREADY  <= wready_i;
  S_AXI_BVALID  <= bvalid_i;
  S_AXI_BRESP   <= "00";
  S_AXI_ARREADY <= arready_i;
  S_AXI_RVALID  <= rvalid_i;
  S_AXI_RRESP   <= "00";
  S_AXI_RDATA   <= rdata_i;

  process(S_AXI_ACLK)
    variable start : boolean;
    variable wr    : std_logic;
    variable a     : std_logic_vector(ADDR_WIDTH-1 downto 0);
    variable row   : unsigned(ADDR_WIDTH-ROW_LSB-1 downto 0);
    variable lat   : integer;
    variable idx   : integer;
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        state    <= IDLE;
        cnt      <= 0;
        ref_cnt  <= 0;
        row_open <= '0';
        awready_i <= '0'; wready_i <= '0'; arready_i <= '0';
        bvalid_i  <= '0'; rvalid_i <= '0';
      else
        awready_i <= '0'; wready_i <= '0'; arready_i <= '0';
        if ref_cnt < REFRESH_PERIOD then
          ref_cnt <= ref_cnt + 1;
        end if;

        case state is
          when IDLE =>
            if ref_cnt >= REFRESH_PERIOD then
              -- Refresh: semua row ditutup (precharge all)
              state    <= REFRESH;
              cnt      <= T_RFC;
              row_open <= '0';
              ref_cnt  <= 0;
            else
              start := false; wr := '0'; a := (others => '0');
              if S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' then
                start := true; wr := '1'; a := S_AXI_AWADDR;
                awready_i <= '1'; wready_i <= '1';
                lat_wdata <= S_AXI_WDATA;
              elsif S_AXI_ARVALID = '1' then
                start := true; wr := '0'; a := S_AXI_ARADDR;
                arready_i <= '1';
              end if;

              if start then
                row := unsigned(a(ADDR_WIDTH-1 downto ROW_LSB));
                if row_open = '1' and open_row = row then
                  lat := T_CL;                    -- row hit
                elsif row_open = '1' then
                  lat := T_RP + T_RCD + T_CL;     -- row conflict
                else
                  lat := T_RCD + T_CL;            -- row closed
                end if;
                is_write <= wr;
                lat_addr <= a;
                open_row <= row;
                row_open <= '1';
                cnt      <= lat;
                state    <= ACCESS_WAIT;
              end if;
            end if;

          when ACCESS_WAIT =>
            if cnt > 1 then
              cnt <= cnt - 1;
            else
              idx := to_integer(unsigned(lat_addr(ADDR_WIDTH-1 downto 2)));
              if is_write = '1' then
                mem(idx) <= lat_wdata;
                bvalid_i <= '1';
                state    <= RESP_W;
              else
                rdata_i  <= mem(idx);
                rvalid_i <= '1';
                state    <= RESP_R;
              end if;
            end if;

          when RESP_W =>
            if S_AXI_BREADY = '1' then
              bvalid_i <= '0';
              state    <= IDLE;
            end if;

          when RESP_R =>
            if S_AXI_RREADY = '1' then
              rvalid_i <= '0';
              state    <= IDLE;
            end if;

          when REFRESH =>
            if cnt > 1 then
              cnt <= cnt - 1;
            else
              state <= IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;
end Behavioral;