simulation()
{
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

	LOOP=$MAX_LOOP
	while [ $LOOP -gt 0 ]; do
	    lsfoutfile=pt-out/getput-sendrecv/$out_file_name.$power_ratio.$LOOP
	    lsferrfile=$lsfoutfile.err
	    rm -f $lsfoutfile $lsferrfile

#	    echo "\
#	    mpiexec -n $nprocs -o $lsfoutfile -e $lsferrfile \
#	    ./perform_test $lat_num $lon_num $power_ratio $outpath $ITR $sleep_ms_per_itr $VALN \
#	    "
#	    mpiexec -n $nprocs \
#	    ./perform_test $lat_num $lon_num $power_ratio $outpath $ITR $sleep_ms_per_itr $VALN \
#	    > $lsfoutfile 2> $lsferrfile
#
	    echo "\
	    bsub -q priority -a intelmpi -n $nprocs -o $lsfoutfile -e $lsferrfile \
	    mpirun.lsf -env I_MPI_EXTRA_FILESYSTEM on -env I_MPI_EXTRA_FILESYSTEM_LIST lustre \
	    ./perform_test $lat_num $lon_num $power_ratio $outpath $ITR $sleep_ms_per_itr $VALN 
	    "

	    ret=`\
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

	    MAX_EXCUTE_TIME=200
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

	if [ $odd_or_even -eq 0 ]; then
	    (( lat_num = lat_num / 2 ))
	else
	    (( lon_num = lon_num / 2 ))
	fi
	(( odd_or_even = 1 - odd_or_even ))

	(( RATIO = RATIO - 1 ))
	echo "RATIO $RATIO completed"
    done
}

##########################################################################
# begin
##########################################################################
cfio_dir=/home/hxm/zc/cfio-2
cfio_def=$cfio_dir/src/common/define.h
test_dir=$cfio_dir/test/client/C
cfio_test_def=$test_dir/test_def.h
sed -i "s/.*#define SVR_UNPACK_ONLY/#define SVR_UNPACK_ONLY/g" $cfio_def
sed -i "s/.*#define SLEEP_TIME.*/#define SLEEP_TIME 1/g" $cfio_test_def
cp /home/hxm/zc/expr/src/comm-ratio.perform_test.c $test_dir/perform_test.c

PROCS_PER_NODE=12

outpath=nc-out
ITR=23 # simulation iterations
sleep_ms_per_itr=2000
VALN=1

SERVER_NUM=16

##########################################################################
# RDMA WRITE addr
##########################################################################
run_getput=1 
if [ $run_getput -eq 1 ]; then
    sed -i "s!.*#define SEND_ADDR!//#define SEND_ADDR!g" $cfio_def
    cd $cfio_dir
    echo "make clean & make"
    make clean > temp
    make >> temp
    cd $test_dir

    lat_num=16
    lon_num=16

    RATIO=5
    MAX_LOOP=2

    out_file_name="getput"

    simulation 
fi

##########################################################################
# RDMA SEND RECV addr
##########################################################################
run_sendrecv=1 
if [ $run_sendrecv -eq 1 ]; then
    sed -i "s/.*#define SEND_ADDR/#define SEND_ADDR/g" $cfio_def
    sed -i "s!.*#define REGISTER_ON_THE_FLY!//#define REGISTER_ON_THE_FLY!g" $cfio_def
    cd $cfio_dir
    echo "make clean & make"
    make clean > temp
    make >> temp
    cd $test_dir

    lat_num=16
    lon_num=16

    RATIO=5
    MAX_LOOP=2

    out_file_name="sendrecv"

    simulation 
fi

##########################################################################
# RDMA SEND RECV addr, register on the fly
##########################################################################
onthefly=1 
if [ $onthefly -eq 1 ]; then
    sed -i "s/.*#define SEND_ADDR/#define SEND_ADDR/g" $cfio_def
    sed -i "s/.*#define REGISTER_ON_THE_FLY/#define REGISTER_ON_THE_FLY/g" $cfio_def
    cd $cfio_dir
    echo "make clean & make"
    make clean > temp
    make >> temp
    cd $test_dir

    lat_num=16
    lon_num=16

    RATIO=5
    MAX_LOOP=2

    out_file_name="onthefly"

    simulation 
fi
