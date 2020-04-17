#!/bin/bash
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

OutputHyperplane() {
    hyperplaneFile=$1
    configFile=$2
    variables=($(cat $configFile | grep "names@" | cut -d"@" -f 2))
    varnum=${#variables[@]}
    b=$(sed -n '1p' $hyperplaneFile)
    parameters=($(sed -n '2,$p' $hyperplaneFile))
    for (( i=0; i<$varnum; i++ ));
    do
        echo -n -e $bold"${parameters[$i]} * ${variables[$i]} + "$normal
    done
    echo -e $bold"$b = 0"$normal
}

if [ $# -lt 3 ]; then
	echo "sh GenerateInvariant.sh needs more parameters"
	echo "sh GenerateInvariant.sh $BUILD $PREFIX"
	echo "try it again..."
	exit 1
fi

DIR_PROJECT=$(cd $(dirname BASH_SOURCE[0]) && pwd)
GEN_PROJECT=$DIR_PROJECT"/GenerateInvariant"
BUILD=$1
PREFIX=$2
CONFIG_FILE=$DIR_PROJECT"/"$3
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

EXTRACT_CONFIG="InitGenData/ExtractConfig.sh"
ADD_BORDER_CPP=$BUILD"/"$PREFIX"_addBorder.cpp"
#./EXTRACT_CONFIG $BUILD $CONFIG_FILE $ADD_BORDER_CPP

cd $BUILD

CALC_HYPERPLANE="../../GenerateInvariant/calcHyperplane"
PREDICT_NODE="../../GenerateInvariant/predictNode"
SVM_TRAIN="../../libsvm-3.24/svm-train"

###################################################
# Initial Iteration
###################################################
echo -e $red"-----------------svm-learner 1-------------------"$normal
echo -e $blue"Using libsvm-3.24 to train the model..."$normal
./$SVM_TRAIN -t 0 $DATA_FILE 1>/dev/null 2>&1
echo -e $green"[Done]"$normal

echo -e $blue"Calculating Hyperplane of the model..."$normal
SVM_MODEL=$DATA_FILE".model"
SVM_PARAMETER=$PREFIX".parameter"
./$CALC_HYPERPLANE $SVM_MODEL $SVM_PARAMETER
echo -e $green"[Done]"$normal
echo -n -e $yellow"The hyperplane is : "$normal
OutputHyperplane $SVM_PARAMETER $CONFIG_FILE

echo -e $blue"Predict border node according to the model..."$normal
SVM_PREDICT=$PREFIX".predict"
./$PREDICT_NODE $SVM_PARAMETER $SVM_PREDICT
echo -e $green"[Done]"$normal

SVM_BEFORE=$PREFIX".before"
echo " " >> $SVM_BEFORE

###################################################
# Generation Interation
###################################################
iterator=2
diff $SVM_BEFORE $SVM_PARAMETER > /dev/null
IF_FILE_SAME=$?
echo -n -e $blue"Checking convergence..."$normal
if [[ $IF_FILE_SAME == 0 ]]; then
    echo -e $yellow"[True]"$normal
else
    echo -e $yellow"[False]"$normal
fi

while [[ $IF_FILE_SAME != 0 ]]
do
    cp $SVM_PARAMETER $SVM_BEFORE
    # Add border node into DATA_FILE

    # Delete original generated file
    rm $SVM_MODEL
    rm $SVM_PARAMETER
    rm $SVM_PREDICT

    # Begin the next iteration
    echo -e $red"-----------------svm-learner $iterator-------------------"$normal
    echo -e $blue"Using libsvm-3.24 to train the model..."$normal
    ./$SVM_TRAIN -t 0 $DATA_FILE 1>/dev/null 2>&1
    echo -e $green"[Done]"$normal

    echo -e $blue"Calculating Hyperplane of the model..."$normal
    ./$CALC_HYPERPLANE $SVM_MODEL $SVM_PARAMETER
    echo -e $green"[Done]"$normal
    echo -n -e $yellow"The hyperplane is : "$normal
    OutputHyperplane $SVM_PARAMETER $CONFIG_FILE

    echo -e $blue"Predict border node according to the model..."$normal
    ./$PREDICT_NODE $SVM_PARAMETER $SVM_PREDICT
    echo -e $green"[Done]"$normal
    let iterator++
    diff $SVM_BEFORE $SVM_PARAMETER > /dev/null
    IF_FILE_SAME=$?
    echo -n -e $blue"Checking convergence..."$normal
    if [[ $IF_FILE_SAME == 0 ]]; then
        echo -e $yellow"[True]"$normal
    else
        echo -e $yellow"[False]"$normal
    fi

done
