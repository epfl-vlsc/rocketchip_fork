#include <chrono>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>
#include <cstring>
#include ESSENT_MODEL

struct CommonImpl {
  template <typename Bundle>
  static void combeval(const Bundle& bundle, bool &wen_old, uint64_t &addr_old,
                       uint64_t &wdata_old, uint64_t &wstrb_old) {
#ifdef NO_THREADS
    wen_old = bundle.srams.mem.wen.as_single_word();
    addr_old = bundle.srams.mem.addr.as_single_word();
    wstrb_old = bundle.srams.mem.wstrb.as_single_word();
    wdata_old = bundle.srams.mem.wdata.as_single_word();
#else
    wen_old = bundle.wen.as_single_word();
    addr_old = bundle.addr.as_single_word();
    wstrb_old = bundle.wstrb.as_single_word();
    wdata_old = bundle.wdata.as_single_word();
#endif
  }

  // template <typename Bundle>
  // static void combeval(Bundle *bundle, bool &wen_old, uint64_t &addr_old,
  //                      uint64_t &wdata_old, uint64_t &wstrb_old) {
  //   wen_old = bundle->wen.as_single_word();
  //   addr_old = bundle->addr.as_single_word();
  //   wstrb_old = bundle->wstrb.as_single_word();
  //   wdata_old = bundle->wdata.as_single_word();
  // }
  static void writeWord(std::vector<uint64_t> &storage, uint64_t wstrb_old,
                        uint64_t addr_old, uint64_t wdata_old) {
    for (int i = 0; i < 8; i++) {
      bool ben = (wstrb_old >> i) & 1u;
      if (ben) {
        uint64_t mask = 0x00ffull << static_cast<uint64_t>(8 * i);
        if (addr_old < storage.size()) {
          // uint64_t reverseMask = ~(0x00ffull << static_cast<uint64_t>(8 *
          // i));
          // std::cout << "mask " << std::hex << mask << "->"
          //           << wdata_old << " ";
          storage[addr_old] &= ~mask;
          storage[addr_old] |= (mask & wdata_old);
        }
        // std::cout << " => " << storage[addr_old] << std::endl;
      }
    }
  }
};
struct ToHostSnooper {
  std::vector<uint64_t> storage;
  ToHostSnooper() : storage(128, 0){};
  bool wen_old;
  uint64_t addr_old;
  uint64_t wdata_old;
  uint64_t wstrb_old;

  void combeval(SimpleHarness *dut) {

    CommonImpl::combeval(
#ifdef NO_THREADS
      dut->mmio,
#else
      dut->mmio_srams_mem,
#endif
      wen_old, addr_old, wdata_old, wstrb_old);
  }

  void tick(SimpleHarness *dut, int cycleCount, bool &finish, bool &stop) {
    if (wen_old) {
      CommonImpl::writeWord(storage, wstrb_old, addr_old, wdata_old);
    }
    if (wen_old && (wstrb_old & 0xf) == 0xf && addr_old == 0) {
      if (wdata_old & 0x1 && (wdata_old >> 1ull) == 0) {
        std::cout << "@" << cycleCount << ": Test passed" << std::endl;
        finish = true;
        return;
      } else if (wdata_old & 0x1 && (wdata_old >> 1ull) != 0) {
        std::cout << "@" << cycleCount << ": Test failed with toHost "
                  << wdata_old << std::endl;
        stop = true;
        return;
      } else if ((wdata_old & 0x1) == 0) {
        // syscall emulation
        if ((wdata_old >> 1ull) == 64) {
          // SYS_WRITE
          const char *buff = reinterpret_cast<const char *>(storage.data() + 1);
          for (int i = 0; i < 64; i++) {
            if (buff[i]==0)
              break;
            std::cout << buff[i];
          }

        } else {
          std::cout << "@" << cycleCount << " unknown system call " << std::hex
                    << (wdata_old >> 1ull) << std::dec << std::endl;
          stop = true;
          return;
        }
      }
    }
  }
};
struct HexMem {

