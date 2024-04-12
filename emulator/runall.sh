
binary_file=/scratch/emami/graphcore/ipu_eval/workloads/src/chipyard-common/bench/dhrystone/dhrystone_2000.hex
max_cycles=5000000
sim_args="+binary=$binary_file +max-cycles=$max_cycles"
echo "simulation arguments: $sim_args"
for cfg in ParendiBig1CoreConfig ParendiBig2CoreConfig ParendiBig4CoreConfig; do
    for t in 1 2 4 8; do
        suffix=freechips.rocketchip.system-freechips.rocketchip.system.$cfg-${t}t
        verilator_cmd=verilator-${suffix}
        numactl -C0-$(($t - 1)) ./$verilator_cmd $sim_args | tee verilator-${suffix}.txt
        essent_cmd=essent-${suffix}
        # numactl -C0-$(($t - 1)) ./$essent_cmd $sim_args | tee essent-${suffix}.txt
    done
done