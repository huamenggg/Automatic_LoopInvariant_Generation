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
CONFIG_FILE=$3
ADD_BORDER_EXE=$PREFIX"_addBorder"
DATA_FILE=$PREFIX".ds"
INVARIANT_FILE=$BUILD"/"$PREFIX".invariant"
NEW_DATA_FILE=$PREFIX".newnode"
USER_INPUT=$PREFIX".userinput"

LOOPBEFORE=$(cat $CONFIG_FILE | grep "loopbefore@" | cut -d"@" -f 2)
PRECONDITION=$(cat $CONFIG_FILE | grep "precondition@" | cut -d"@" -f 2)
POSTCONDITION=$(cat $CONFIG_FILE | grep "postcondition@" | cut -d"@" -f 2)
LOOPCONDITION=$(cat $CONFIG_FILE | grep "loopcondition@" | cut -d"@" -f 2)
LOOP=$(cat $CONFIG_FILE | grep "loop@" | cut -d"@" -f 2)
VARIABLES=($(cat $CONFIG_FILE | grep "names@" | cut -d"@" -f 2))
INVARIANT=$(sed -n '1p' $INVARIANT_FILE)

###################################################
# Output current situation
###################################################
echo -e $yellow$bold"\n\n            [User Input Border Node]             "$normal$normal
echo -e $blue$bold"\n-------------------The hoare is----------------------"$normal$normal
echo -e -n $yellow"[variables]: "$normal
for i in "${VARIABLES[@]}"
do
    printf "%s " $i
done
printf "\n"
echo -e -n $yellow"[precondition]: "$normal
echo -e "$PRECONDITION"
echo -e $yellow"[The loop]"$normal
if [ "$LOOPBEFORE" != "" ]; then
    echo -e "$LOOPBEFORE"
fi
printf "while(%s) {\n" "$LOOPCONDITION"
printf "    %s\n" "$LOOP"
printf "}\n"
echo -e -n $yellow"[postcondition]: "$normal
echo -e "$POSTCONDITION"

echo -e $blue$bold"-----------------The invariant is--------------------"$normal$normal
echo "$INVARIANT"
echo -e $blue$bold"-----------------------------------------------------"$normal$normal
echo -e $yellow$bold"Do you want to mannually add some border node?"$normal$normal
echo -e $yellow$bold"[input $red\"Y\"$yellow to add, input $red\"N\"$yellow or other to ignore]"$normal$normal
read input
if [ "$input" != "Y" ]; then
    exit 0
fi

###################################################
# cd build directory
# user input node
###################################################
cd $BUILD
if [ -f $USER_INPUT ]; then
    rm $USER_INPUT
fi
while [ "$input" == "Y" ];
do
    for i in "${VARIABLES[@]}"
    do
        echo -e $blue$bold"Please input $i"$normal$normal
        read x
        while [ -z $x ];
        do
            echo -e "Need input number"
            read x
        done
        echo -n "$x " >> $USER_INPUT
    done
    printf "\n" >> $USER_INPUT
    echo -e $yellow$bold"Do you want to add more border node?"$normal$normal
    echo -e $yellow$bold"[input $red\"Y\"$yellow to add, input $red\"N\"$yellow or other to ignore]"$normal$normal
    read input
done
cat $USER_INPUT
./$ADD_BORDER_EXE $USER_INPUT >> $NEW_DATA_FILE
echo -n -e $blue"Adding new border node into data file..."$normal
OutputBorderNode $NEW_DATA_FILE
cat $NEW_DATA_FILE >> $DATA_FILE
rm $NEW_DATA_FILE
rm $USER_INPUT
echo -e $green"[Done]"$normal

###################################################
# cd project root directory
###################################################
cd $DIR_PROJECT
