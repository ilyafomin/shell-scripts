#!/bin/bash
# This script takes a tab delimited table of numbers and computes rolling averages for each column
# This version is able to process rather fixed-size bins (not windows by numbers of lines) and compute weighed averages 
# It determines automatically number of elements (N) in each row and average between them separately
# Only each Nth average is written out, so that script shrinks the dataset by the factor of N
# Output is CSV
# Download https://github.com/ilyafomin/shell-scripts/blob/master/rollingaverage_example.txt for an example.
# run it as ./rollingaverage.sh rollingaverage_example.txt 
# to send the output to a new file, use ./rollingaverage2.sh rollingaverage_example.txt rollingaverage_output.txt
# (c) Ilya Fomin , 2018

# Averaging window size - to use fixed size one
window=100
# Set these vars to use a certain interval of values from column 1 rather than fixed number of entries
# Note that this is independent from weighed mean or arithmetic mean switch
useinterval=1 #set 1 to use it, 0 for a window
interval=500000.0

# Weighing by the first column values argument
# set 1 to used weighing, 0 for non-weighed arithmetic mean
weighing=1

# check and report filenames to be processed
if [ $# -eq 0 ]
then
  echo "Pass an input file name as an argument."
  exit
fi
filename=$1
echo -e "Input file: \e[1m\e[92m$filename\e[0m"
outputfn=$2
if [ "$outputfn" = "" ]
then
  echo "\e[1m\e[93No output file\e[0m will be written; all the output goes to the console"
else
  echo -e "Output file: \e[1m\e[92m$outputfn\e[0m"
  # flush it contents
  rm $outputfn &> /dev/null
fi

# learn and report number of elements in each row
argnum=$(head -n 1 $filename | wc -w)
echo -e "Found \e[1m\e[91m$argnum\e[0m data columns to be averaged"

# report how many folds do we shrink the dataset
if [ "$useinterval" -eq 1 ]
then
  echo -e "Compute rolling averages for each bin of size \e[1m\e[93m$interval\e[0m in column \e[1m\e[93m1\e[0m"
else
  echo -e "Rolling average window is fixed to \e[1m\e[93m$window\e[0m entries"
fi

# report which argument is used for weighing
if [ "$weighing" -eq 0 ]
then
  echo -e "Computing \e[1m\e[93marithmetic\e[0m mean"
else
  echo -e  "Computing \e[1m\e[93mweighed\e[0m mean"
fi

# init array and make sure it is zeroed
for (( j=1 ; j<=$argnum ; j=j+1 ))
do
  total[$j]=0.0; # this is current step sum
done

j=1 #counter of elements
k=0 #counter of rows
kgl=1 #counter of data frames
totalweight=0.0 #total weight for weighing
weight=0.0 # current value for weighing

# it returns consequentially each element line by line
for i in $( awk '{ print }' $filename )
do
  # it adds the current value to a specific array term and increases index
  if [ "$weighing" -eq 0 -o "$j" -eq 1 ]
  then
    weight=$i #store the weight for another elements in the row, it is used only if $weighing=1
    totalweight=$(echo "scale=5; $weight+$totalweight" | bc | sed 's/^\./0./') #update the total sum for the frame
    total[$j]=$(echo "scale=5; ${total[$j]} + $i" | bc)
  elif [ "$weighing" -gt 0 ]
  then
    total[$j]=$(echo "scale=5; ${total[$j]} + $i*$weight" | bc)
  fi
  # increase the element-in-a-row counter
  (( j++ ))
  #is row finished?
  if [ "$j" -gt "$argnum" ]
  then
    #we are at the end of a row => flush j and increase k
    j=1
    (( k++ ))
  fi
  #should we collect and output stats?
  cmp=$(awk 'BEGIN{ print '$interval'<'$totalweight' }') 
  if [ \( "$k" -eq "$window" -a "$useinterval" -eq 0 \) -o \( "$cmp" -eq 1 -a "$useinterval" -eq 1 -a "$j" -eq 1 \) ]
  then
    #assemble a line for printing
    output=""
    for (( j=1 ; j<=$argnum ; j++ ))
    do
      #get an average
      if [ "$weighing" -eq 1 -a "$j" -ne 1 ]
      then
        # weighed average
        value=$(echo "scale=5; ${total[$j]}/$totalweight" | bc | sed 's/^\./0./')
      else
        # arithmetic mean for k items - that's important to use an interval based window with arithmetic mean
        value=$(echo "scale=5; ${total[$j]}/$k" | bc | sed 's/^\./0./')
      fi
      #add to output line; add comma only if we are not at the end
      output+="$value"
      if [ "$j" -lt "$argnum" ] ; then output+="," ; fi
      #zero the sum
      total[$j]=0.0
    done
    # drop the counter for elements-in-a-row
    j=1
    # drop the counter for elements-in-a-frame
    k=0
    # we are at the end of the data frame - drop the sun m for weighing
    totalweight=0.0
    
    #output
    echo -en "\r --> Writing data frame \e[1m\e[91m$kgl\e[0m ..."
    (( kgl++ ))
    if [ "$outputfn" != "" ]
    then
      echo "$output" >> $outputfn
    else
      echo "$output"
    fi
#    exit
  fi
  
done

# final report
inputsize=$( wc -c $filename | sed 's/[^0-9]*//g' )
if [ "$outputfn" != "" ]
then
  outputsize=$( wc -c $outputfn | sed 's/[^0-9]*//g' )
  echo -en "\nFinished: input of \e[1m\e[91m$inputsize\e[0m bytes shrinked to \e[1m\e[91m$outputsize\e[0m bytes\n"
else
  echo -en "\nFinished: input file containing \e[31m$inputsize\e[0m bytes processed\n"
fi
