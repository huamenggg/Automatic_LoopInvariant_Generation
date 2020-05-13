#!/bin/bash
red="\e[31m"
green="\e[32m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

DIR_PROJECT=$(cd $(dirname $BASH_SOURCE[0]) && pwd)

OutputModelValue() {
    index=$1
    empty=$2
    file=$3
    if [[ ${TYPES[$index]} == "bool" || ${TYPES[$index]} == "int" ]]; then
        echo -e -n $empty >> $file
        printf "p->%s = m.get_const_interp(v).get_numeral_int();\n" ${VARIABLES[$index]} >> $file
    elif [[ ${TYPES[$index]} == "double" ]]; then
        echo -e -n $empty >> $file
        printf "string val = m.get_const_interp(v).get_decimal_string(10);\n" >> $file
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

if [ $# -lt 3 ]; then
    echo -e $red"GenerateCpp.sh needs more parameters"$normal
    echo -e $red"./GenerateCpp.sh build config_file prefix"$normal
    exit 1
fi

BUILD=$1
CONFIG_FILE=$2
PREFIX=$3
CPPFILE=$BUILD"/"$PREFIX".cpp"
HEAD=$DIR_PROJECT"/Head"
EXTRACT="InitGenData/ExtractConfig.sh"
MAINHEAD=$DIR_PROJECT"/MainHead"
MAINMEDIUM=$DIR_PROJECT"/MainMedium"
MAINTAIL=$DIR_PROJECT"/MainTail"
VARIABLES=($(cat $CONFIG_FILE | grep "names@" | cut -d"@" -f 2))
VARNUM=${#VARIABLES[@]}
TYPES=($(cat $CONFIG_FILE | grep "types@" | cut -d"@" -f 2))
PRECONDITION=$(cat $CONFIG_FILE | grep "precondition@" | cut -d"@" -f 2)

#---------------------------------------------
## Extract variables
#---------------------------------------------
VARS_FILE=$BUILD"/"$PREFIX".vars"
if [ -f $VARS_FILE ]; then
    rm $VARS_FILE
fi
printf "vars " >> $VARS_FILE
for i in "${VARIABLES[@]}"
do
    printf "%s " $i >> $VARS_FILE
done
printf "\ntypes " >> $VARS_FILE
for i in "${TYPES[@]}"
do
    printf "%s " $i >> $VARS_FILE
done
printf "\n" >> $VARS_FILE

#---------------------------------------------
## Extract function from config file
#---------------------------------------------
./$EXTRACT $BUILD $CONFIG_FILE $CPPFILE

#---------------------------------------------
## GiveVarValue function
#---------------------------------------------
printf "void GiveVarValue(Node *p, z3::model m) {\n\tfor(unsigned m_i = 0;m_i < m.size();m_i++) {\n\t\tz3::func_decl v = m[m_i];\n\t\tstring name = v.name().str();\n" >> $CPPFILE
printf "\t\tif(name == \"%s\") {\n" ${VARIABLES[0]} >> $CPPFILE
OutputModelValue 0 "\t\t\t" $CPPFILE
printf "\t\t}\n" >> $CPPFILE
for (( i=1; i<$VARNUM; i++  ));
do
    printf "\t\telse if(name == \"%s\") {\n" ${VARIABLES[$i]} >> $CPPFILE
    OutputModelValue $i "\t\t\t" $CPPFILE
    printf "\t\t}\n" >> $CPPFILE
done
printf "\t\telse {\n\t\t\tcerr << \"There's something wrong in GiveVarValue function\" << endl;\n\t\t\texit(-1);\n\t\t}\n\t}\n}\n\n" >> $CPPFILE

#---------------------------------------------
## Cat main function
#---------------------------------------------
cat $MAINHEAD >> $CPPFILE

#---------------------------------------------
# Using SMT to solve the precondition
#---------------------------------------------
for (( i=0; i<$VARNUM; i++  ));
do
    if [[ ${TYPES[$i]} == "bool" || ${TYPES[$i]} == "int" ]]; then
        printf "\tz3::expr %s = c.int_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $CPPFILE
    else
        printf "\tz3::expr %s = c.real_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $CPPFILE
    fi
done
printf "\n\tz3::solver s(c);\n\n" >> $CPPFILE
for (( i=0; i<$VARNUM; i++  ));
do
    if [[ ${TYPES[$i]} == "bool" ]]; then
        printf "\ts.add(%s>=0 && %s<=1);\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $CPPFILE
    fi
done
printf "\t// precondition\n\ts.add(%s);\n\n" "$PRECONDITION" >> $CPPFILE
printf "\tswitch(s.check()) {\n\t\tcase z3::unsat: return -1; break;\n\t\tcase z3::sat: {\n\t\t\tz3::model m = s.get_model();\n\t\t\tNode *p = new Node;\n\t\t\tGiveVarValue(p, m);\n\t\t\tGetPositive(p, positiveSet);\n\t\t\tbreak;\n\t\t}\n\t\tcase z3::unknown: return -1;break;\n\t}\n\n\ts.reset();\n\n" >> $CPPFILE
for (( i=0; i<$VARNUM; i++  ));
do
    if [[ ${TYPES[$i]} == "bool" ]]; then
        printf "\ts.add(%s>=0 && %s<=1);\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $CPPFILE
    fi
done
printf "\t// !precondition\n\ts.add(!(%s));\n\n" "$PRECONDITION" >> $CPPFILE
printf "\tswitch(s.check()) {\n\t\tcase z3::unsat: return -1; break;\n\t\tcase z3::sat: {\n\t\t\tz3::model m = s.get_model();\n\t\t\tNode *p = new Node;\n\t\t\tGiveVarValue(p, m);\n\t\t\tGetNegative(p, negativeSet);\n\t\t\tbreak;\n\t\t}\n\t\tcase z3::unknown: return -1;break;\n\t}\n\n" >> $CPPFILE

#---------------------------------------------
# Using random to add more data
#---------------------------------------------
printf "\tstruct timeb timeSeed;\n\tftime(&timeSeed);\n\tunsigned mileTime = timeSeed.time * 1000 + timeSeed.millitm;\n\tsrand(mileTime);\n" >> $CPPFILE
printf "\n\twhile(positiveSet.empty() || negativeSet.empty()) {\n\t\tNode *p = new Node;\n" >> $CPPFILE

for (( i=0; i<$VARNUM; i++  ));
do
    if [[ ${TYPES[$i]} == "bool" ]]; then
        printf "\t\tp->%s = abs(rand() %% 2);\n" ${VARIABLES[$i]} >> $CPPFILE
    elif [[ ${TYPES[$i]} == "int" ]]; then
        printf "\t\tp->%s = (rand() %% 201) - 100;\n" ${VARIABLES[$i]} >> $CPPFILE
    else
        printf "\t\tp->%s = ((double)rand() / (double)RAND_MAX) * 200 - 100;\n" ${VARIABLES[$i]} >> $CPPFILE
    fi
done
printf "\n" >> $CPPFILE
cat $MAINMEDIUM >> $CPPFILE
for (( i=0; i<${VARNUM}-1; i++  ));
do
    printf "\t\tcout << \"%d:\" << positiveSet[m_i].%s << \" \";\n" $[i + 1] ${VARIABLES[$i]} >> $CPPFILE
done
printf "\t\tcout << \"%d:\" << positiveSet[m_i].%s << \" \" << endl;\n" ${VARNUM} ${VARIABLES[(( $VARNUM - 1 ))]} >> $CPPFILE

printf "\t}\n\tfor(size_t m_i = 0;m_i < negativeSet.size();m_i++){\n\t\tcout << \"-1 \";\n" >> $CPPFILE
for (( i=0; i<${VARNUM}-1; i++  ));
do
    printf "\t\tcout << \"%d:\" << negativeSet[m_i].%s << \" \";\n" $[i + 1] ${VARIABLES[$i]} >> $CPPFILE
done
printf "\t\tcout << \"%d:\" << negativeSet[m_i].%s << \" \" << endl;\n" ${VARNUM}  ${VARIABLES[(( $VARNUM - 1 ))]} >> $CPPFILE
cat $MAINTAIL >> $CPPFILE
