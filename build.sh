#!/bin/bash
cmd="$1"

if [ "$cmd" != "clean" ];then
  mkdir -p output
else
  rm -rf output
fi
for dir in $(ls); do
  if [ ! -d $dir ] || [ "$dir" == "output" ] || [ "$dir" == "share" ];then
    continue
  fi
  echo $dir
  make -C $dir $cmd
  mv $dir/output output/$dir
done
if [ -d output/share ];then
  mv output/share output/services
fi
