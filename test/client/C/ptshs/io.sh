repeat()
{
    LOOP=$MAX_LOOP
    while [ $LOOP -gt 0 ]; do
	lsfoutfile=$out_file_name.$power_ratio.$LOOP
	lsferrfile=$lsfoutfile.err
	rm -f $lsfoutfile $lsferrfile
	rm -rf nc-out/*

	echo "bsub -q priority -a intelmpi -n $nprocs -o $lsfoutfile -e $lsferrfile \
	mpirun.lsf -env I_MPI_EXTRA_FILESYSTEM on -env I_MPI_EXTRA_FILESYSTEM_LIST lustre \
	./perform_test $lat_num $lon_num $power_ratio $outpath $ITR $sleep_ms_per_itr $VALN"

	ret=` \
	bsub -q priority -a intelmpi -n $nprocs -o $lsfoutfile -e $lsferrfile \
	mpirun.lsf -env I_MPI_EXTRA_FILESYSTEM on -env I_MPI_EXTRA_FILESYSTEM_LIST lustre \
	./perform_test $lat_num $lon_num $power_ratio $outpath $ITR $sleep_ms_per_itr $VALN 
	`
	echo $ret
	jobid=`echo $ret | grep Job | sed "s/>.*//g" | sed "s/^.*<//g"`

	while [ `bjobs $jobid | grep RUN | wc -l` -ne 1 ]; do
	    sleep 1
	done
	echo "job $jobid is running."

	MAX_EXCUTE_TIME=900
	while [ ! -e $lsfoutfile -a ! -e $lsferrfile ]; do
	    sleep 1
	    (( MAX_EXCUTE_TIME -= 1 ))
	    if [ $MAX_EXCUTE_TIME -eq 0 ]; then
		bkill -r $jobid
		break
	    fi
	done

#	rm -f $lsferrfile
	(( LOOP = LOOP - 1 ))
    done
}

repeat_pnf()
{
    LOOP=$MAX_LOOP
    while [ $LOOP -gt 0 ]; do
	lsfoutfile=$out_file_name.$server_num.$LOOP
	lsferrfile=$lsfoutfile.err
	rm -f $lsfoutfile $lsferrfile
	rm -rf nc-out/*

	((extra = nprocs - server_num))

	echo "bsub -q priority -a intelmpi -n $nprocs -o $lsfoutfile -e $lsferrfile \
	mpirun.lsf -env I_MPI_EXTRA_FILESYSTEM on -env I_MPI_EXTRA_FILESYSTEM_LIST lustre \
	./perform_test_pnetcdf $server_num 1 $outpath $extra $sleep_ms_per_itr " 

	ret=` \
	bsub -q priority -a intelmpi -n $nprocs -o $lsfoutfile -e $lsferrfile \
	mpirun.lsf -env I_MPI_EXTRA_FILESYSTEM on -env I_MPI_EXTRA_FILESYSTEM_LIST lustre \
	./perform_test_pnetcdf $server_num 1 $outpath $extra $sleep_ms_per_itr  
	`
	echo $ret
	jobid=`echo $ret | grep Job | sed "s/>.*//g" | sed "s/^.*<//g"`

	while [ `bjobs $jobid | grep RUN | wc -l` -ne 1 ]; do
	    sleep 1
	done
	echo "job $jobid is running."

	MAX_EXCUTE_TIME=900
	while [ ! -e $lsfoutfile -a ! -e $lsferrfile ]; do
	    sleep 1
	    (( MAX_EXCUTE_TIME -= 1 ))
	    if [ $MAX_EXCUTE_TIME -eq 0 ]; then
		bkill -r $jobid
		break
	    fi
	done

#	rm -f $lsferrfile
	(( LOOP = LOOP - 1 ))
    done
}

##########################################################################
# begin
##########################################################################

# CFIO-2
rdma_dir=/home/hxm/zc/cfio-2
rdma_test_dir=$rdma_dir/test/client/C
rdma_def=$rdma_dir/src/common/define.h
rdma_test_def=$rdma_dir/test/client/C/test_def.h
sed -i "s!.*#define SVR_UNPACK_ONLY!//#define SVR_UNPACK_ONLY!g" $rdma_def
sed -i "s!.*#define SEND_ADDR!//#define SEND_ADDR!g" $rdma_def
sed -i "s!.*#define SLEEP_TIME .*!#define SLEEP_TIME 0!g" $rdma_test_def
cp /home/hxm/zc/expr/src/io.perform_test.c $rdma_test_dir/perform_test.c
cp /home/hxm/zc/expr/src/io.perform_test_pnetcdf.c $rdma_test_dir/perform_test_pnetcdf.c

# CFIO
cfio_dir=/home/hxm/zc/cfio-1
cfio_test_dir=$cfio_dir/test/client/C
cfio_def=$cfio_dir/src/common/define.h
cfio_test_def=$cfio_dir/test/client/C/test_def.h
sed -i "s!.*#define SVR_UNPACK_ONLY!//#define SVR_UNPACK_ONLY!g" $cfio_def
sed -i "s!.*#define SLEEP_TIME .*!#define SLEEP_TIME 0!g" $cfio_test_def
cp /home/hxm/zc/expr/src/io.perform_test.c $cfio_test_dir/perform_test.c

cd $rdma_dir
echo "make clean & make"
make clean > temp
make >> temp

cd $cfio_dir
echo "make clean & make"
make clean > temp
make >> temp

PROCS_PER_NODE=12

outpath=nc-out
ITR=20 # simulation iterations
sleep_ms_per_itr=2000
VALN=25

server_num=256

lat_num=16
lon_num=16

RATIO=6
MAX_LOOP=2

while [ $RATIO -gt 0 ]; do
    (( client_num = lat_num * lon_num ))
    (( power_ratio = client_num / server_num ))

    (( nprocs = client_num + server_num ))
    ((nodes = nprocs / PROCS_PER_NODE))
    ((remainder_procs = nprocs % PROCS_PER_NODE))
    if [ $remainder_procs -ne 0 ]; then
	(( nodes++ ))
    fi
    (( nprocs = PROCS_PER_NODE * nodes ))

    run_rdma=0
    if [ $run_rdma -eq 1 ]; then
	cd $rdma_test_dir
	out_file_name="pt-out/io/io-rdma"
	repeat # call function
    fi

    run_cfio=0
    if [ $run_cfio -eq 1 ]; then
	cd $cfio_test_dir
	out_file_name="pt-out/io/io-cfio"
	repeat # call function
    fi

    run_pnetcdf=1
    if [ $run_pnetcdf -eq 1 ]; then
	(( nprocs = server_num ))
	((nodes = nprocs / PROCS_PER_NODE))
	((remainder_procs = nprocs % PROCS_PER_NODE))
	if [ $remainder_procs -ne 0 ]; then
	    (( nodes++ ))
	fi
	(( nprocs = PROCS_PER_NODE * nodes ))

	cd $rdma_test_dir
	out_file_name="pt-out/io-pnf/io-pnf"
	repeat_pnf # call function
    fi

    (( server_num /= 2 ))

    (( RATIO = RATIO - 1 ))
    echo "server $server_num client $client_num"
done
