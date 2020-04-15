#!/bin/bash
red="\e[31m"
green="\e[32m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

DIR_PROJECT=$(cd $(dirname $BASH_SOURCE[0]) && pwd)

if [ $# -lt 1 ]; then
	echo "sh run.sh needs more parameters"
	echo "sh run.sh config_file"
	echo "try it again..."
	exit 1
fi

if [ ! -f $1 ]; then
	echo -e $red"The argument is invalid, can not find a config file with name $1"
	exit 1
fi

CONFIG_FILE=$1
PREFIX=`basename -s .cfg $1`
BUILD=$DIR_PROJECT"/Build/"$PREFIX
mkdir -p $BUILD

##########################################################################
# Convert config file to cpp, compile it and generate init data.
##########################################################################
echo -e $blue"Converting the given config file to a cplusplus file..."$normal
./InitGenData/GenerateCPP.sh $BUILD $CONFIG_FILE $PREFIX
echo -e $green"[Done]"$normal

CPPFILE=$PREFIX".cpp"
EXEFILE=$PREFIX
INIT_DATA=$PREFIX".ds"
echo -e $blue"Compile the cplusplus file and get the initial data"$normal
cd $BUILD
g++ $CPPFILE -o $EXEFILE
./$EXEFILE $INIT_DATA
echo -e $green"[Done]"$normal
cd $DIR_PROJECT

##########################################################################
# Generate Loop Invariant.
##########################################################################
echo -e $blue"Generating Loop Invariant..."$normal
./GenerateInvariant/GenerateInvariant.sh $BUILD $PREFIX
echo -e $green"[Done]"$normal
