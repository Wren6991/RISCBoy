#include <iostream>
#include <fstream>
#include <cstdint>
#include <string>
#include <stdio.h>

#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

// Device-under-test model generated by CXXRTL:
#include "dut.cpp"
#include <backends/cxxrtl/cxxrtl_vcd.h>

// There must be a better way
#ifdef __x86_64__
#define I64_FMT "%ld"
#else
#define I64_FMT "%lld"
#endif

// -----------------------------------------------------------------------------

static const int MEM_SIZE = 1 * 1024 * 1024;
static const int N_RESERVATIONS = 2;
static const uint32_t RESERVATION_ADDR_MASK = 0xfffffff8u;

static const unsigned int IO_BASE = 0xf000;
enum {
	IO_PRINT_CHAR     = 0x000,
	IO_PRINT_U32      = 0x004,
	IO_EXIT           = 0x008,
	IO_RUNNING_IN_SIM = 0x00c
};

struct mem_io_state {

	bool exit_req;
	uint32_t exit_code;

	uint8_t *mem;

	mem_io_state() {
		exit_req = false;
		exit_code = 0;
		mem = new uint8_t[MEM_SIZE];
		for (size_t i = 0; i < MEM_SIZE; ++i)
			mem[i] = 0;
	}

	// Where we're going we don't need a destructor B-)

	void step() {
	}
};

struct bus_response {
	uint32_t rdata;
	bool err;
	bus_response(): rdata(0), err(false) {}
};

bus_response mem_access(mem_io_state &memio, uint32_t addr, bool write, uint32_t wdata) {
	bus_response resp;

	if (write) {
		if (addr == IO_BASE + IO_PRINT_CHAR) {
			putchar(wdata);
		}
		else if (addr == IO_BASE + IO_PRINT_U32) {
			printf("%08x\n", wdata);
		}
		else if (addr == IO_BASE + IO_EXIT) {
			if (!memio.exit_req) {
				memio.exit_req = true;
				memio.exit_code = wdata;
			}
		}
		else {
			resp.err = true;
		}
	}
	else {
		if (addr == IO_BASE + IO_RUNNING_IN_SIM) {
			resp.rdata = 1;
		}
		else {
			resp.err = true;
		}
	}
	return resp;
}

// -----------------------------------------------------------------------------

const char *help_str =
"Usage: tb [--bin x.bin] [--port n] [--vcd x.vcd] [--dump start end] \\\n"
"          [--cycles n] [--cpuret] [--jtagdump x] [--jtagreplay x]\n"
"\n"
"    --bin x.bin      : Flat binary file loaded to address 0x0 in RAM\n"
"    --vcd x.vcd      : Path to dump waveforms to\n"
"    --dump start end : Print out memory contents from start to end (exclusive)\n"
"                       after execution finishes. Can be passed multiple times.\n"
"    --cycles n       : Maximum number of cycles to run before exiting.\n"
"                       Default is 0 (no maximum).\n"
"    --cpuret         : Testbench's return code is the return code written to\n"
"                       IO_EXIT by the CPU, or -1 if timed out.\n"
;

void exit_help(std::string errtext = "") {
	std::cerr << errtext << help_str;
	exit(-1);
}

