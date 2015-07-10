repeat()
{
    LOOP=$MAX_LOOP
    while [ $LOOP -gt 0 ]; do
	lsfoutfile=$out_file_name.$power_ratio.$LOOP
	lsferrfile=$lsfoutfile.err
	rm -f $lsfoutfile $lsferrfile

#	echo "
#	mpiexec -n $nprocs \
#	./perform_test $lat_num $lon_num $power_ratio $outpath $ITR $sleep_ms_per_itr $VALN \
#	> $lsfoutfile 2> $lsferrfile \
#	"
#
#	mpiexec -n $nprocs \
#	./perform_test $lat_num $lon_num $power_ratio $outpath $ITR $sleep_ms_per_itr $VALN \
#	> $lsfoutfile 2> $lsferrfile 

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
	    sleep 10
	done
	echo "job $jobid is running."

	MAX_EXCUTE_TIME=120
	while [ ! -e $lsfoutfile -a ! -e $lsferrfile ]; do
	    sleep 1
	    (( MAX_EXCUTE_TIME -= 1 ))
	    if [ $MAX_EXCUTE_TIME -eq 0 ]; then
		bkill -r $jobid
		break
	    fi
	done

	rm -f $lsferrfile
	(( LOOP = LOOP - 1 ))
    done
}

##########################################################################
# begin
##########################################################################
rdma_dir=/home/hxm/zc/cfio-src
rdma_test_dir=$rdma_dir/test/client/C
rdma_def=$rdma_dir/src/common/define.h
rdma_test_def=$rdma_dir/test/client/C/test_def.h
sed -i "s!.*#define SVR_UNPACK_ONLY!#define SVR_UNPACK_ONLY!g" $rdma_def
sed -i "s!.*#define SEND_ADDR!//#define SEND_ADDR!g" $rdma_def
sed -i "s!.*#define SLEEP_TIME .*!#define SLEEP_TIME 0!g" $rdma_test_def

cfio_dir=/home/hxm/zc/cfio-1
cfio_test_dir=$cfio_dir/test/client/C
cfio_def=$cfio_dir/src/common/define.h
cfio_test_def=$rdma_dir/test/client/C/test_def.h
sed -i "s/.*#define SVR_UNPACK_ONLY/#define SVR_UNPACK_ONLY/g" $cfio_def
sed -i "s!.*#define SLEEP_TIME .*!#define SLEEP_TIME 0!g" $cfio_test_def

cd $rdma_dir
echo "make clean & make"
make clean > temp
make >> temp

cd $cfio_dir
echo "make clean & make"
#make clean > temp
#make >> temp

PROCS_PER_NODE=12

outpath=nc-out
ITR=23 # simulation iterations
sleep_ms_per_itr=2000
VALN=25

SERVER_NUM=16

lat_num=16
lon_num=16

RATIO=1
MAX_LOOP=1

odd_or_even=0

while [ $RATIO -gt 0 ]; do
    (( client_num = lat_num * lon_num ))
    (( power_ratio = client_num / SERVER_NUM ))

    (( nprocs = client_num + SERVER_NUM ))
    ((nodes = nprocs / PROCS_PER_NODE))
    ((remainder_procs = nprocs % PROCS_PER_NODE))
    if [ $remainder_procs -ne 0 ]; then
	(( nodes++ ))
    fi
    (( nprocs = PROCS_PER_NODE * nodes ))

    cd $rdma_test_dir
    out_file_name="pt-out/comm-ratio/comm-ratio-rdma"
    repeat # call function

    cd $cfio_test_dir
    out_file_name="pt-out/comm-ratio/comm-ratio-cfio"
    # repeat # call function

    if [ $odd_or_even -eq 0 ]; then
	(( lat_num /= 2 ))
    else
	(( lon_num /= 2 ))
    fi
    (( odd_or_even = 1 - odd_or_even ))

    (( RATIO = RATIO - 1 ))
    echo "server $SERVER_NUM client $client_num"
done
