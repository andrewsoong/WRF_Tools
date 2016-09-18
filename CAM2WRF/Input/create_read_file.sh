#!/bin/bash


#dir="/misc/data2_eli/abbot/CAM/2001/"
dir="/home/yy/CAM3/"
#files_str="camrun_branch2.cam2.h0.0062"
#files_str="camrun_branch2.cam2.h0.0062-01-31"
files_str="camrun.cam2.h1.0000"

out_file='CAM2WRF.input'

rm -f $out_file

list=`echo $dir$files_str*`
for file in $list
do
  file2=${file:0:21}'clm2'${file:25}

  sec=${file:40:5}
  hr=`awk -v sec=$sec 'BEGIN{printf("%.2d\n",sec/3600.)}'`
  date='0000'${file:33:6}'_'$hr':00:00'
  
  echo \"$file\"' '\"$file2\"' '\"$date\" >> $out_file

done