int main(int argc, char **argv) {

	bool load_bin = false;
	std::string bin_path;
	bool dump_waves = false;
	std::string waves_path;
	std::vector<std::pair<uint32_t, uint32_t>> dump_ranges;
	int64_t max_cycles = 0;
	bool propagate_return_code = false;
	uint16_t port = 0;

	for (int i = 1; i < argc; ++i) {
		std::string s(argv[i]);
		if (s.rfind("--", 0) != 0) {
			std::cerr << "Unexpected positional argument " << s << "\n";
			exit_help("");
		}
		else if (s == "--bin") {
			if (argc - i < 2)
				exit_help("Option --bin requires an argument\n");
			load_bin = true;
			bin_path = argv[i + 1];
			i += 1;
		}
		else if (s == "--vcd") {
			if (argc - i < 2)
				exit_help("Option --vcd requires an argument\n");
			dump_waves = true;
			waves_path = argv[i + 1];
			i += 1;
		}
		else if (s == "--dump") {
			if (argc - i < 3)
				exit_help("Option --dump requires 2 arguments\n");
			dump_ranges.push_back(std::pair<uint32_t, uint32_t>(
				std::stoul(argv[i + 1], 0, 0),
				std::stoul(argv[i + 2], 0, 0)
			));;
			i += 2;
		}
		else if (s == "--cycles") {
			if (argc - i < 2)
				exit_help("Option --cycles requires an argument\n");
			max_cycles = std::stol(argv[i + 1], 0, 0);
			i += 1;
		}
		else if (s == "--cpuret") {
			propagate_return_code = true;
		}
		else {
			std::cerr << "Unrecognised argument " << s << "\n";
			exit_help("");
		}
	}

	mem_io_state memio;

	if (load_bin) {
		std::ifstream fd(bin_path, std::ios::binary | std::ios::ate);
		if (!fd){
			std::cerr << "Failed to open \"" << bin_path << "\"\n";
			return -1;
		}
		std::streamsize bin_size = fd.tellg();
		if (bin_size > MEM_SIZE) {
			std::cerr << "Binary file (" << bin_size << " bytes) is larger than memory (" << MEM_SIZE << " bytes)\n";
			return -1;
		}
		fd.seekg(0, std::ios::beg);
		fd.read((char*)memio.mem, bin_size);
	}

	cxxrtl_design::p_riscboy__core top;

	std::ofstream waves_fd;
	cxxrtl::vcd_writer vcd;
	if (dump_waves) {
		waves_fd.open(waves_path);
		cxxrtl::debug_items all_debug_items;
		top.debug_info(all_debug_items);
		vcd.timescale(1, "us");
		vcd.add(all_debug_items);
	}

	// Set bus interfaces to generate good OKAY responses at first
	top.p_tbio__pready.set<bool>(true);
	top.p_tbio__pslverr.set<bool>(false);

	bool next_sram_oe_n = true;
	bool next_sram_ce_n = true;
	bool next_sram_we_n = true;
	uint8_t next_sram_byte_n = 0xff;
	uint32_t next_sram_addr = 0;
	uint16_t next_sram_rdata = 0;

	// Reset + initial clock pulse

	top.step();
	top.p_clk__sys.set<bool>(true);
	top.p_clk__lcd__bit.set<bool>(true);
	top.step();
	top.p_clk__sys.set<bool>(false);
	top.p_clk__lcd__bit.set<bool>(false);
	top.p_rst__n.set<bool>(true);
	top.step();
	top.step(); // workaround for github.com/YosysHQ/yosys/issues/2780

	bool timed_out = false;
	for (int64_t cycle = 0; cycle < max_cycles || max_cycles == 0; ++cycle) {
		top.p_clk__sys.set<bool>(false);
		top.p_clk__lcd__bit.set<bool>(false);
		top.step();
		if (dump_waves)
			vcd.sample(cycle * 2);
		top.p_clk__sys.set<bool>(true);
		top.p_clk__lcd__bit.set<bool>(true);
		top.step();
		top.step(); // workaround for github.com/YosysHQ/yosys/issues/2780

		bool got_exit_cmd = false;
		bool step = false;
		memio.step();

		// Register in SRAM contents read on previous cycle (matching DQ input registers in FPGA SRAM PHY)
		top.p_sram__dq__in.set<uint16_t>(next_sram_rdata);
		next_sram_rdata = 0;

		// Apply SRAM operation registered into TB PHY model on previous cycle
		if (!next_sram_ce_n && !next_sram_we_n) {
			uint16_t sram_wdata = top.p_sram__dq__out.get<uint16_t>();
			if (!(next_sram_byte_n & 0x1)) {
				memio.mem[next_sram_addr * 2 + 0] = sram_wdata & 0xff;
			}
			if (!(next_sram_byte_n & 0x2)) {
				memio.mem[next_sram_addr * 2 + 1] = sram_wdata >> 8;
			}
		} else if (!next_sram_ce_n && !next_sram_oe_n) {
			next_sram_rdata = memio.mem[2 * next_sram_addr + 0] |
				((uint16_t)memio.mem[2 * next_sram_addr + 1] << 8);
		}

		// Sample SRAM control bus, and read/write memory contents accordingly
		next_sram_oe_n = top.p_sram__oe__n.get<bool>();
		next_sram_we_n = top.p_sram__we__n.get<bool>();
		next_sram_ce_n = top.p_sram__ce__n.get<bool>();
		next_sram_byte_n = top.p_sram__byte__n.get<uint8_t>();
		next_sram_addr = top.p_sram__addr.get<uint32_t>();

		// Handle I/O access
		if (top.p_tbio__psel.get<bool>() && top.p_tbio__penable.get<bool>()) {
			bus_response resp = mem_access(
				memio,
				top.p_tbio__paddr.get<uint16_t>(),
				top.p_tbio__pwrite.get<bool>(),
				top.p_tbio__pwdata.get<uint32_t>()
			);
			top.p_tbio__prdata.set<uint32_t>(resp.rdata);
			top.p_tbio__pslverr.set<bool>(resp.err);
		}

		if (dump_waves) {
			// The extra step() is just here to get the bus responses to line up nicely
			// in the VCD (hopefully is a quick update)
			top.step();
			vcd.sample(cycle * 2 + 1);
			if ((cycle & 0xfff) == 0) {
				waves_fd << vcd.buffer;
				vcd.buffer.clear();
			}
		}

		if (memio.exit_req) {
			printf("CPU requested halt. Exit code %d\n", memio.exit_code);
			printf("Ran for " I64_FMT " cycles\n", cycle + 1);
			break;
		}
		if (cycle + 1 == max_cycles) {
			printf("Max cycles reached\n");
			timed_out = true;
		}
		if (got_exit_cmd)
			break;
	}

	if (dump_waves) {
		waves_fd << vcd.buffer;
		vcd.buffer.clear();
	}

	for (auto r : dump_ranges) {
		printf("Dumping memory from %08x to %08x:\n", r.first, r.second);
		for (int i = 0; i < r.second - r.first; ++i)
			printf("%02x%c", memio.mem[r.first + i], i % 16 == 15 ? '\n' : ' ');
		printf("\n");
	}

	if (propagate_return_code && timed_out) {
		return -1;
	}
	else if (propagate_return_code && memio.exit_req) {
		return memio.exit_code;
	}
	else {
		return 0;
	}
}
