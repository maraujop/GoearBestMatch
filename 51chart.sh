#!/bin/bash

# Miguel Araujo Pérez www.toThinkOrNotToThink.com
# This script gets all the song titles and artists from the 51 chart of maxima.fm
# The Spanish Dance Radio Station

# Download the file with the 51 chart titles and artists
# file --mime-encoding $chart shows that the index.html is encoded using iso-8859-1
# So we will convert it to standard UTF-8 for not having trouble with locales
chartIso=`tempfile`
# This will be the file in UTF-8
chart=`tempfile`

echo "FINDING 51CHART HIT TITLES AND ARTISTS"
wget -q -O $chartIso http://www.maxima.fm/51Chart/ 
iconv -c -f iso-8859-1 -t utf-8 $chartIso > $chart

# Extract the song titles
songTitles=`tempfile`
cat $chart | egrep -io "<br/><span class=\".*\">.*</span>" | cut -f 3 -d '>' | cut -f 1 -d '<' > $songTitles
numberTitles=`cat $songTitles | wc -l`

# Extract the artists names
songArtists=`tempfile`
cat $chart | egrep -io "<span class=\"normal\">.*</span>" | cut -f 2 -d '>' | cut -f 1 -d '<' > $songArtists
numberArtists=`cat $songArtists | wc -l`

if [ $numberTitles -ne 51 ]
then
   echo "Something went wrong"
   echo "The script didn't find the 51 titles. It only found $numberTitles"
   echo "This is related to the locales or language set"
   echo "Please report this to the author at www.toThinkOrNotToThink.com"
   echo "Do you still want to continue (y/n)?"
   read answer
   if [ $answer = "n" ]
   then
   	  exit 1
   fi
fi

if [ $numberTitles -ne $numberArtists ]
then
   echo "Something went very wrong"
   echo "The number of song titles doesn't match the number of artists"
   echo "Please report this to the author at www.toThinkOrNotToThink.com"
   exit 1
fi

songsDownloaded=0
for i in `seq 1 $numberTitles`
do
   songTitle=`cat $songTitles | head -$i | tail -1`
   songArtist=`cat $songArtists | head -$i | tail -1`
   ./GoearBestMatch.sh -b "$songTitle [] $songArtist"
   result=`echo $?`
   
   if [ $result -eq 0 ]
   then
   	  songsDownloaded=$(($songsDownloaded+1))
   fi
done

notify-send -i gtk-dialog-info "$songsDownloaded songs downloaded"

exit 0
