#!/bin/bash
if [ $# -lt 2 ]; then
	echo "sh GenerateInvariant.sh needs more parameters"
	echo "sh GenerateInvariant.sh $BUILD $PREFIX"
	echo "try it again..."
	exit 1
fi

DIR_PROJECT=$(cd $(dirname BASH_SOURCE[0]) && pwd)
GEN_PROJECT=$DIR_PROJECT"/GenerateInvariant"
BUILD=$1
PREFIX=$2
DATA_FILE=$PREFIX".ds"
TEST_EXIST=$BUILD"/"$DATA_FILE
if [ ! -f $TEST_EXIST ]; then
	echo -e $red"There's something wrong in $TEST_EXIST"
	exit 1
fi

# TODO:Compile operation file, could be replaced by make
# After update the Makefile
cd $GEN_PROJECT
rm calcHyperplane
rm predictNode
g++ CalcHyperplane.cpp -o calcHyperplane
g++ PredictNode.cpp -o predictNode
cd $DIR_PROJECT

CALC_HYPERPLANE="../../GenerateInvariant/calcHyperplane"
PREDICT_NODE="../../GenerateInvariant/predictNode"
SVM_TRAIN="../../libsvm-3.24/svm-train"

cd $BUILD
./$SVM_TRAIN -t 0 $DATA_FILE 1>/dev/null 2>&1

SVM_MODEL=$DATA_FILE".model"
SVM_PARAMETER=$PREFIX".parameter"
./$CALC_HYPERPLANE $SVM_MODEL $SVM_PARAMETER

SVM_PREDICT=$PREFIX".predict"
./$PREDICT_NODE $SVM_PARAMETER $SVM_PREDICT

