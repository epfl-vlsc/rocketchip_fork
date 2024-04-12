#!/bin/bash
genTask() {
    # sleep 0.5; echo "$1";
    echo "======================== Making firrtl $1 =============================="
    make -f SimpleTestDriver.mk MODEL=SimpleHarness CONFIG=freechips.rocketchip.system.$1 gen_firrtl
    make -f SimpleTestDriver.mk MODEL=SimpleHarness CONFIG=freechips.rocketchip.system.$1 gen_verilog
    # make -f simple.mk CONFIG=chipyard.example.simulation.$1
    echo "=========================== Made firrtl $1 ====================================="
}

buildTask() {
    # sleep 0.5; echo "$1";
    echo "======================== Making binary $1 ${2}t =============================="
    make -f SimpleTestDriver.mk MODEL=SimpleHarness  CONFIG=freechips.rocketchip.system.$1 THREADS=$2 essent_sim verilator_sim -j8
    echo "=========================== Made binary $1 ${2} ====================================="
}
config_list=()

addConfig() {
    config_list+=" $1 "
}

for x in 1 2 4 8 12 16 24 32; do
    addConfig ParendiSmall${x}CoreConfig
    addConfig ParendiBig${x}CoreConfig
done




# initialize a semaphore with a given number of tokens
open_sem(){
    mkfifo pipe-$$
    exec 3<>pipe-$$
    rm pipe-$$
    local i=$1
    for((;i>0;i--)); do
        printf %s 000 >&3
    done
}


# run the given command asynchronously and pop/push tokens
run_with_lock(){
    local x
    # this read waits until there is something to read
    read -u 3 -n 3 x && ((0==x)) || exit $x
    (
     ( "$@"; )
    # push the return code of the command to the semaphore
    printf '%.3d' $? >&3
    )&
}


N=12

# open_sem $N
for cfg in $config_list; do
    genTask $cfg gen_firrtl
done

# for cfg in $config_list; do
#     for t in 1 2 4 6 8 10 12 14 16; do
#         run_with_lock buildTask $cfg $t
#     done
# done
