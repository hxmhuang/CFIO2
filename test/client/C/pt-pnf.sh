nprocs_max=256
nprocs=16

while [ $nprocs -le $nprocs_max ]; do
    max_itr=5
    itr=0

    while [ $itr -lt $max_itr ]; do
	rm -f nc-out/*

	#outfile=pt-out/out.%J
	outfile=pt-out/out.pnf.$nprocs.$itr
	rm -f $outfile

	bsub -a intelmpi -n $nprocs -o $outfile -e pt-err mpirun.lsf -env I_MPI_EXTRA_FILESYSTEM on -env I_MPI_EXTRA_FILESYSTEM_LIST lustre ./perform_test_pnetcdf $nprocs 1 nc-out 0

	while [ ! -e $outfile ]; do
	    sleep 1
	done

	ls -l -h nc-out
	ncdump nc-out/pnetcdf-9.nc | head 
	grep "proc 0 IO time " $outfile
 	echo ""

	(( itr++ ))
    done

    (( nprocs = nprocs * 2))
done


