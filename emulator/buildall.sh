
verilog_sources=""
firrtl_sources=""
binary_files=""
configs="ParendiBig1CoreConfig ParendiBig2CoreConfig ParendiBig4CoreConfig ParendiBig8CoreConfig"
threads="1 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32"

build_sources() {
    for cfg in $configs; do
        echo "*------* building sources of ${cfg} *------*"
        make CONFIG=freechips.rocketchip.system.${cfg} MODEL=SimpleHarness -f SimpleTestDriver.mk -j12  gen_verilog gen_firrtl
        cp generated-src/freechips.rocketchip.system.${cfg}.v generated-src/${cfg}.v
        verilog_sources="${verilog_sources} generated-src/${cfg}.v"
        firrtl_sources="${firrtl_sources} generated-src/freechips.rocketchip.system.${cfg}.fir"
    done
    echo "Archiving source ${verilog_sources}"
    tar -czf verilog_sources.tar.gz ${verilog_sources}
}

build_binaries() {
    echo "Compiling for threads = ${threads}"
    for cfg in $configs; do
        for t in $threads; do
            echo "*------* building sources of essent-${cfg}-${t} *------*"
            make CONFIG=freechips.rocketchip.system.${cfg} MODEL=SimpleHarness -f SimpleTestDriver.mk -j12  THREADS=$t essent_sim
            echo "*------* building sources of verilator-${cfg}-${t} *------*"
            make CONFIG=freechips.rocketchip.system.${cfg} MODEL=SimpleHarness -f SimpleTestDriver.mk -j12  THREADS=$t verilator_sim
            essent_bin=essent-freechips.rocketchip.system-freechips.rocketchip.system.${cfg}-${t}t
            if [ -f $essent_bin ]; then
                binary_files="${binary_files} essent-freechips.rocketchip.system-freechips.rocketchip.system.${cfg}-${t}t"
            else
                echo "--- Warning: $essent_bin not found!"
            fi
            verilator_bin=verilator-freechips.rocketchip.system-freechips.rocketchip.system.${cfg}-${t}t
            if [ -f $verilator_bin ]; then
                binary_files="${binary_files} verilator-freechips.rocketchip.system-freechips.rocketchip.system.${cfg}-${t}t"
            else
                echo "--- Warning: $verilator_bin not found!"
            fi
        done
    done
    echo "Archving binaries ${binary_files}"
    tar -czf binary_files.tar.gz ${binary_files}
}


# build_sources
build_binaries