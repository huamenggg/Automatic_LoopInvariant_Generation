#!/bin/bash
red="\e[31m"
green="\e[32m"
blue="\e[34m"
normal="\e[0m"
bold="\e[1m"

DIR_PROJECT=$(cd $(dirname $BASH_SOURCE[0]) && pwd)

if [ $# -lt 3 ]; then
    echo -e $red"GenerateCpp.sh needs more parameters"$normal
    echo -e $red"./GenerateCpp.sh build config_file prefix"$normal
    exit 1
fi

BUILD=$1
TEST_FILE=$2
CPPFILE=$3
HEAD=$DIR_PROJECT"/Head"
VARIABLES=($(cat $TEST_FILE | grep "names@" | cut -d"@" -f 2))
TYPES=($(cat $TEST_FILE | grep "types@" | cut -d"@" -f 2))
VARNUM=${#VARIABLES[@]}
TYPESNUM=${#TYPES[@]}

if [ $VARNUM -ne $TYPESNUM ]; then
    echo $red"The config file error : type number is not equal to var numver." $normal
    exit -1
fi

if [ -f $CPPFILE ]; then
    rm $CPPFILE
fi

cat $HEAD >> $CPPFILE

#---------------------------------------------
## Struct Defination
#---------------------------------------------
printf "\nstruct Node{\n" >> $CPPFILE
for (( i=0; i<$VARNUM; i++  ));
do
    printf "\t%s %s;\n" ${TYPES[$i]} ${VARIABLES[$i]} >> $CPPFILE
done
printf "\tbool operator == (const Node &e){\n\t\t return " >> $CPPFILE
for (( i=0; i<${VARNUM}-1; i++  ));
do
    printf "(this->%s == e.%s) && " ${VARIABLES[$i]} ${VARIABLES[$i]} >> $CPPFILE
done
printf "(this->%s == e.%s);\n\t}\n};\n\n" ${VARIABLES[(( $VARNUM - 1 ))]} ${VARIABLES[(( $VARNUM - 1 ))]} >> $CPPFILE

#---------------------------------------------
## Test PreCondition function
#---------------------------------------------
##TODO: if variables are more than one
printf "int TestIfSatisfyPre(Node* aNode) {\n" >> $CPPFILE
for (( i=0; i<$VARNUM; i++  ));
do
    printf "\t%s %s = aNode->%s;\n" ${TYPES[$i]} ${VARIABLES[$i]} ${VARIABLES[$i]} >> $CPPFILE
done
printf "\n\tif(" >> $CPPFILE
PRECONDITION=$(cat $TEST_FILE | grep "precondition@" | cut -d"@" -f 2)
printf %s "$PRECONDITION" >> $CPPFILE
printf ") return 1;\n\treturn -1;\n}\n\n" >> $CPPFILE

#---------------------------------------------
## Test PostCondition function
#---------------------------------------------
##TODO: if variables are more than one
printf "int TestIfSatisfyPost(Node* aNode) {\n" >> $CPPFILE
for (( i=0; i<$VARNUM; i++  ));
do
    printf "\t%s %s = aNode->%s;\n" ${TYPES[$i]} ${VARIABLES[$i]} ${VARIABLES[$i]} >> $CPPFILE
done
printf "\n\tif(" >> $CPPFILE
POSTCONDITION=$(cat $TEST_FILE | grep "postcondition@" | cut -d"@" -f 2)
printf %s "$POSTCONDITION" >> $CPPFILE
printf ") return 1;\n\treturn -1;\n}\n\n" >> $CPPFILE

#---------------------------------------------
## Execute the loop
#---------------------------------------------
printf "Node* DoWhile(Node *aNode, vector<Node>& aSet) {\n" >> $CPPFILE
for (( i=0; i<$VARNUM; i++  ));
do
    printf "\t%s %s = aNode->%s;\n" ${TYPES[$i]} ${VARIABLES[$i]} ${VARIABLES[$i]} >> $CPPFILE
done
BEFORELOOP=$(cat $TEST_FILE | grep "loopbefore@" | cut -d"@" -f 2)
if [[ $BEFORELOOP != "" ]]; then
    printf "\t%s\n" "$BEFORELOOP" >> $CPPFILE
fi
printf "\n\tNode *_p;\n\twhile(" >> $CPPFILE
LOOPCONDITION=$(cat $TEST_FILE | grep "loopcondition@" | cut -d"@" -f 2)
printf "%s" "$LOOPCONDITION" >> $CPPFILE
printf "){\n\t\t" >> $CPPFILE
LOOP=$(cat $TEST_FILE | grep "loop@" | cut -d"@" -f 2)
echo "$LOOP" >> $CPPFILE
printf "\n\t\t_p = new Node;\n" >> $CPPFILE
for i in "${VARIABLES[@]}"
do
    printf "\t\t_p->%s = %s;\n" $i $i >> $CPPFILE
done
printf "\n\t\tvector<Node>::iterator it = find(aSet.begin(), aSet.end(), *_p);\n\t\tif(it == aSet.end()) {\n\t\t\taSet.push_back(*_p);\n\t\t}\n\t}\n" >> $CPPFILE
printf "\t_p = new Node;\n" >> $CPPFILE
for i in "${VARIABLES[@]}"
do
    printf "\t_p->%s = %s;\n" $i $i >> $CPPFILE
done
printf "\treturn _p;\n}\n\n" >> $CPPFILE

#---------------------------------------------
## Generate positive example
#---------------------------------------------
printf "void GetPositive(Node *aNode, vector<Node>& aPositive) {\n\tint begin = aPositive.size();\n\taPositive.push_back(*aNode);\n\n" >> $CPPFILE
printf "\tNode *p = DoWhile(aNode, aPositive);\n" >> $CPPFILE
printf "\tif(TestIfSatisfyPost(p) == -1) {\n\t\taPositive.erase(aPositive.begin() + begin, aPositive.end());\n\t}\n}\n\n" >> $CPPFILE

#---------------------------------------------
## Generate negative example
#---------------------------------------------
printf "void GetNegative(Node* aNode, vector<Node>& aNegative) {\n\tint begin = aNegative.size();\n\taNegative.push_back(*aNode);\n\n" >> $CPPFILE
printf "\tNode *p = DoWhile(aNode, aNegative);\n" >> $CPPFILE
printf "\tif(TestIfSatisfyPost(p) == 1) {\n\t\taNegative.erase(aNegative.begin() + begin, aNegative.end());\n\t}\n}\n\n" >> $CPPFILE
