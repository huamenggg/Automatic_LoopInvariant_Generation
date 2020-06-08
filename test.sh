#!/bin/bash

TESTNUM=20
for (( i=1; i<=$TESTNUM; i++  ));
do
    TESTFILE=`printf "Benchmark/%02d" $i`
    echo "Running $TESTFILE"
    ./run.sh $TESTFILE
done
