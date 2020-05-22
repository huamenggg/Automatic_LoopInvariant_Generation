#!/bin/bash
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
purple="\e[35m"
normal="\e[0m"
bold="\e[1m"

OutputBorderNode() {
    nodeFile=$1
    while read line
    do
        echo -n -e $purple" [$line] "$normal
    done < $nodeFile
    printf "\n"
}

OutputHyperplane() {
    hyperplaneFile=$1
    varFile=$2
    invariantFile=$3
    dataFile=$4
    symbolFile=$5
    if [ -f $invariantFile ]; then
        rm $invariantFile
    fi
    if [ -f $symbolFile ]; then
        rm $symbolFile
    fi
    variables=($(cat $varFile | cut -d"@" -f 2))
    varnum=${#variables[@]}
    b=$(sed -n '1p' $hyperplaneFile)
    parameters=($(sed -n '2,$p' $hyperplaneFile))
    for (( i=0; i<$varnum; i++ ));
    do
        printf "%s * %s + " ${parameters[$i]} "${variables[$i]}" >> $invariantFile
    done
    echo -e -n "$b " >> $invariantFile
    # calculating the symbol of the equation
    ./../../GenerateInvariant/outputHyperplane $hyperplaneFile $dataFile
    symbol=$?
    if [ $symbol -ge 0 ]; then
        echo -e -n ">=" >> $invariantFile
        echo ">=" >> $symbolFile
    else
        echo -e -n "<=" >> $invariantFile
        echo "<=" >> $symbolFile
    fi
    echo -e -n " 0" >> $invariantFile
    invariant=$(sed -n '1p' $invariantFile)
    echo -e $bold"$invariant"$normal
}

if [ $# -lt 4 ]; then
	echo "sh GenerateInvariant.sh needs more parameters"
	echo "sh GenerateInvariant.sh BUILD PREFIX TEST_FILE CONFIG_FILE"
	echo "try it again..."
	exit 1
fi

DIR_PROJECT=$(pwd)
GEN_PROJECT=$DIR_PROJECT"/GenerateInvariant"
BUILD=$1
PREFIX=$2
TEST_FILE=$DIR_PROJECT"/"$3
CONFIG_FILE=$4
Z3_BUILD_DIR=$(cat $CONFIG_FILE | grep "z3Build:" | cut -d":" -f 2)
IF_SELECTIVE=$(cat $CONFIG_FILE | grep "selective:" | cut -d":" -f 2)
SELECTIVE_SAMPLE_NUM=$(cat $CONFIG_FILE | grep "selectiveSampleNum:" | cut -d":" -f 2)
ITERATION_TIMES=$(cat $CONFIG_FILE | grep "maxIterationTimes:" | cut -d":" -f 2)
DATA_FILE=$PREFIX".ds"
TEST_EXIST=$BUILD"/"$DATA_FILE
if [ ! -f $TEST_EXIST ]; then
	echo -e $red$bold"There's something wrong in $TEST_EXIST"$normal$normal
	exit 1
fi

# TODO:Compile operation file, could be replaced by make
# After update the Makefile
###################################################
# cd generate directory
###################################################
cd $GEN_PROJECT
if [ ! -f calcHyperplane ]; then
    g++ CalcHyperplane.cpp -o calcHyperplane
fi
if [ ! -f outputHyperplane ]; then
    g++ OutputHyperplane.cpp -o outputHyperplane
fi
if [ ! -f genPolyVar ]; then
    g++ GenPolyVar.cpp -o genPolyVar
fi
if [ ! -f genPolyData ]; then
    g++ GenPolyData.cpp -o genPolyData
fi
###################################################
# cd project root directory
###################################################
cd $DIR_PROJECT

####################################################
# Generate add border node cpp and compile
####################################################
DEGREE=$(cat $CONFIG_FILE | grep "degree:" | cut -d":" -f 2)
VARIABLES=($(cat $TEST_FILE | grep "names@" | cut -d"@" -f 2))
VARNUM=${#VARIABLES[@]}
TYPES=($(cat $TEST_FILE | grep "types@" | cut -d"@" -f 2))
EXTRACT_CONFIG="InitGenData/ExtractConfig.sh"
ADD_BORDER_CPP=$BUILD"/"$PREFIX"_addBorder.cpp"
ADD_BORDER_HEAD=$GEN_PROJECT"/MainHead"
ADD_BORDER_MEDIUM=$GEN_PROJECT"/MainMedium"
ADD_BORDER_TAIL=$GEN_PROJECT"/MainTail"
./$EXTRACT_CONFIG $BUILD $TEST_FILE $ADD_BORDER_CPP
cat $ADD_BORDER_HEAD >> $ADD_BORDER_CPP

printf "\t\tvector<string> temp;\n" >> $ADD_BORDER_CPP
for (( i=0; i<$VARNUM; i++ ));
do
    printf "\t\ttemp.clear();\n\t\ttemp = Split(res[%s], \":\");\n" $[i + 1] >> $ADD_BORDER_CPP
    if [[ ${TYPES[$i]} == "bool" || ${TYPES[$i]} == "int" ]]; then
        printf "\t\tp->%s = stoi(temp[1]);\n" ${VARIABLES[$i]} >> $ADD_BORDER_CPP
    else
        printf "\t\tp->%s = stod(temp[1]);\n" ${VARIABLES[$i]} >> $ADD_BORDER_CPP
    fi
done
printf "\t\t\toldSet.push_back(*p);\n\t}\n\n" >> $ADD_BORDER_CPP
printf "\twhile(getline(inFile, line)) {\n\t\tvector<string> res = Split(line, \" \");\n\t\tNode *p = new Node;\n\t\t// give Node variable\n" >> $ADD_BORDER_CPP
for (( i=0; i<$VARNUM; i++ ));
do
    if [[ ${TYPES[$i]} == "bool" || ${TYPES[$i]} == "int" ]]; then
        printf "\t\tp->%s = stoi(res[%d]);\n" ${VARIABLES[$i]} $i >> $ADD_BORDER_CPP
    else
        printf "\t\tp->%s = stod(res[%d]);\n" ${VARIABLES[$i]} $i >> $ADD_BORDER_CPP
    fi
done
cat $ADD_BORDER_MEDIUM >> $ADD_BORDER_CPP
# Output variabl number to file
for (( i=0; i<${VARNUM}-1; i++  ));
do
    printf "\t\tcout << \"%d:\" << positiveSet[m_i].%s << \" \";\n" $[i + 1] ${VARIABLES[$i]} >> $ADD_BORDER_CPP
done
printf "\t\tcout << \"%d:\" << positiveSet[m_i].%s << \" \" << endl;\n" ${VARNUM} ${VARIABLES[(( $VARNUM - 1 ))]} >> $ADD_BORDER_CPP

printf "\t}\n\tfor(size_t m_i = 0;m_i < negativeSet.size();m_i++){\n\t\tcout << \"-1 \";\n" >> $ADD_BORDER_CPP
for (( i=0; i<${VARNUM}-1; i++  ));
do
    printf "\t\tcout << \"%d:\" << negativeSet[m_i].%s << \" \";\n" $[i + 1] ${VARIABLES[$i]} >> $ADD_BORDER_CPP
done
printf "\t\tcout << \"%d:\" << negativeSet[m_i].%s << \" \" << endl;\n" ${VARNUM}  ${VARIABLES[(( $VARNUM - 1 ))]} >> $ADD_BORDER_CPP
cat $ADD_BORDER_TAIL >> $ADD_BORDER_CPP

###################################################
# cd Build directory
###################################################
cd $BUILD

ADD_BORDER_CPP=$PREFIX"_addBorder.cpp"
ADD_BORDER_EXE=$PREFIX"_addBorder"
POLY_VAR_FILE=$PREFIX".polyvars"
POLY_DATA_FILE=$PREFIX".polydata"
g++ $ADD_BORDER_CPP -o $ADD_BORDER_EXE

CALC_HYPERPLANE="../../GenerateInvariant/calcHyperplane"
GEN_VARIABLES="../../GenerateInvariant/genPolyVar"
GEN_DATA="../../GenerateInvariant/genPolyData"
SVM_TRAIN="../../libsvm-3.24/svm-train"

###################################################
# Initial Iteration
###################################################
echo -e $yellow"-----------------svm-learner 1-------------------"$normal
echo -e -n "Reflacting data to dimention degree..."
if [ -f $POLY_VAR_FILE ]; then
    rm $POLY_VAR_FILE
fi
if [ -f $POLY_DATA_FILE ]; then
    rm $POLY_DATA_FILE
fi
./$GEN_VARIABLES $TEST_FILE >> $POLY_VAR_FILE
POLY_VAR=($(cat $POLY_VAR_FILE | cut -d"@" -f 2))
POLY_VARNUM=${#POLY_VAR[@]}
./$GEN_DATA $DATA_FILE $DEGREE >> $POLY_DATA_FILE
echo -e $green"[Done]"$normal
echo -e -n "Using libsvm-3.24 to train the model..."
./$SVM_TRAIN -t 0 $POLY_DATA_FILE 1>/dev/null 2>&1
echo -e $green"[Done]"$normal

echo -e -n "Calculating Hyperplane of the model..."
SVM_MODEL=$POLY_DATA_FILE".model"
SVM_PARAMETER=$PREFIX".parameter"
INVARIANT_FILE=$PREFIX".invariant"
SYMBOL_FILE=$PREFIX".symbol"
if [ -f $SVM_PARAMETER ]; then
    rm $SVM_PARAMETER
fi
./$CALC_HYPERPLANE $SVM_MODEL $TEST_FILE >> $SVM_PARAMETER
echo -e $green"[Done]"$normal
echo -n -e "The hyperplane is : "
OutputHyperplane $SVM_PARAMETER $POLY_VAR_FILE $INVARIANT_FILE $POLY_DATA_FILE $SYMBOL_FILE

####################################################
# Generate predict node cpp and compile
####################################################
if [[ $IF_SELECTIVE -eq 1 ]]; then
    echo -e -n "Generating predict cpp file and compile..."
    PREDICT_CPP=$PREFIX"_predict.cpp"
    PREDICT_HEAD=$GEN_PROJECT"/PredictHead"
    B=$(sed -n '1p' $SVM_PARAMETER)
    PARAMETERS=($(sed -n '2,$p' $SVM_PARAMETER))

    if [ -f $PREDICT_CPP ]; then
        rm $PREDICT_CPP
    fi
    cat $PREDICT_HEAD >> $PREDICT_CPP

    #---------------------------------------------
    ## Struct Defination
    #---------------------------------------------
    printf "\nstruct Node{\n" >> $PREDICT_CPP
    for (( i=0; i<$VARNUM; i++  ));
    do
        printf "\t%s %s;\n" ${TYPES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
    done
    printf "};\n\n" >> $PREDICT_CPP
    #---------------------------------------------
    ## Main function
    #---------------------------------------------
    printf "int main() {\n\tz3::context c;\n\n" >> $PREDICT_CPP
    for (( i=0; i<${VARNUM}-1; i++  ));
    do
        if [[ ${TYPES[$i]} == "bool" || ${TYPES[$i]} == "int" ]]; then
            printf "\tz3::expr %s = c.int_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
        else
            printf "\tz3::expr %s = c.real_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
        fi
    done
    ## the last variable needs to be real type for solving
    printf "\tz3::expr %s = c.real_const(\"%s\");\n" ${VARIABLES[(( $VARNUM - 1 ))]} ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP

    ## Add invariant equation
    printf "\n\tz3::solver s(c);\n\n\ts.add(" >> $PREDICT_CPP
    for (( i=0; i<$POLY_VARNUM; i++  ))
    do
        printf "c.real_val(\"%s\") * %s + " ${PARAMETERS[$i]} "${POLY_VAR[$i]}" >> $PREDICT_CPP
    done
    printf "c.real_val(\"%s\") == 0);\n" $B >> $PREDICT_CPP
    ## if contain bool variable, add constraint
    for (( i=0; i<$VARNUM; i++  ));
    do
        if [[ ${TYPES[$i]} == "bool" ]]; then
            printf "\ts.add(%s >= 0 && %s <= 1);\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
        fi
    done
    ## rand initialization
    printf "\n\tstruct timeb timeSeed;\n\tftime(&timeSeed);\n\n\tunsigned mileTime = timeSeed.time * 1000 + timeSeed.millitm;\n\tsrand(mileTime);\n\n\t Node *p = new Node;\n" >> $PREDICT_CPP
    if [ $VARNUM -eq 1 ]; then
        ## if the variable num equal to 1, just solve the equation
        printf "\tswitch(s.check()) {\n\t\tcase z3::unsat: break;\n\t\tcase z3::sat: {\n\t\t\tz3::model m = s.get_model();\n\t\t\tz3::func_decl v = m[0];\n"  >> $PREDICT_CPP
        if [[ ${TYPES[0]} == "bool" || ${TYPES[0]} == "int" ]]; then
            printf "\t\t\tcout << GetIntValue(m.get_const_interp(v).get_decimal_string(10)) << endl;\n" >> $PREDICT_CPP
        else
            printf "\t\t\tcout << GetDoubleValue(m.get_const_interp(v).get_decimal_string(10)) << endl;\n" >> $PREDICT_CPP
        fi
        printf "\t\t\tbreak;\n\t\t}\n\t\tcase z3::unknown: break;\n\t}\n\treturn 0;\n}\n" >> $PREDICT_CPP
    else
        ## else generate config number group sets by random
        printf "\tfor(int m_i = 0;m_i < %s;m_i++) {\n\t\ts.push();\n\t\tint valInt;\n\t\tdouble valDouble;\n\n" $SELECTIVE_SAMPLE_NUM >> $PREDICT_CPP
        ## generate random value of top n-1 variables
        for (( i=0; i<${VARNUM}-1; i++  ));
        do
            if [[ ${TYPES[$i]} == "bool" ]]; then
                printf "\t\tvalInt = (rand() %% 2);\n\t\ts.add(%s == valInt);\n\t\tp->%s = valInt;\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
            elif [[ ${TYPES[$i]} == "int" ]]; then
                printf "\t\tvalInt = (rand() %% 201) - 100;\n\t\ts.add(%s == valInt);\n\t\tp->%s = valInt;\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
            else
                printf "\t\tvalDouble = ((double)rand() / (double)RAND_MAX) * 200 - 100;\n\t\tstring str = Double2String(valDouble);\n\t\tchar const *a = const_cast<char *>(str.c_str());\n\t\ts.add(%s == c.real_val(a));\n\t\tp->%s = valDouble;\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
            fi
        done
        printf "\t\tswitch(s.check()) {\n\t\t\tcase z3::unsat: break;\n\t\t\tcase z3::sat: {\n\t\t\t\tz3::model m = s.get_model();\n\t\t\t\tfor (unsigned m_i = 0;m_i < m.size(); m_i++) {\n\t\t\t\t\tz3::func_decl v = m[m_i];\n\t\t\t\t\tif(v.name().str() == \"%s\") {\n" ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP
        if [[ ${TYPES[(( $VARNUM - 1 ))]} == "bool" || ${TYPES[(( $VARNUM - 1 ))]} == "int" ]]; then
            printf "\t\t\t\t\t\tp->%s = GetIntValue(m.get_const_interp(v).get_decimal_string(10));\n\t\t\t\t\t}\n\t\t\t\t}\n" ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP
        else
            printf "\t\t\t\t\t\tp->%s = GetDoubleValue(m.get_const_interp(v).get_decimal_string(10));\n\t\t\t\t\t}\n\t\t\t\t}\n" ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP
        fi
        printf "\t\t\t\tcout << " >> $PREDICT_CPP
        for (( i=0; i<${VARNUM}-1; i++  ));
        do
            printf "p->%s << \" \" << " ${VARIABLES[$i]} >> $PREDICT_CPP
        done
        printf "p->%s << endl;\n" ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP
        printf "\t\t\t\tbreak;\n\t\t\t}\n\t\t\tcase z3::unknown: break;\n\t\t}\n\t\ts.pop();\n\t}\n\treturn 0;\n}\n" >> $PREDICT_CPP
    fi

    PREDICT_NODE=$PREFIX"_predict"
    if [ -f $PREDICT_NODE ]; then
        rm $PREDICT_NODE
    fi
    g++ $PREDICT_CPP -o $PREDICT_NODE -lz3 -L$Z3_BUILD_DIR
    echo -e $green"[Done]"$normal

    echo -e "Predict border node according to the model..."
    SVM_PREDICT=$PREFIX".predict"
    ./$PREDICT_NODE >> $SVM_PREDICT
    echo -e $green"[Done]"$normal

    SVM_BEFORE=$PREFIX".before"
    SVM_NEWNODE=$PREFIX".newnode"
    echo " " >> $SVM_BEFORE

    ###################################################
    # Generation Interation
    ###################################################
    iterator=2
    diff $SVM_BEFORE $SVM_PARAMETER > /dev/null
    IF_FILE_SAME=$?
    echo -n -e "Checking convergence..."
    if [[ $IF_FILE_SAME == 0 ]]; then
        echo -e $yellow"[True]"$normal
    else
        echo -e $red"[False]"$normal
    fi

    while [[ $IF_FILE_SAME != 0 ]]
    do
        if [ $iterator -ge $ITERATION_TIMES ]; then
            echo -e $red$bold"The iteration times are more than "$ITERATION_TIMES", end the process"$normal$normal
            exit -1
        fi
        cp $SVM_PARAMETER $SVM_BEFORE
        # Add border node into DATA_FILE
        echo -n -e "Adding new border node into data file..."
        ./$ADD_BORDER_EXE $SVM_PREDICT $DATA_FILE >> $SVM_NEWNODE
        OutputBorderNode $SVM_NEWNODE
        cat $SVM_NEWNODE >> $DATA_FILE
        echo -e $green"[Done]"$normal

        # Delete original generated file
        rm $SVM_MODEL
        rm $SVM_PARAMETER
        rm $SVM_PREDICT
        rm $SVM_NEWNODE
        rm $PREDICT_CPP
        rm $PREDICT_NODE
        rm $POLY_DATA_FILE

        # Begin the next iteration
        echo -e $yellow"-----------------svm-learner $iterator-------------------"$normal
        echo -e -n "Reflacting data to dimention degree..."
        ./$GEN_DATA $DATA_FILE $DEGREE >> $POLY_DATA_FILE
        echo -e $green"[Done]"$normal
        echo -e -n "Using libsvm-3.24 to train the model..."
        ./$SVM_TRAIN -t 0 $POLY_DATA_FILE 1>/dev/null 2>&1
        echo -e $green"[Done]"$normal

        echo -e -n "Calculating Hyperplane of the model..."
        ./$CALC_HYPERPLANE $SVM_MODEL $TEST_FILE >> $SVM_PARAMETER
        echo -e $green"[Done]"$normal
        echo -n -e "The hyperplane is : "
        OutputHyperplane $SVM_PARAMETER $POLY_VAR_FILE $INVARIANT_FILE $POLY_DATA_FILE $SYMBOL_FILE

        ####################################################
        # Generate predict node cpp and compile
        ####################################################
        echo -e -n "Generating predict cpp file and compile..."

        B=$(sed -n '1p' $SVM_PARAMETER)
        PARAMETERS=($(sed -n '2,$p' $SVM_PARAMETER))
        cat $PREDICT_HEAD >> $PREDICT_CPP

        #---------------------------------------------
        ## Struct Defination
        #---------------------------------------------
        printf "\nstruct Node{\n" >> $PREDICT_CPP
        for (( i=0; i<$VARNUM; i++  ));
        do
            printf "\t%s %s;\n" ${TYPES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
        done
        printf "};\n\n" >> $PREDICT_CPP
        #---------------------------------------------
        ## Main function
        #---------------------------------------------
        printf "int main() {\n\tz3::context c;\n\n" >> $PREDICT_CPP
        for (( i=0; i<${VARNUM}-1; i++  ));
        do
            if [[ ${TYPES[$i]} == "bool" || ${TYPES[$i]} == "int" ]]; then
                printf "\tz3::expr %s = c.int_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
            else
                printf "\tz3::expr %s = c.real_const(\"%s\");\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
            fi
        done
        ## the last variable needs to be real type for solving
        printf "\tz3::expr %s = c.real_const(\"%s\");\n" ${VARIABLES[(( $VARNUM - 1 ))]} ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP

        ## Add invariant equation
        printf "\n\tz3::solver s(c);\n\n\ts.add(" >> $PREDICT_CPP
        for (( i=0; i<$POLY_VARNUM; i++  ))
        do
            printf "c.real_val(\"%s\") * %s + " ${PARAMETERS[$i]} "${POLY_VAR[$i]}" >> $PREDICT_CPP
        done
        printf "c.real_val(\"%s\") == 0);\n" $B >> $PREDICT_CPP
        ## if contain bool variable, add constraint
        for (( i=0; i<$VARNUM; i++  ));
        do
            if [[ ${TYPES[$i]} == "bool" ]]; then
                printf "\ts.add(%s >= 0 && %s <= 1);\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
            fi
        done
        ## rand initialization
        printf "\n\tstruct timeb timeSeed;\n\tftime(&timeSeed);\n\n\tunsigned mileTime = timeSeed.time * 1000 + timeSeed.millitm;\n\tsrand(mileTime);\n\n\tNode *p = new Node;\n" >> $PREDICT_CPP
        if [ $VARNUM -eq 1 ]; then
            ## if the variable num equal to 1, just solve the equation
            printf "\tswitch(s.check()) {\n\t\tcase z3::unsat: break;\n\t\tcase z3::sat: {\n\t\t\tz3::model m = s.get_model();\n\t\t\tz3::func_decl v = m[0];\n"  >> $PREDICT_CPP
            if [[ ${TYPES[0]} == "bool" || ${TYPES[0]} == "int" ]]; then
                printf "\t\t\tcout << GetIntValue(m.get_const_interp(v).get_decimal_string(10)) << endl;\n" >> $PREDICT_CPP
            else
                printf "\t\t\tcout << GetDoubleValue(m.get_const_interp(v).get_decimal_string(10)) << endl;\n" >> $PREDICT_CPP
            fi
            printf "\t\t\tbreak;\n\t\t}\n\t\tcase z3::unknown: break;\n\t}\n\treturn 0;\n}\n" >> $PREDICT_CPP
        else
            ## else generate config number group sets by random
            printf "\tfor(int m_i = 0; m_i < %s;m_i++) {\n\t\ts.push();\n\t\tint valInt;\n\t\tdouble valDouble;\n\n" $SELECTIVE_SAMPLE_NUM >> $PREDICT_CPP
            ## generate random value of top n-1 variables
            for (( i=0; i<${VARNUM}-1; i++  ));
            do
                if [[ ${TYPES[$i]} == "bool" ]]; then
                    printf "\t\tvalInt = (rand() %% 2);\n\t\ts.add(%s == valInt);\n\t\tp->%s = valInt;\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
                elif [[ ${TYPES[$i]} == "int" ]]; then
                    printf "\t\tvalInt = (rand() %% 201) - 100;\n\t\ts.add(%s == valInt);\n\t\tp->%s = valInt;\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
                else
                    printf "\t\tvalDouble = ((double)rand() / (double)RAND_MAX) * 200 - 100;\n\t\tstring str = Double2String(valDouble);\n\t\tchar const *a = const_cast<char *>(str.c_str());\n\t\ts.add(%s == c.real_val(a));\n\t\tp->%s = valDouble;\n" ${VARIABLES[$i]} ${VARIABLES[$i]} >> $PREDICT_CPP
                fi
            done
            printf "\t\tswitch(s.check()) {\n\t\t\tcase z3::unsat: break;\n\t\t\tcase z3::sat: {\n\t\t\t\tz3::model m = s.get_model();\n\t\t\t\tfor (unsigned m_i = 0;m_i < m.size(); m_i++) {\n\t\t\t\t\tz3::func_decl v = m[m_i];\n\t\t\t\t\tif(v.name().str() == \"%s\") {\n" ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP
            if [[ ${TYPES[(( $VARNUM - 1 ))]} == "bool" || ${TYPES[(( $VARNUM - 1 ))]} == "int" ]]; then
                printf "\t\t\t\t\t\tp->%s = GetIntValue(m.get_const_interp(v).get_decimal_string(10));\n\t\t\t\t\t}\n\t\t\t\t}\n" ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP
            else
                printf "\t\t\t\t\t\tp->%s = GetDoubleValue(m.get_const_interp(v).get_decimal_string(10));\n\t\t\t\t\t}\n\t\t\t\t}\n" ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP
            fi
            printf "\t\t\t\tcout << " >> $PREDICT_CPP
            for (( i=0; i<${VARNUM}-1; i++  ));
            do
                printf "p->%s << \" \" << " ${VARIABLES[$i]} >> $PREDICT_CPP
            done
            printf "p->%s << endl;\n" ${VARIABLES[(( $VARNUM - 1 ))]} >> $PREDICT_CPP
            printf "\t\t\t\tbreak;\n\t\t\t}\n\t\t\tcase z3::unknown: break;\n\t\t}\n\t\ts.pop();\n\t}\n\treturn 0;\n}\n" >> $PREDICT_CPP
        fi

        g++ $PREDICT_CPP -o $PREDICT_NODE -lz3 -L$Z3_BUILD_DIR
        echo -e $green"[Done]"$normal

        echo -e -n "Predict border node according to the model..."
        ./$PREDICT_NODE >> $SVM_PREDICT
        echo -e $green"[Done]"$normal

        let iterator++
        diff $SVM_BEFORE $SVM_PARAMETER > /dev/null
        IF_FILE_SAME=$?
        echo -n -e "Checking convergence..."
        if [[ $IF_FILE_SAME == 0 ]]; then
            echo -e $yellow"[True]"$normal
        else
            echo -e $red"[False]"$normal
        fi
    done
    rm $SVM_BEFORE
fi

###################################################
# cd project root directory
###################################################
cd $DIR_PROJECT
