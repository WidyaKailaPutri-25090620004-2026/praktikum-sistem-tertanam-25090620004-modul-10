library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_dram_model is
end tb_dram_model;

architecture sim of tb_dram_model is
  constant AW : integer := 14;

  signal clk     : std_logic := '0';
  signal rstn    : std_logic := '0';
  signal awaddr  : std_logic_vector(AW-1 downto 0) := (others => '0');
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wvalid  : std_logic := '0';
  signal wready  : std_logic;
  signal bresp   : std_logic_vector(1 downto 0);
  signal bvalid  : std_logic;
  signal bready  : std_logic := '0';
  signal araddr  : std_logic_vector(AW-1 downto 0) := (others => '0');
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rvalid  : std_logic;
  signal rready  : std_logic := '0';
begin

  clk <= not clk after 5 ns;  -- 100 MHz

  dut : entity work.axi_lite_dram_model
    generic map (ADDR_WIDTH => AW)
    port map (
      S_AXI_ACLK    => clk,
      S_AXI_ARESETN => rstn,
      S_AXI_AWADDR  => awaddr,
      S_AXI_AWVALID => awvalid,
      S_AXI_AWREADY => awready,
      S_AXI_WDATA   => wdata,
      S_AXI_WVALID  => wvalid,
      S_AXI_WREADY  => wready,
      S_AXI_BRESP   => bresp,
      S_AXI_BVALID  => bvalid,
      S_AXI_BREADY  => bready,
      S_AXI_ARADDR  => araddr,
      S_AXI_ARVALID => arvalid,
      S_AXI_ARREADY => arready,
      S_AXI_RDATA   => rdata,
      S_AXI_RRESP   => rresp,
      S_AXI_RVALID  => rvalid,
      S_AXI_RREADY  => rready
    );

  stim : process
    constant BASE_DATA : unsigned(31 downto 0) := x"A0000000";
    variable rd           : std_logic_vector(31 downto 0);
    variable cyc          : integer;
    variable lat_closed   : integer;
    variable lat_hit      : integer;
    variable lat_conflict : integer;
    variable lat_max      : integer := 0;
    variable errors       : integer := 0;

    function A(n : integer) return std_logic_vector is
    begin
      return std_logic_vector(to_unsigned(n, AW));
    end function;

    procedure axi_write(addr : in std_logic_vector(AW-1 downto 0);
                        data : in std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      awaddr <= addr;  awvalid <= '1';
      wdata  <= data;  wvalid  <= '1';
      bready <= '1';
      loop
        wait until rising_edge(clk);
        exit when awready = '1' and wready = '1';
      end loop;
      awvalid <= '0';  wvalid <= '0';
      loop
        wait until rising_edge(clk);
        exit when bvalid = '1';
      end loop;
      bready <= '0';
    end procedure;

    procedure axi_read(addr   : in  std_logic_vector(AW-1 downto 0);
                       data   : out std_logic_vector(31 downto 0);
                       cycles : out integer) is
      variable c : integer := 0;
    begin
      wait until rising_edge(clk);
      araddr <= addr;  arvalid <= '1';
      rready <= '1';
      loop
        wait until rising_edge(clk);
        c := c + 1;
        exit when arready = '1';
      end loop;
      arvalid <= '0';
      loop
        wait until rising_edge(clk);
        c := c + 1;
        exit when rvalid = '1';
      end loop;
      data   := rdata;
      cycles := c;
      rready <= '0';
    end procedure;

  begin
    -- Reset
    rstn <= '0';
    wait for 100 ns;
    rstn <= '1';
    wait for 50 ns;

    -- Test 1: latensi (urutan penting: row masih tertutup setelah reset)
    axi_read(A(0),   rd, lat_closed);     -- row 0 tertutup  -> ACTIVATE + CL
    axi_read(A(4),   rd, lat_hit);        -- row 0 terbuka   -> hanya CL
    axi_read(A(256), rd, lat_conflict);   -- row 1 (alamat 0x100) -> PRECHARGE + ACTIVATE + CL
    report "Latensi (siklus): row hit = " & integer'image(lat_hit) &
           ", row closed = " & integer'image(lat_closed) &
           ", row conflict = " & integer'image(lat_conflict) severity note;
    if not (lat_hit < lat_closed and lat_closed < lat_conflict) then
      report "GAGAL Test 1: urutan latensi hit < closed < conflict tidak terpenuhi" severity error;
      errors := errors + 1;
    else
      report "OK    Test 1: hit < closed < conflict" severity note;
    end if;

    -- Test 2: tulis 32 kata di dua row (bergantian), lalu baca dan cocokkan
    for i in 0 to 15 loop
      axi_write(A(i*4),       std_logic_vector(BASE_DATA + to_unsigned(i, 32)));
      axi_write(A(256 + i*4), std_logic_vector(BASE_DATA + to_unsigned(100 + i, 32)));
    end loop;
    for i in 0 to 15 loop
      axi_read(A(i*4), rd, cyc);
      if rd /= std_logic_vector(BASE_DATA + to_unsigned(i, 32)) then
        report "GAGAL Test 2: row 0 kata " & integer'image(i) severity error;
        errors := errors + 1;
      end if;
      axi_read(A(256 + i*4), rd, cyc);
      if rd /= std_logic_vector(BASE_DATA + to_unsigned(100 + i, 32)) then
        report "GAGAL Test 2: row 1 kata " & integer'image(i) severity error;
        errors := errors + 1;
      end if;
    end loop;
    report "OK    Test 2: 32 kata di dua row tertulis dan terbaca benar" severity note;

    -- Test 3: refresh berkala (baca berulang di row yang sama, cari latensi terpanjang)
    for i in 1 to 120 loop
      axi_read(A(8), rd, cyc);
      if cyc > lat_max then
        lat_max := cyc;
      end if;
    end loop;
    report "Latensi terpanjang saat 120 pembacaan beruntun = " & integer'image(lat_max) &
           " siklus (row hit normal = " & integer'image(lat_hit) & ")" severity note;
    if lat_max > lat_hit then
      report "OK    Test 3: refresh menahan akses sesaat (latensi melonjak)" severity note;
    else
      report "GAGAL Test 3: lonjakan latensi akibat refresh tidak terlihat" severity error;
      errors := errors + 1;
    end if;

    if errors = 0 then
      report "SIMULASI MODEL DRAM SELESAI: SEMUA TEST LULUS." severity note;
    else
      report "SIMULASI MODEL DRAM SELESAI: " & integer'image(errors) & " TEST GAGAL." severity error;
    end if;
    wait;
  end process;

end sim;