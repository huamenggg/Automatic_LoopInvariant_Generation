#!/bin/bash
red="\e[31m"
green="\e[32m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

GetVerify2Result() {
    verifybc=$1
    resultFile=$2
    tempResult=$verifybc".tmp"
    if [ -f $tempResult ]; then
        rm $tempResult
    fi
    klee $verifybc 1>$tempResult 2>&1
    cat $tempResult | grep "KLEE: ERROR:" | grep "klee_assume" 1>/dev/null 2>&1
    if [ $? -eq 0 ]; then
        rm $tempResult
        return 0
    fi
    rm $tempResult
    #Output border data
    kleeData="klee_last/test000001.ktest"
    ktest-tool $kleeData >> $tempResult
    re=($(cat $tempResult | grep " int" | cut -d":" -f 3 | cut -d" " -f2))
    rm $tempResult
    for i in $re
    do
        printf "%s " $i >> $resultFile
    done
}

OutputModelValue() {
    index=$1
    empty=$2
    file=$3
    if [[ ${TYPES[$index]} == "bool" || ${TYPES[$index]} == "int" ]]; then
        echo -e -n $empty >> $file
        printf "p->%s = m.get_const_interp(v).get_numeral_int();\n" ${VARIABLES[$index]} >> $file
    elif [[ ${TYPES[$index]} == "double" ]]; then
        echo -e -n $empty >> $file
        printf "std::string val = m.get_const_interp(v).get_decimal_string(10);\n" >> $file
        echo -e -n $empty >> $file
        printf "if(val[val.size() - 1] == '?') {\n" >> $file
        echo -e -n $empty >> $file
        printf "\tval = val.substr(0, val.size() - 1);\n" >> $file
        echo -e -n $empty >> $file
        printf "}\n" >> $file
        echo -e -n $empty >> $file
        printf "p->%s = stod(val);\n" ${VARIABLES[$index]} >> $file
    else
        echo $red"The config file type is error, needs to be bool, int or double"$normal
        exit 1
    fi
}

DIR_PROJECT=$(pwd)

