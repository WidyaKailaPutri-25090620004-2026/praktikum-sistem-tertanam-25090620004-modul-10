library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_axi_lite_gpio is
end tb_axi_lite_gpio;

architecture sim of tb_axi_lite_gpio is
  signal clk     : std_logic := '0';
  signal rstn    : std_logic := '0';

  signal awaddr  : std_logic_vector(3 downto 0)  := (others => '0');
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wvalid  : std_logic := '0';
  signal wready  : std_logic;
  signal bresp   : std_logic_vector(1 downto 0);
  signal bvalid  : std_logic;
  signal bready  : std_logic := '0';
  signal araddr  : std_logic_vector(3 downto 0)  := (others => '0');
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rvalid  : std_logic;
  signal rready  : std_logic := '0';

  signal gpio_out : std_logic_vector(15 downto 0);
  signal sw       : std_logic_vector(15 downto 0) := (others => '0');
begin

  clk <= not clk after 5 ns;  -- 100 MHz

  dut : entity work.axi_lite_gpio_v1_0
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
      S_AXI_RREADY  => rready,
      gpio_out      => gpio_out,
      sw            => sw
    );

  stim : process
    variable rd : std_logic_vector(31 downto 0);

    procedure axi_write(addr : in std_logic_vector(3 downto 0);
                        data : in std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      awaddr  <= addr;  awvalid <= '1';
      wdata   <= data;  wvalid  <= '1';
      bready  <= '1';
      loop                                   -- tunggu handshake AW & W
        wait until rising_edge(clk);
        exit when awready = '1' and wready = '1';
      end loop;
      awvalid <= '0';  wvalid <= '0';
      loop                                   -- tunggu response B
        wait until rising_edge(clk);
        exit when bvalid = '1';
      end loop;
      bready <= '0';
    end procedure;

    procedure axi_read(addr : in  std_logic_vector(3 downto 0);
                       data : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      araddr  <= addr;  arvalid <= '1';
      rready  <= '1';
      loop                                   -- tunggu handshake AR
        wait until rising_edge(clk);
        exit when arready = '1';
      end loop;
      arvalid <= '0';
      loop                                   -- tunggu data R
        wait until rising_edge(clk);
        exit when rvalid = '1';
      end loop;
      data   := rdata;
      rready <= '0';
    end procedure;

  begin
    -- Reset
    rstn <= '0';
    wait for 100 ns;
    rstn <= '1';
    wait for 50 ns;

    -- Test 1: tulis reg0 (LED), cek gpio_out
    axi_write(x"0", x"0000A5A5");
    wait for 20 ns;
    assert gpio_out = x"A5A5"
      report "GAGAL Test 1: gpio_out tidak sama dengan A5A5" severity error;

    -- Test 2: baca balik reg0
    axi_read(x"0", rd);
    assert rd = x"0000A5A5"
      report "GAGAL Test 2: baca reg0 salah" severity error;

    -- Test 3: baca reg1 (switch)
    sw <= x"1234";
    wait for 100 ns;                         -- tunggu sinkronisasi 2 FF
    axi_read(x"4", rd);
    assert rd = x"00001234"
      report "GAGAL Test 3: baca reg1 (switch) salah" severity error;

    -- Test 4: reg1 read-only, tulisan harus diabaikan
    axi_write(x"4", x"FFFFFFFF");
    axi_read(x"4", rd);
    assert rd = x"00001234"
      report "GAGAL Test 4: reg1 seharusnya read-only" severity error;

    -- Test 5: reg2 tulis lalu baca
    axi_write(x"8", x"DEADBEEF");
    axi_read(x"8", rd);
    assert rd = x"DEADBEEF"
      report "GAGAL Test 5: reg2 salah" severity error;

    report "SIMULASI SELESAI. Jika tidak ada pesan GAGAL berarti semua test lulus."
      severity note;
    wait;
  end process;

end sim;