  std::vector<uint64_t> storage;
  int addr_q;
  bool wen_old = false;
  uint64_t addr_old;
  uint64_t wdata_old;
  uint64_t wstrb_old = 0;
  HexMem() : storage(1 << 14, 0) {}
  void loadHex(const std::string &filename) {
    std::ifstream ifs(filename, std::ios::in);
    int i = 0;
    if (!ifs) {
      std::cerr << "Could not load hex file" << std::endl;
      std::exit(-1);
    }
    while (!ifs.eof()) {
      std::string line;
      ifs >> line;
      if (line.empty())
        break;
      std::stringstream ss;
      ss << "0x" << line;
      ss >> std::hex >> storage[i++];
    }
  }
  void combeval(SimpleHarness *dut) {
    CommonImpl::combeval(
#ifdef NO_THREADS
      dut->mem,
#else
      dut->mem_srams_mem,
#endif
      wen_old, addr_old, wdata_old, wstrb_old);
  }
  void tick(SimpleHarness *dut) {
    if (wen_old) {
      CommonImpl::writeWord(storage, wstrb_old, addr_old, wdata_old);
    }
    // std::cout << "Read 0x" << std::hex << hi << "_" << std::hex << lo  << "
    // " << std::hex << "storage[" << addr_old << "] = " << storage[addr_old]
    // << std::endl;
#ifdef NO_THREADS
    dut->mem.srams.mem.rdata = UInt<64>(storage[addr_old]);
#else
    dut->mem_srams_mem.rdata = UInt<64>(storage[addr_old]);
#endif
  }
};

struct CliOpt {

  bool verbose = false;
  std::string binaryFileName = "";
  uint64_t maxCycles = 1000;
  void parse(int argc, char *argv[]) {
    int argIndex = 1;
    for (int argIndex = 1; argIndex < argc; argIndex++) {
      std::string key = argv[argIndex];
      if (key.substr(0, 8) == "+binary=") {
        binaryFileName = key.substr(8);
      } else if (key.substr(0, 12) == "+max-cycles=") {
        maxCycles = std::stoi(key.substr(12));
      } else if (key == "+verbose") {
        verbose = true;
      } else {
        std::cerr << "Invalid argument '" << key << "'" << std::endl;
        std::exit(-1);
      }
    }
    if (binaryFileName.empty()) {
      std::cerr << "+binary= is required" << std::endl;
      std::exit(-1);
    }
  }
};
int main(int argc, char *argv[]) {

  // parse arguments
  CliOpt opts;
  opts.parse(argc, argv);
  // memory model
  std::unique_ptr<HexMem> memModel(new HexMem);
  memModel->loadHex(opts.binaryFileName);

  std::unique_ptr<ToHostSnooper> snooper(new ToHostSnooper);

  std::unique_ptr<SimpleHarness> dut(new SimpleHarness);
  // #ifdef ESSENT_TRACE
  // dut->genWaveHeader();
  // #endif

  auto start = std::chrono::high_resolution_clock::now();

  dut->reset = UInt<1>(1);
  int cycleCount = 0;
  for (int i = 0; i < 11; i++) {
    dut->eval(true, opts.verbose, false);
    cycleCount++;
  }
  bool finish = false;
  bool stop = false;
  dut->reset = UInt<1>(0);

  while (cycleCount < opts.maxCycles && !stop && !finish) {
    dut->eval(false, opts.verbose, true);
    memModel->combeval(dut.get());
    snooper->combeval(dut.get());
    dut->eval(true, opts.verbose, true);
    memModel->tick(dut.get());
    snooper->tick(dut.get(), cycleCount, finish, stop);
    cycleCount++;
  }
  auto end = std::chrono::high_resolution_clock::now();
  auto duration = std::chrono::duration<double>(end - start).count();
  auto ratekHz = static_cast<double>(cycleCount) / duration / 1000.0;
  printf("Finished after %d cycles in %.3f seconds (%.3f)\n", cycleCount,
         duration, ratekHz);
  return stop;
}
