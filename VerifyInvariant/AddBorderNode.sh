#!/bin/bash
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

OutputBorderNode() {
    nodeFile=$1
    while read line
    do
        echo -n -e $yellow" [$line] "$normal
    done < $nodeFile
    printf "\n"
}

if [ $# -lt 2 ]; then
	echo "sh AddBorderNode.sh needs more parameters"
	echo "sh AddBorderNode.sh BUILD PREFIX"
	echo "try it again..."
	exit 1
fi

DIR_PROJECT=$(pwd)
BUILD=$1
PREFIX=$2
ADD_BORDER_EXE=$PREFIX"_addBorder"
DATA_FILE=$PREFIX".ds"
NEW_DATA_FILE=$PREFIX".newnode"
VERIFY_RESULT=$PREFIX"_verify.result"

###################################################
# cd build directory
###################################################
cd $BUILD
./$ADD_BORDER_EXE $VERIFY_RESULT >> $NEW_DATA_FILE
echo -n -e $blue"Adding new border node into data file..."$normal
OutputBorderNode $NEW_DATA_FILE
cat $NEW_DATA_FILE >> $DATA_FILE
rm $NEW_DATA_FILE
echo -e $green"[Done]"$normal

###################################################
# cd project root directory
###################################################
cd $DIR_PROJECT