if [ $# -lt 5 ]; then
	echo "sh VerifyInvariant.sh needs more parameters"
	echo "sh VerifyInvariant.sh build prefix config_file z3_build_dir klee_include"
	echo "try it again..."
	exit 1
fi

if [ ! -f $3 ]; then
	echo -e $red"The argument is invalid, can not find a config file with name $3"
	exit 1
fi

BUILD=$1
PREFIX=$2
CONFIG_FILE=$3
Z3_BUILD_DIR=$4
KLEE_INCLUDE=$5
PARAMETER_FILE=$BUILD"/"$PREFIX".parameter"
SYMBOL_FILE=$BUILD"/"$PREFIX".symbol"
INVARIANT_FILE=$BUILD"/"$PREFIX".invariant"

if [ ! -f $PARAMETER_FILE ]; then
	echo -e $red"The argument is invalid, can not find a file with name $PARAMETER_FILE"
	exit 1
fi
if [ ! -f $SYMBOL_FILE ]; then
	echo -e $red"The argument is invalid, can not find a file with name $SYMBOL_FILE"
	exit 1
fi

VERIFY1=$PREFIX"_verify1.cpp"
VERIFY1EXE=$PREFIX"_verify1"
VERIFY2=$PREFIX"_verify2.c"
VERIFY2BC=$PREFIX"_verify2.bc"
VERIFY3=$PREFIX"_verify3.cpp"
VERIFY3EXE=$PREFIX"_verify3"

B=$(sed -n '1p' $PARAMETER_FILE)
PARAMETERS=($(sed -n '2,$p' $PARAMETER_FILE))
SYMBOL=$(sed -n '1p' $SYMBOL_FILE)
INVARIANT=$(sed -n '1p' $INVARIANT_FILE)
LOOPBEFORE=$(cat $CONFIG_FILE | grep "loopbefore@" | cut -d"@" -f 2)
PRECONDITION=$(cat $CONFIG_FILE | grep "precondition@" | cut -d"@" -f 2)
POSTCONDITION=$(cat $CONFIG_FILE | grep "postcondition@" | cut -d"@" -f 2)
LOOPCONDITION=$(cat $CONFIG_FILE | grep "loopcondition@" | cut -d"@" -f 2)
LOOP=$(cat $CONFIG_FILE | grep "loop@" | cut -d"@" -f 2)
VARIABLES=($(cat $CONFIG_FILE | grep "names@" | cut -d"@" -f 2))
VARNUM=${#VARIABLES[@]}
TYPES=($(cat $CONFIG_FILE | grep "types@" | cut -d"@" -f 2))

##############################################################
# Generate verify z3 cpp file
# cd build directory
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

MAINHEAD="../../VerifyInvariant/MainHead"
MAINMEDIUM="../../VerifyInvariant/MainMedium"
MAINTAIL="../../VerifyInvariant/MainTail"

#Handle head of the verification file
cat $MAINHEAD >> $VERIFY1
for (( i=0; i<$VARNUM; i++  ));
do
    printf "\t%s %s;\n" ${TYPES[$i]} ${VARIABLES[$i]} >> $VERIFY1
done
printf "};\n\n" >> $VERIFY1
#---------------------------------------------
## GiveVarValue function
#---------------------------------------------
printf "void GiveVarValue(Node *p, z3::model m) {\n\tfor(unsigned m_i = 0;m_i < m.size();m_i++) {\n\t\tz3::func_decl v = m[m_i];\n\t\tstd::string name = v.name().str();\n" >> $VERIFY1
printf "\t\tif(name == \"%s\") {\n" ${VARIABLES[0]} >> $VERIFY1
OutputModelValue 0 "\t\t\t" $VERIFY1
printf "\t\t}\n" >> $VERIFY1
for (( i=1; i<$VARNUM; i++  ));
do
    printf "\t\telse if(name == \"%s\") {\n" ${VARIABLES[$i]} >> $VERIFY1
    OutputModelValue $i "\t\t\t" $VERIFY1
    printf "\t\t}\n" >> $VERIFY1
done
printf "\t\telse {\n\t\t\tstd::cerr << \"There's something wrong in GiveVarValue function\" << std::endl;\n\t\t\texit(-1);\n\t\t}\n\t}\n}\n\n" >> $VERIFY1

printf "int main() {\n\tconfig cfg;\n\tcfg.set(\"auto_config\", true);\n\tcontext c(cfg);\n" >> $VERIFY1

cat $VERIFY1 >> $VERIFY3

#Verify1: test if exits pre && !invariant
for (( i=0; i<$VARNUM; i++  ));
do
    if [[ ${TYPES[$i]} == "bool" || ${TYPES[$i]} == "int" ]]; then
        printf "\texpr %s = c.int_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $VERIFY1
    else
        printf "\texpr %s = c.real_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $VERIFY1
    fi
done
printf "\n\tsolver s(c);\n\n" >> $VERIFY1
for (( i=0; i<$VARNUM; i++  ));
do
    if [[ ${TYPES[$i]} == "bool" ]]; then
        printf "\ts.add(%s>=0 && %s<=1);\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $VERIFY1
    fi
done
printf "\t// precondition\n" >> $VERIFY1
printf "\ts.add(%s);\n\n\t// !invariant\n" "$PRECONDITION" >> $VERIFY1
printf "\ts.add(!(" >> $VERIFY1
for (( i=0; i<$VARNUM; i++ ));
do
    echo -n -e "c.real_val(\"${PARAMETERS[$i]}\") * ${VARIABLES[$i]} + " >> $VERIFY1
done
printf "c.real_val(\"%s\") %s 0));\n" $B $SYMBOL >> $VERIFY1
cat $MAINMEDIUM >> $VERIFY1
printf "\t\t\tstd::cout << " >> $VERIFY1
for i in "${VARIABLES[@]}"
do
    printf "p->%s << \" \" << " $i >> $VERIFY1
done
printf "std::endl;\n" >> $VERIFY1
cat $MAINTAIL >> $VERIFY1

#Verify2: using klee test if exits sp(condition && invariant) && !invariant
echo "#include <klee/klee.h>" >> $VERIFY2
echo "#include <stdio.h>" >> $VERIFY2
echo "#include <stdbool.h>" >> $VERIFY2
echo "int main() {" >> $VERIFY2
for (( i=0; i<$VARNUM; i++  ));
do
    printf "\t%s %s;\n" ${TYPES[$i]} ${VARIABLES[$i]} >> $VERIFY2
    printf "\tklee_make_symbolic(&%s, sizeof(%s), \"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} ${VARIABLES[$i]} >> $VERIFY2
done
printf "\tklee_assume(%s);\n" "$LOOPCONDITION" >> $VERIFY2
printf "\tklee_assume(%s);\n" "$INVARIANT" >> $VERIFY2
if [[ $LOOPBEFORE != "" ]]; then
    printf "\t%s\n" "$LOOPBEFORE" >> $VERIFY2
fi
printf "\t%s\n" "$LOOP" >> $VERIFY2
printf "\tklee_assume(!(%s));\n\treturn 0;\n}\n" "$INVARIANT" >> $VERIFY2

#Verify3: test if exits invariant && !condition && !post
for (( i=0; i<$VARNUM; i++  ));
do
    if [[ ${TYPES[$i]} == "bool" || ${TYPES[$i]} == "int" ]]; then
        printf "\texpr %s = c.int_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $VERIFY3
    else
        printf "\texpr %s = c.real_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $VERIFY3
    fi
done
printf "\n\tsolver s(c);\n\n" >> $VERIFY3
for (( i=0; i<$VARNUM; i++  ));
do
    if [[ ${TYPES[$i]} == "bool" ]]; then
        printf "\ts.add(%s>=0 && %s<=1);\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $VERIFY3
    fi
done
printf "\t// invariant\n" >> $VERIFY3
printf "\ts.add(" >> $VERIFY3
for (( i=0; i<$VARNUM; i++ ));
do
    echo -n -e "c.real_val(\"${PARAMETERS[$i]}\") * ${VARIABLES[$i]} + " >> $VERIFY3
done
printf "c.real_val(\"%s\") %s 0);\n" $B $SYMBOL >> $VERIFY3
printf "\n\t// !condition\n\ts.add(!(%s));\n\n\t// !postcondition\n\ts.add(!(%s));\n" "$LOOPCONDITION" "$POSTCONDITION" >> $VERIFY3
cat $MAINMEDIUM >> $VERIFY3
printf "\t\t\tstd::cout << " >> $VERIFY3
for i in "${VARIABLES[@]}"
do
    printf "p->%s << \" \" << " $i >> $VERIFY3
done
printf "std::endl;\n" >> $VERIFY3
cat $MAINTAIL >> $VERIFY3

##############################################################
# Compile and check
##############################################################
if [ -f $VERIFY1EXE ]; then
    rm $VERIFY1EXE
fi
if [ -f $VERIFY2BC ]; then
    rm $VERIFY2BC
fi
if [ -f $VERIFY3EXE ]; then
    rm $VERIFY3EXE
fi
g++ $VERIFY1 -o $VERIFY1EXE -lz3 -L$Z3_BUILD_DIR
clang -I $KLEE_INCLUDE -emit-llvm -c $VERIFY2
g++ $VERIFY3 -o $VERIFY3EXE -lz3 -L$Z3_BUILD_DIR
VERIFY_RESULT_FILE=$PREFIX"_verify.result"
if [ -f $VERIFY_RESULT_FILE ]; then
    rm $VERIFY_RESULT_FILE
fi
./$VERIFY1EXE >> $VERIFY_RESULT_FILE
VERIFY_RESULT=$?
if [ $VERIFY_RESULT -ne 0 ]; then
    echo -e $red$bold"Can't satisfy verify condition 1"$normal$normal
    exit 1
fi

if [ -f $VERIFY_RESULT_FILE ]; then
    rm $VERIFY_RESULT_FILE
fi
GetVerify2Result $VERIFY2BC $VERIFY_RESULT_FILE
VERIFY_RESULT=$?
if [ $VERIFY_RESULT -ne 0 ]; then
    echo -e $red$bold"Can't satisfy verify condition 2"$normal$normal
    exit 1
fi

if [ -f $VERIFY_RESULT_FILE ]; then
    rm $VERIFY_RESULT_FILE
fi
./$VERIFY3EXE >> $VERIFY_RESULT_FILE
VERIFY_RESULT=$?
if [ $VERIFY_RESULT -ne 0 ]; then
    echo -e $red$bold"Can't satisfy verify condition 3"$normal$normal
    exit 1
fi
if [ -f $VERIFY_RESULT_FILE ]; then
    rm $VERIFY_RESULT_FILE
fi

##############################################################
# cd project root kkdirectory
##############################################################
cd $DIR_PROJECT
