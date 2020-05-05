#!/bin/bash
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

OutputBorerNode() {
    nodeFile=$1
    while read line
    do
        echo -n -e $yellow" [$line] "$normal
    done < $nodeFile
    printf "\n"
}

OutputHyperplane() {
    hyperplaneFile=$1
    configFile=$2
    invariantFile=$3
    dataFile=$4
    symbolFile=$5
    if [ -f $invariantFile ]; then
        rm $invariantFile
    fi
    variables=($(cat $configFile | grep "names@" | cut -d"@" -f 2))
    varnum=${#variables[@]}
    b=$(sed -n '1p' $hyperplaneFile)
    parameters=($(sed -n '2,$p' $hyperplaneFile))
    for (( i=0; i<$varnum; i++ ));
    do
        echo -n -e "${parameters[$i]} * ${variables[$i]} + " >> $invariantFile
    done
    echo -e -n "$b " >> $invariantFile
    # calculating the symbol of the equation
    ./../../GenerateInvariant/outputHyperplane $hyperplaneFile $dataFile
    symbol=$?
    if [ $symbol -ge 0 ]; then
        echo -e -n ">=" >> $invariantFile
        echo -e -n ">=" >> $symbolFile
    else
        echo -e -n "<=" >> $invariantFile
        echo -e -n "<=" >> $symbolFile
    fi
    echo -e -n " 0" >> $invariantFile
    invariant=$(sed -n '1p' $invariantFile)
    echo -e $bold"$invariant"$normal
}

if [ $# -lt 3 ]; then
	echo "sh GenerateInvariant.sh needs more parameters"
	echo "sh GenerateInvariant.sh BUILD PREFIX CONFIG_FILE"
	echo "try it again..."
	exit 1
fi

DIR_PROJECT=$(pwd)
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
###################################################
# cd generate directory
###################################################
cd $GEN_PROJECT
if [ ! -f calcHyperplane ]; then
    g++ CalcHyperplane.cpp -o calcHyperplane
fi
if [ ! -f perdictNode ]; then
    g++ PredictNode.cpp -o predictNode
fi
if [ ! -f outputHyperplane ]; then
    g++ OutputHyperplane.cpp -o outputHyperplane
fi
###################################################
# cd project root directory
###################################################
cd $DIR_PROJECT

####################################################
# Generate config file to cpp and compile
####################################################
EXTRACT_CONFIG="InitGenData/ExtractConfig.sh"
ADD_BORDER_CPP=$BUILD"/"$PREFIX"_addBorder.cpp"
ADD_BORDER_HEAD=$GEN_PROJECT"/MainHead"
ADD_BORDER_MEDIUM=$GEN_PROJECT"/MainMedium"
ADD_BORDER_TAIL=$GEN_PROJECT"/MainTail"
./$EXTRACT_CONFIG $BUILD $CONFIG_FILE $ADD_BORDER_CPP
cat $ADD_BORDER_HEAD >> $ADD_BORDER_CPP
VARIABLES=($(cat $CONFIG_FILE | grep "names@" | cut -d"@" -f 2))
VARNUM=${#VARIABLES[@]}
for (( i=0; i<$VARNUM; i++ ));
do
    printf "\t\tp->%s = stoi(res[%d]);\n" ${VARIABLES[$i]} $i >> $ADD_BORDER_CPP
done
cat $ADD_BORDER_MEDIUM >> $ADD_BORDER_CPP
# Output variabl number to file
for (( i=0; i<${VARNUM}-1; i++  ));
do
    printf "\t\tcout << \"%d:\" << positiveSet[i].%s << \" \";\n" $[i + 1] ${VARIABLES[$i]} >> $ADD_BORDER_CPP
done
printf "\t\tcout << \"%d:\" << positiveSet[i].%s << \" \" << endl;\n" ${VARNUM} ${VARIABLES[(( $VARNUM - 1 ))]} >> $ADD_BORDER_CPP

printf "\t}\n\tfor(size_t i = 0;i < negativeSet.size();i++){\n\t\tcout << \"-1 \";\n" >> $ADD_BORDER_CPP
for (( i=0; i<${VARNUM}-1; i++  ));
do
    printf "\t\tcout << \"%d:\" << negativeSet[i].%s << \" \";\n" $[i + 1] ${VARIABLES[$i]} >> $ADD_BORDER_CPP
done
printf "\t\tcout << \"%d:\" << negativeSet[i].%s << \" \" << endl;\n" ${VARNUM}  ${VARIABLES[(( $VARNUM - 1 ))]} >> $ADD_BORDER_CPP
cat $ADD_BORDER_TAIL >> $ADD_BORDER_CPP

###################################################
# cd Build directory
###################################################
cd $BUILD

ADD_BORDER_EXE=$PREFIX"_addBorder"
g++ $ADD_BORDER_CPP -o $ADD_BORDER_EXE

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
INVARIANT_FILE=$PREFIX".invariant"
./$CALC_HYPERPLANE $SVM_MODEL >> $SVM_PARAMETER
echo -e $green"[Done]"$normal
echo -n -e $yellow"The hyperplane is : "$normal
OutputHyperplane $SVM_PARAMETER $CONFIG_FILE $INVARIANT_FILE $DATA_FILE

echo -e $blue"Predict border node according to the model..."$normal
SVM_PREDICT=$PREFIX".predict"
./$PREDICT_NODE $SVM_PARAMETER >> $SVM_PREDICT
echo -e $green"[Done]"$normal

SVM_BEFORE=$PREFIX".before"
SVM_NEWNODE=$PREFIX".newnode"
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
    if [ $iterator -ge 128 ]; then
        echo $red$bold"The iteration times are more than 128, end the process"$normal$normal
        exit -1
    fi
    cp $SVM_PARAMETER $SVM_BEFORE
    # Add border node into DATA_FILE
    echo -n -e $blue"Adding new border node into data file..."$normal
    ./$ADD_BORDER_EXE $SVM_PREDICT >> $SVM_NEWNODE
    OutputBorerNode $SVM_NEWNODE
    cat $SVM_NEWNODE >> $DATA_FILE
    echo -e $green"[Done]"$normal

    # Delete original generated file
    rm $SVM_MODEL
    rm $SVM_PARAMETER
    rm $SVM_PREDICT
    rm $SVM_NEWNODE

    # Begin the next iteration
    echo -e $red"-----------------svm-learner $iterator-------------------"$normal
    echo -e $blue"Using libsvm-3.24 to train the model..."$normal
    ./$SVM_TRAIN -t 0 $DATA_FILE 1>/dev/null 2>&1
    echo -e $green"[Done]"$normal

    echo -e $blue"Calculating Hyperplane of the model..."$normal
    ./$CALC_HYPERPLANE $SVM_MODEL >> $SVM_PARAMETER
    echo -e $green"[Done]"$normal
    echo -n -e $yellow"The hyperplane is : "$normal
    OutputHyperplane $SVM_PARAMETER $CONFIG_FILE $INVARIANT_FILE $DATA_FILE

    echo -e $blue"Predict border node according to the model..."$normal
    ./$PREDICT_NODE $SVM_PARAMETER >> $SVM_PREDICT
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

###################################################
# cd project root directory
###################################################
cd $DIR_PROJECT
