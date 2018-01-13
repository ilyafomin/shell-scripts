#!/bin/bash
# This script converts a large text file to a table of scaled values.
# It goes through input file and looks for lines containing specific pattern.
# Then is extracts from these lines numeric parameter number N (specified individually 
# for each pattern) and concatenate them into one CSV replaced with an tad-delimited values
# Download https://github.com/ilyafomin/shell-scripts/blob/master/datagrabber_example.txt for an example.
# run it as ./datagrabber.sh datagrabber_example.txt 
# to send the output to a new file, use ./datagrabber.sh datagrabber_example.txt datagrabber_output.txt
# (c) Ilya Fomin , 2018

# Put here patterns you want to look for:
declare -a patterns=('yr ;' 'Total solid' 'Temp (K)')
# Put here indexes (position) for the numeric values you are looking for:
# Note that only space-delimited characters are counted
# e.g. in line " abd = 5 def 6 ghi 7" index for 6 is 5.
# this is messy, but allows to deal with floats and sci notation without complex regexp
# NB: the first value MUST be zero. It does not affect anything.
declare -a indexes=(0 7 6 12)
# Put here multipliers for numeric values:
# in the example, the first one converts years to millions of years, the second does nothing,
# and the third one converts kilotonnes to gigatonnes
# NB: the first value MUST be zero. It does not affect anything.
declare -a multiply=(0 0.000001 0.000001 1)

# check and report filenames to be processed
if [ $# -eq 0 ]
then
  echo "Pass an input file name as an argument."
  exit
fi
filename=$1
echo -e "Input file: \e[32m$filename\e[0m"
outputfn=$2
if [ "$outputfn" = "" ]
then
  echo "No output file will be written; all the output goes to the console"
else
  echo -e "Output file: \e[32m$outputfn\e[0m"
  # flush it contents
  rm $outputfn &> /dev/null
fi

# remove all the old temporary files if there are some
rm datagrabber_tmpouts* &> /dev/null
# counter of entries
k=0
# counter of lines - in case there is an incompleted record, it will be omitted 
l=1

# loop through patterns and write them to temporary outputs
for i in "${patterns[@]}"
do
  #increase counter
  (( k++ ))
 
  echo -e "Looking for pattern [\e[32m$i\e[0m] and index \e[32m${indexes[$k]}\e[0m"
  
  # get lines with required patterns and cut all the non-numerics
  index=${indexes[$k]}
  grep "$i" $filename | awk "{ print \$$index }" | tr -d ',;' > datagrabber_tmpouts_$k.txt

  # get number of lines and min number of lines [i.e. truncate uncompleted output]
  lcur=$(wc -l datagrabber_tmpouts_$k.txt | awk '{ print $1 }')
  if [ "$k" -eq 1 ]
  then
    l=$lcur
  fi
  if [ "$lcur" -lt "$l" ]
  then
    l=$lcur
  fi

done


echo -e "A table with \e[31m$l\e[0m rows and \e[31m$k\e[0m columns is printing ..."

# go through lines to stack values
for (( j=1 ; j<=$l ; j++ ))
do
  # string for output
  output=""
  # go through values over files
  for (( i=1 ; i<=$k ; i++ ))
  do
     # get line with value and get rid of sci notation if any:
     value=$(head -n $j datagrabber_tmpouts_$i.txt | tail -1 | sed 's/[eE][+][0]/*10^/')
     # multiply it by scaling factor
     value=$(echo "scale=10; ${multiply[$i]}*$value" | bc | sed 's/^\./0./')
     output+="$value"
     if [ "$i" -lt "$k" ] ; then output+="," ; fi
  done

  #output
  if [ "$outputfn" != "" ]
  then
    echo "$output" >> $outputfn
  else
    echo "$output"
  fi
done

# replace comma with tabs to make the output compatible with rollingaverage.sh
mv $outputfn datagrabber_tmpouts_0.txt
tr ',' '\t' < datagrabber_tmpouts_0.txt > $outputfn

#clean up
rm datagrabber_tmpouts* &> /dev/null

inputsize=$( wc -c $filename | sed 's/[^0-9]*//g' )
if [ "$outputfn" != "" ]
then
  outputsize=$( wc -c $outputfn | sed 's/[^0-9]*//g' )
  echo -e "Finished: from \e[31m$inputsize\e[0m bytes input file a table with \e[31m$outputsize\e[0m bytes created"
else
  echo -e "Finished: input file containing \e[31m$inputsize\e[0m bytes processed"
fi
