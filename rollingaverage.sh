#!/bin/bash
# This script takes a tab delimited table of numbers and computes rolling averages for each column
# It determines automatically number of elements (N) in each row and average between them separately
# Only each Nth average is written out, so that script shrinks the dataset by the factor of N
# Output is CSV
# Download https://github.com/ilyafomin/shell-scripts/blob/master/rollingaverage_example.txt for an example.
# run it as ./rollingaverage.sh rollingaverage_example.txt 
# to send the output to a new file, use ./rollingaverage.sh rollingaverage_example.txt rollingaverage_output.txt
# (c) Ilya Fomin , 2018

#Averaging window size
window=10

# check and report filenames to be processed
if [ $# -eq 0 ]
then
  echo "Pass an input file name as an argument."
  exit
fi
filename=$1
echo "Input file: $filename"
outputfn=$2
if [ "$outputfn" = "" ]
then
  echo "No output file will be written; all the output goes to the console"
else
  echo "Output file: $outputfn"
  # flush it contents
  echo "" > $outputfn
fi

# learn and report number of elements in each row
argnum=$(head -n 1 $filename | wc -w)
echo "Found $argnum data columns to be averaged"

# report how many folds do we shrink the dataset
echo "Rolling average window is $window"

# init array and make sure it is zeroed
for (( j=1 ; j<=$argnum ; j=j+1 ))
do
  total[$j]=0.0;
done

j=1 #counter of elements
k=0 #counter of rows

# it returns consequentially each element line by line
for i in $( awk '{ print }' tempdata.txt )
do
  # it adds the current value to a specific array term and increases index
  total[$j]=$(echo "scale=5; ${total[$j]} + $i" | bc)
  (( j++ ))
  #is row finished?
  if [ "$j" -gt "$argnum" ]
  then
    #we are at the end of a row => flush j and increase k
    j=1
    (( k++ ))
  fi
  #should we collect and output stats?
  if [ "$k" -eq "$window" ]
  then
    #we are at the end of a row => flush k
    k=0
    output=""
    for (( j=1 ; j<=$argnum ; j++ ))
    do
      #get an average
      value=$(echo "scale=5; ${total[$j]}/$window" | bc | sed 's/^\./0./')
      #add to output line; add comma only if we are not at the end
      output+="$value"
      if [ "$j" -lt "$argnum" ] ; then output+="," ; fi
      #zero the sum
      total[$j]=0.0;
    done
    j=1 # to rewind the elements in the next row

    #output
    if [ "$outputfn" != "" ]
    then
      echo "$output" >> $outputfn
    else
      echo "$output"
    fi
#    exit
  fi
done
