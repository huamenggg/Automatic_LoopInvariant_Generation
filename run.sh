#!/bin/bash
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

DIR_PROJECT=$(pwd)

starttime=$(date +%s)

if [ $# -lt 1 ]; then
	echo "sh run.sh needs more parameters"
	echo "sh run.sh test_file"
	echo "try it again..."
	exit 1
fi

if [ ! -f $1 ]; then
	echo -e $red"The argument is invalid, can not find a config file with name $1"
	exit 1
fi

TEST_FILE=$1
CONFIG_FILE="config.json"
IS_OUTPUT_DETAIL=$(cat $CONFIG_FILE | grep "outputDetail:" | cut -d":" -f 2)
Z3_BUILD_DIR=$(cat $CONFIG_FILE | grep "z3Build:" | cut -d":" -f 2)
INTERACTIVE=$(cat $CONFIG_FILE | grep "interactive:" | cut -d":" -f 2)
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
if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    echo -e -n "Converting the given config file to a cplusplus file..."
else
    echo -e -n "Generating..."
fi
./InitGenData/GenerateCPP.sh $BUILD $TEST_FILE $PREFIX $CONFIG_FILE
if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    echo -e $green"[Done]"$normal
fi

PARAMETER_FILE=$BUILD"/"$PREFIX".parameter"
CPPFILE=$PREFIX".cpp"
EXEFILE=$PREFIX
INIT_DATA=$PREFIX".ds"
if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    echo -e -n "Compile the cplusplus file and get the initial data..."
fi
cd $BUILD
g++ $CPPFILE -o $EXEFILE -lz3 -L$Z3_BUILD_DIR
./$EXEFILE >> $INIT_DATA
if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    echo -e $green"[Done]"$normal
fi
cd $DIR_PROJECT

##########################################################################
# Generate Loop Invariant.
##########################################################################
if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    echo -e $yellow"#######################################################"$normal
    echo -e "Generating Loop Invariant...[Times 1]"
else
    echo -n "..."
fi

if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    ./GenerateInvariant/GenerateInvariant.sh $BUILD $PREFIX $TEST_FILE $CONFIG_FILE
else
    ./GenerateInvariant/GenerateInvariant.sh $BUILD $PREFIX $TEST_FILE $CONFIG_FILE 1>/dev/null 2>&1
fi
if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    echo -e $green"[Done]"$normal
fi
PARAMETERS=($(sed -n '2,$p' $PARAMETER_FILE))
IS_ALL_0=1
for i in "${PARAMETERS[@]}"
do
    if [[ $i != "0.00" && $i != "0" && $i != "-0.00" && $i != "-0" ]]; then
        IS_ALL_0=0
    fi
done
if [ $IS_ALL_0 -eq 1 ]; then
    echo -e $red$bold"Can't generate invariant...you might try again or change the tool"$normal$normal
    exit -1
fi

##########################################################################
# Verify Invariant.
##########################################################################
if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    echo -e "Verifying Invariant..."
    ./VerifyInvariant/VerifyInvariant.sh $BUILD $PREFIX $TEST_FILE $CONFIG_FILE
    VERIFY_RESULT=$?
else
    ./VerifyInvariant/VerifyInvariant.sh $BUILD $PREFIX $TEST_FILE $CONFIG_FILE 1>/dev/null 2>&1
    VERIFY_RESULT=$?
fi
if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
    echo -e $green"[Done]"$normal
fi
if [ $VERIFY_RESULT -eq 0 ]; then
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        echo -e -n "The generated Invariant satisfies hoare triple"
        echo -e $green"[Process Finished]"$normal
    else
        echo ""
    fi
    echo -e $green$bold"------------------------------------------------"$normal$normal
    echo -e -n "The invariant is : "
    OUTPUT_INVARIANT=$(sed -n '1p' $INVARIANT_FILE)
    echo -e $bold"$OUTPUT_INVARIANT"$normal
    echo -e $green"------------------------------------------------"$normal
    endtime=$(date +%s)
    cost_time=$[ $endtime-$starttime ]
    echo -e "Total run time : "$bold$cost_time"s"$normal"  | Total iteration times: "$bold"1"$normal
    exit 0
else
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        echo -e $red$bold"The Invariant can't satisfies hoare triple"$normal$normal
    fi
    #add new border node
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        echo -e "Verifying Invariant..."
        ./VerifyInvariant/AddBorderNode.sh $BUILD $PREFIX
    else
        ./VerifyInvariant/AddBorderNode.sh $BUILD $PREFIX 1>/dev/null 2>&1
    fi
    if [[ $INTERACTIVE -eq 1 ]]; then
        ./VerifyInvariant/UserAddNode.sh $BUILD $PREFIX $TEST_FILE
    fi
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        echo -e $yellow"#######################################################"$normal
    fi
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
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        echo -e "Generating Loop Invariant...[Times $ITERATION]"
    else
        echo -n "..."
    fi
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        ./GenerateInvariant/GenerateInvariant.sh $BUILD $PREFIX $TEST_FILE $CONFIG_FILE
    else
        ./GenerateInvariant/GenerateInvariant.sh $BUILD $PREFIX $TEST_FILE $CONFIG_FILE 1>/dev/null 2>&1
    fi
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        echo -e $green"[Done]"$normal
    fi
    PARAMETERS=($(sed -n '2,$p' $PARAMETER_FILE))
    IS_ALL_0=1
    for i in "${PARAMETERS[@]}"
    do
        if [[ $i != "0.00" && $i != "0" && $i != "-0.00" && $i != "-0" ]]; then
            IS_ALL_0=0
        fi
    done
    if [ $IS_ALL_0 -eq 1 ]; then
        echo -e $red$bold"Can't generate invariant...you might try again or change the tool"$normal$normal
        exit -1
    fi

    ##########################################################################
    # Verify Invariant.
    ##########################################################################
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        echo -e "Verifying Invariant..."
        ./VerifyInvariant/VerifyInvariant.sh $BUILD $PREFIX $TEST_FILE $CONFIG_FILE
        VERIFY_RESULT=$?
    else
        ./VerifyInvariant/VerifyInvariant.sh $BUILD $PREFIX $TEST_FILE $CONFIG_FILE 1>/dev/null 2>&1
        VERIFY_RESULT=$?
    fi
    if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
        echo -e $green"[Done]"$normal
    fi
    if [ $VERIFY_RESULT -eq 0 ]; then
        if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
            echo -e -n "The generated Invariant satisfies hoare triple"
            echo -e $green"[Process Finished]"$normal
        else
            echo ""
        fi
        echo -e $green"------------------------------------------------"$normal
        echo -e -n "The invariant is :"
        OUTPUT_INVARIANT=$(sed -n '1p' $INVARIANT_FILE)
        echo -e $bold"$OUTPUT_INVARIANT"$normal
        echo -e $green"------------------------------------------------"$normal
        endtime=$(date +%s)
        cost_time=$[ $endtime-$starttime ]
        echo -e "Total run time : "$bold$cost_time"s"$normal"  | Total iteration times: "$bold$ITERATION$normal
        exit 0
    else
        if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
            echo -e $red$bold"The Invariant can't satisfies hoare triple"$normal$normal
        fi
        #add new border node
        if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
            echo -e "Verifying Invariant..."
            ./VerifyInvariant/AddBorderNode.sh $BUILD $PREFIX
        else
            ./VerifyInvariant/AddBorderNode.sh $BUILD $PREFIX 1>/dev/null 2>&1
        fi
        if [[ $INTERACTIVE -eq 1 ]]; then
            ./VerifyInvariant/UserAddNode.sh $BUILD $PREFIX $TEST_FILE
        fi
        if [ $IS_OUTPUT_DETAIL -eq 1 ]; then
            echo -e $yellow"#######################################################"$normal
        fi
    fi
    let ITERATION++
done
