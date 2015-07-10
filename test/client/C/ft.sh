#bsub -a intelmpi -o out -e err -n 18 mpirun.lsf ./func_test
mpirun -n 10 ./func_test

#i=1
#while [ "$i" -lt 50 ]
#do
#    echo ""
#    echo ""
#    echo "$i"
#    let "i = $i + 1"
#    echo ""
#    echo ""
#    mpirun -n 10 ./func_test 
#done
#
