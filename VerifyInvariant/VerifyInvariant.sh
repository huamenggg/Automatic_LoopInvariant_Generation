#!/bin/bash
red="\e[31m"
green="\e[32m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

DIR_PROJECT=$(pwd)

if [ $# -lt 3 ]; then
	echo "sh VerifyInvariant.sh needs more parameters"
	echo "sh VerifyInvariant.sh build prefix config_file"
	echo "try it again..."
	exit 1
fi

if [ ! -f $3 ]; then
	echo -e $red"The argument is invalid, can not find a config file with name $2"
	exit 1
fi

BUILD=$1
PREFIX=$2
CONFIG_FILE=$3
INVARIANT_FILE=$BUILD"/"$PREFIX".invariant"

if [ ! -f $INVARIANT_FILE ]; then
	echo -e $red"The argument is invalid, can not find a file with name $INVARIANT_FILE"
	exit 1
fi

VERIFY1=$PREFIX"_verify1.c"
VERIFY2=$PREFIX"_verify2.c"
VERIFY3=$PREFIX"_verify3.c"
INVARIANT=$(cat $INVARIANT_FILE)
VARIABLES=($(cat $CONFIG_FILE | grep "names@" | cut -d"@" -f 2))
PRECONDITION=$(cat $CONFIG_FILE | grep "precondition@" | cut -d"@" -f 2)
POSTCONDITION=$(cat $CONFIG_FILE | grep "postcondition@" | cut -d"@" -f 2)
BEFORELOOP=$(cat $CONFIG_FILE | grep "beforeloop@" | cut -d"@" -f 2)
LOOPCONDITION=$(cat $CONFIG_FILE | grep "loopcondition@" | cut -d"@" -f 2)
LOOP=$(cat $CONFIG_FILE | grep "loop@" | cut -d"@" -f 2)
VARNUM=${#VARIABLES[@]}

##############################################################
# Generate verify klee file
##############################################################
cd $BUILD
if [ -f $VERIFY1 ]; then
    rm $VERIFY1
fi
if [ -f $VERIFY2 ]; then
    rm $VERIFY2
fi
if [ -f $VERIFY3 ]; then
    rm $VERIFY3
fi
echo "#include <klee/klee.h>" >> $VERIFY1
echo "#include <klee/klee.h>" >> $VERIFY2
echo "#include <klee/klee.h>" >> $VERIFY3

#Verify1: test if exits pre && !invariant
printf "\nvoid get_flag(" >> $VERIFY1
for i in "${VARIABLES[@]}"
do
    printf "int %s, " $i >> $VERIFY1
done
printf "int flag1) {\n\tif(!(%s)){\n\t\tflag1 = 1;\n\t}\n\telse {\n\t\tflag1 = 0;\n\t}\n}" $INVARIANT >> $VERIFY1
printf "\n\nint main() {\n\tint " >> $VERIFY1
for i in "${VARIABLES[@]}"
do
    printf "%s, " $i >> $VERIFY1
done
printf "flag1;\n" >> $VERIFY1
for i in "${VARIABLES[@]}"
do
    printf "\tklee_make_symbolic(&%s, sizeof(%s), \"%s\");\n" $i $i $i >> $VERIFY1
done
printf "\tklee_make_symbolic(&flag1, sizeof(flag1), \"flag1\");\n" >> $VERIFY1
printf "\tklee_assume( (%s) );\n\tget_flag(" $PRECONDITION >> $VERIFY1
for i in "${VARIABLES[@]}"
do
    printf "%s, " $i >> $VERIFY1
done
printf "flag1);\n\treturn 0;\n}" >> $VERIFY1

#Verify2: test if exits sp(condition && invariant) && !invariant
printf "\nvoid get_flag(" >> $VERIFY2
for i in "${VARIABLES[@]}"
do
    printf "int %s, " $i >> $VERIFY2
done
printf "int flag1) {\n\tif(!(%s)){\n\t\tflag1 = 1;\n\t}\n\telse {\n\t\tflag1 = 0;\n\t}\n}" $INVARIANT >> $VERIFY2
printf "\n\nint main() {\n\tint " >> $VERIFY2
for i in "${VARIABLES[@]}"
do
    printf "%s, " $i >> $VERIFY2
done
printf "flag1;\n" >> $VERIFY2
for i in "${VARIABLES[@]}"
do
    printf "\tklee_make_symbolic(&%s, sizeof(%s), \"%s\");\n" $i $i $i >> $VERIFY2
done
printf "\tklee_make_symbolic(&flag1, sizeof(flag1), \"flag1\");\n" >> $VERIFY2
printf "\tklee_assume( (%s) );\n\tklee_assume( (" $INVARIANT >> $VERIFY2
echo -e -n $LOOPCONDITION >> $VERIFY2
printf ") );\n\tdo {\n\t\t%s\n\t} while(0);\n\n\tget_flag(" $LOOP >> $VERIFY2
for i in "${VARIABLES[@]}"
do
    printf "%s, " $i >> $VERIFY2
done
printf "flag1);\n\treturn 0;\n}" >> $VERIFY2

#Verify3: test if exits invariant && !condition && !post
printf "\nvoid get_flag(" >> $VERIFY3
for i in "${VARIABLES[@]}"
do
    printf "int %s, " $i >> $VERIFY3
done
printf "int flag1) {\n\tif(!(%s)){\n\t\tflag1 = 1;\n\t}\n\telse {\n\t\tflag1 = 0;\n\t}\n}" $POSTCONDITION >> $VERIFY3
printf "\n\nint main() {\n\tint " >> $VERIFY3
for i in "${VARIABLES[@]}"
do
    printf "%s, " $i >> $VERIFY3
done
printf "flag1;\n" >> $VERIFY3
for i in "${VARIABLES[@]}"
do
    printf "\tklee_make_symbolic(&%s, sizeof(%s), \"%s\");\n" $i $i $i >> $VERIFY3
done
printf "\tklee_make_symbolic(&flag1, sizeof(flag1), \"flag1\");\n" >> $VERIFY3
printf "\tklee_assume( (%s) );\n\tklee_assume( !(%s) );\n\n\tget_flag(" $INVARIANT $POSTCONDITION >> $VERIFY3
for i in "${VARIABLES[@]}"
do
    printf "%s, " $i >> $VERIFY3
done
printf "flag1);\n\treturn 0;\n}" >> $VERIFY3

cd $DIR_PROJECT