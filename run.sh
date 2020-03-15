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

CON_FIGFILE=$1
BUILD=$DIR_PROJECT"/Build"
mkdir -p $BUILD

##########################################################################
# BEGINNING
##########################################################################
echo $blue"Converting the given config file to a cplusplus file..."$normal
sh InitGenData/GenerateCPP.sh $BUILD $CON_FIGFILE
