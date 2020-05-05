#!/bin/bash
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

DIR_PROJECT=$(cd $(dirname $BASH_SOURCE[0]) && pwd)

if [ $# -lt 2 ]; then
	echo "sh run.sh needs more parameters"
	echo "sh run.sh config_file klee_include_path"
	echo "try it again..."
	exit 1
fi

if [ ! -f $1 ]; then
	echo -e $red"The argument is invalid, can not find a config file with name $1"
	exit 1
fi

CONFIG_FILE=$1
KLEE_INCLUDE=$2
PREFIX=`basename -s .cfg $1`
BUILD=$DIR_PROJECT"/Build/"$PREFIX
INVARIANT_FILE=$BUILD"/"$PREFIX".invariant"
if [ -d $BUILD ]; then
    rm $BUILD -rf
fi
mkdir -p $BUILD

##########################################################################
# Convert config file to cpp, compile it and generate init data.
##########################################################################
echo -e $blue$bold$bold"Converting the given config file to a cplusplus file..."$normal$normal
./InitGenData/GenerateCPP.sh $BUILD $CONFIG_FILE $PREFIX
echo -e $green"[Done]"$normal

CPPFILE=$PREFIX".cpp"
EXEFILE=$PREFIX
INIT_DATA=$PREFIX".ds"
echo -e $blue$bold"Compile the cplusplus file and get the initial data"$normal$normal
cd $BUILD
g++ $CPPFILE -o $EXEFILE
./$EXEFILE >> $INIT_DATA
echo -e $green"[Done]"$normal
cd $DIR_PROJECT

##########################################################################
# Generate Loop Invariant.
##########################################################################
echo "#######################################################"
echo -e $blue$bold"Generating Loop Invariant...[Times 1]"$normal$normal
./GenerateInvariant/GenerateInvariant.sh $BUILD $PREFIX $CONFIG_FILE
echo -e $green"[Done]"$normal

##########################################################################
# Verify Invariant.
##########################################################################
echo -e $blue$bold"Verifying Invariant..."$normal$normal
./VerifyInvariant/VerifyInvariant.sh $BUILD $PREFIX $CONFIG_FILE $KLEE_INCLUDE
VERIFY_RESULT=$?
echo -e $green"[Done]"$normal
if [ $VERIFY_RESULT -eq 0 ]; then
    echo -e $blue$bold"The generated Invariant satisfies hoare triple"$normal$normal
    echo -e $gree"[Process Finished]"$normal
    echo -e $yellow"------------------------------------------------"$normal
    echo -e -n $yellow"The invariant is : "$normal
    cat $INVARIANT_FILE
    echo ""
    echo -e $yellow"------------------------------------------------"$normal
    exit 0
else
    echo -e $red$bold"The Invariant can't satisfies hoare triple"$normal$normal
    echo -e $blue$bold"Adding new border node into data file..."$normal$normal
    #add new border node
    echo "#######################################################"
fi

ITERATION=2
while [ $VERIFY_RESULT -ne 0 ]
do
    if [ $ITERATION -ge 128 ]; then
        echo $red$bold"The iteration times are more than 128, end the process"$normal$normal
        exit -1
    fi
    ##########################################################################
    # Generate Loop Invariant.
    ##########################################################################
    echo -e $blue$bold"Generating Loop Invariant...[Times $ITERATION]"$normal$normal
    ./GenerateInvariant/GenerateInvariant.sh $BUILD $PREFIX $CONFIG_FILE
    echo -e $green"[Done]"$normal

    ##########################################################################
    # Verify Invariant.
    ##########################################################################
    echo -e $blue$bold"Verifying Invariant..."$normal$normal
    ./VerifyInvariant/VerifyInvariant.sh $BUILD $PREFIX $CONFIG_FILE $KLEE_INCLUDE
    VERIFY_RESULT=$?
    echo -e $green"[Done]"$normal
    if [ $VERIFY_RESULT -eq 0 ]; then
        echo -e $blue$bold"The generated Invariant satisfies hoare triple"$normal$normal
        echo -e $gree"[Process Finished]"$normal
        echo -e $yellow"------------------------------------------------"$normal
        echo -e -n $yellow"The invariant is :"$normal
        cat $INVARIANT_FILE
        echo ""
        echo -e $yellow"------------------------------------------------"$normal
        exit 0
    else
        echo -e $red$bold"The Invariant can't satisfies hoare triple"$normal$normal
        echo -e $blue$bold"Adding new border node into data file..."$normal$normal
        #add new border node
        echo "#######################################################"
    fi
    let ITERATION++
done
