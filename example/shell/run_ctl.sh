#!/bin/bash

WorkDir=$(cd -P $(dirname $BASH_SOURCE) && cd .. && pwd)
source $WorkDir/tools/func.sh

PsName=$WorkDir/tools/run.sh

ctlmain "$@"
