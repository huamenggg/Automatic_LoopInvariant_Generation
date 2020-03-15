#!/bin/bash
red="\e[31m"
green="\e[32m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

DIR_PROJECT=$(cd $(dirname $BASH_SOURCE[0]) && pwd)

if [ $# -lt 2 ]; then
	echo "GenerateCPP needs more parameters"
	echo "sh GenerateCPP.sh build_dir config_file"
	echo "try it again..."
	exit 1
fi

BUILD=$1
CONFIG_FILE=$2

CPPFILE=$BUILD"/InitGen.cpp"
INIT_DIR=$DIR_PROJECT"/InitGenData"
HEAD=$INIT_DIR"/Head"
MAIN=$INIT_DIR"/Main"

if [ -f $1 ]; then
    rm $CPPFILE
fi

cat $HEAD >> $CPPFILE

## Test PreCondition function
##TODO: if variables are more than one
printf "\nint TestIfSatisfyPre(int aData) {\n\tint " >> $CPPFILE
VARIABLE=$(cat $CONFIG_FILE | grep "names@" | cut -d"@" -f 2 )
printf %s $VARIABLE >> $CPPFILE
printf " = aData;\n\tif(" >> $CPPFILE
PRECONDITION=$(cat $CONFIG_FILE | grep "precondition@" | cut -d"@" -f 2)
printf %s $PRECONDITION >> $CPPFILE
printf ") return 1;\n\treturn -1;\n}\n\n" >> $CPPFILE

## Test PostCondition function
##TODO: if variables are more than one
printf "int TestIfSatisfyPost(int aData) {\n\tint " >> $CPPFILE
printf %s $VARIABLE >> $CPPFILE
printf " = aData;\n\tif(" >> $CPPFILE
POSTCONDITION=$(cat $CONFIG_FILE | grep "postcondition@" | cut -d"@" -f 2)
printf %s $POSTCONDITION >> $CPPFILE
printf ") return 1;\n\treturn -1;\n}\n\n" >> $CPPFILE

## Generate positive example
printf "void GetPositive(int aData, vector<int>& aPositive) {\n\tint begin = aPositive.size();\n\taPositive.push_back(aData);\n\n\tint " >> $CPPFILE
printf %s $VARIABLE >> $CPPFILE
printf " = aData;\n\n\twhile(" >> $CPPFILE
LOOPCONDITION=$(cat $CONFIG_FILE | grep "loopcondition@" | cut -d"@" -f 2)
printf %s $LOOPCONDITION >> $CPPFILE
printf "){\n\t\t" >> $CPPFILE
LOOP=$(cat $CONFIG_FILE | grep "loop@" | cut -d"@" -f 2)
printf %s $LOOP >> $CPPFILE
printf "\n\t\tvector<int>::iterator it = find(aPositive.begin(), aPositive.end(), x);\n\t\tif(it == aPositive.end()) {\n\t\t\taPositive.push_back(x);\n\t\t}\n\t}\n\n" >> $CPPFILE

printf "\tif(TestIfSatisfyPost(" >> $CPPFILE
printf %s $VARIABLE >> $CPPFILE
printf ") == -1) {\n\t\taPositive.erase(aPositive.begin() + begin, aPositive.end());\n\t}\n}\n\n" >> $CPPFILE

## Generate negative example
printf "void GetNegative(int aData, vector<int>& aNegative) {\n\tint begin = aNegative.size();\n\taNegative.push_back(aData);\n\n\tint " >> $CPPFILE
printf %s $VARIABLE >> $CPPFILE
printf " = aData;\n\n\twhile(" >> $CPPFILE
printf %s $LOOPCONDITION >> $CPPFILE
printf "){\n\t\t" >> $CPPFILE
printf %s $LOOP >> $CPPFILE
printf "\n\t\tvector<int>::iterator it = find(aNegative.begin(), aNegative.end(), x);\n\t\tif(it == aNegative.end()) {\n\t\t\taNegative.push_back(x);\n\t\t}\n\t}\n\n" >> $CPPFILE

printf "\tif(TestIfSatisfyPost(" >> $CPPFILE
printf %s $VARIABLE >> $CPPFILE
printf ") == 1) {\n\t\taNegative.erase(aNegative.begin() + begin, aNegative.end());\n\t}\n}\n\n" >> $CPPFILE

## Cat main function
cat $MAIN >> $CPPFILE
