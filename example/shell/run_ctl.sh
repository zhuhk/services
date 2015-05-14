#!/bin/bash

WorkDir=$(cd $(dirname $BASH_SOURCE) && cd .. && pwd)
source $WorkDir/tools/func.sh

PsName=$WorkDir/tools/run.sh

ctlmain "$@"
