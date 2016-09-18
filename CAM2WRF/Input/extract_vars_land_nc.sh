#!/bin/bash
dir="/misc/data2_eli/abbot/CAM/2001/"
files_str="camrun_branch2.clm2.h0.0062"
tmp_file=$dir"tmp"

list=`echo $dir$files_str*`
for file in $list
do
  echo $file
  ncks -av ZSOI,DZSOI,WATSAT,H2OSOI,SOILICE,SOILLIQ,TG,TSOI $file $tmp_file 
  mv $tmp_file $file
done
