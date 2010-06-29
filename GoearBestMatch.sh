#!/bin/bash 
# ./GoearBestMatch.sh [-n songTitle [] Artist | -b songTitle [] Artist]

# GoearBestMatch at Github
# Miguel Araujo Pérez www.toThinkOrNotToThink.com
# This script downloads best search result from Goear
# from searching a song name and artist

# TODO
# Edit ID3 tags
# Equalize volume of all songs
# Use random User-agent and referrer
# Limit wget bandwidth 

usage()
{
   cat << EOF
   usage: $0 options "songTitle [] Artist"

   Downloads a song from Goear.com trying to find the best match

   OPTIONS:
      -h      Shows script help
      -b      Searches for the songtitle and artist together.
      -n      Searches for the songtitle and uses the artist to improve matching
              Recommended if -b fails at finding a match
EOF
}

trimmer() {
    # Remove symbols
	new=`echo $@ | tr --delete . | sed "s/-/ /g" | sed "s/,/ /g" | sed "s/\&//g" | sed "s/\;/ /g" | sed "s/(//g" | sed "s/)//g"`
	
	# Convert blank spaces to white spaces, being careful with single quotes
	new=`echo $new | sed 's/\[\]/ /' | awk '{for(i=1; i<=NF; i++) print $i}' | xargs -0`
    
	# Removes unwanted characters or converts letters with accents to regular letters
	echo $new | sed 's/^[ ]*//' | sed 's/á/a/g' | sed 's/é/e/g' |sed 's/í/i/g' |sed 's/ó/o/g' |sed 's/ú/u/g' \
	| sed 's/à/a/g' | sed 's/è/e/g' |sed 's/ì/i/g' |sed 's/ò/o/g' |sed 's/ù/u/g' \
	| sed 's/â/a/g' | sed 's/ê/e/g' |sed 's/î/i/g' |sed 's/ô/o/g' |sed 's/û/u/g' \
	| sed 's/ä/a/g' | sed 's/ë/e/g' |sed 's/ï/i/g' |sed 's/ö/o/g' |sed 's/ü/u/g'
}

songArtistSearch() {
	# $1 (First parameter) is searchPattern
	# To find a match looks for a song title that includes song title and artist at the same title (method -b)
	# returns songId if a match is found or 0 if not
	
	searchPattern=`trimmer $1 | tr ' ' '+'`

	# We search for the pattern
	search=`tempfile`
	wget -qO $search http://www.goear.com/search.php?q=$searchPattern

	# We get all the song titles from the first results page
	songTitles=`tempfile`
	cat $search | egrep -o 'class="b1">[^<]*</a>' | cut -f 2 -d '>' | cut -f 1 -d '<' > $songTitles

	if [ `cat $songTitles | wc -l` -eq 0 ]
	then
		echo "0"
		return
	fi

	# We get all their IDs
	songIds=`tempfile`
	cat $search | egrep -o "listen/([[:digit:]]|[[:alpha:]])*/" | cut -f 2 -d "/" | cut -f 1 -d '/' > $songIds

    # We decide which song to download
	echo $param | egrep -i '(mix|remix|rmx)' > /dev/null
	result=`echo $?`

	# If the name doesn't have a mix, remix or rmx on it
	if [ $result -eq 1 ]
	then
		lines=`cat $songTitles | wc -l`
		songNumber=0

		for i in `seq 1 $lines`
		do
			line=`cat $songTitles | head -$i | tail -1 | sed 's/&//g' | sed 's/;//g'`

			# Here you can add your filters for improving the snarch
			echo $param | egrep -i '(mix|remix|rmx)' > /dev/null
			result=`echo $?`

			if [ $result -eq 1 ]
			then
				echo $line | egrep -i '(mix|remix)' > /dev/null
				result=`echo $?`

				# If it's not a mix or remix then we download it
				if [ $result -eq 1 ]
				then
					songNumber=$i
					break
				fi
			fi
		done
	else
		# We download the first match, as lack of a better one
		songNumber=1
	fi

	# If it found a match
	if [ $songNumber -ne 0 ]
	then
		# We get the ID of that song title
		songId=`cat $songIds | head -$songNumber | tail -1`
		echo $songId
	else
		echo "0"
	fi
}

longestWord() {
	# $1 is a sentence
	# The function will echo the longest word in that sentence
	echo $1 | awk 'BEGIN{ l=0 }
	   {  
		  for ( i=1; i<=NF; i++){
			 gsub(/[[:punct:]]/,"",$i)
			 if (length($i) >l ) { 
				l=length($i)
				f=$i		 
			 }		 
		  }	  
	   }
	   END{
		  print f
	   }' 
}	

descriptionSearch() {
	# $1 (First parameter) is searchPattern
	# To find a match looks for a song title that includes only the song title and then uses the artist name to search 
	# the descriptions of the song (method -n)
    # returns songId if a match is found or 0 if not
	# return -1 if a no matter what we do we will not find a match
	
	searchPattern=`trimmer $(echo $1 | cut -f 1 -d '[') | tr ' ' '+'`
	artist=`trimmer $(echo $1 | cut -f 2 -d ']')`
	
	search=`tempfile`
	wget -qO $search http://www.goear.com/search.php?q=$searchPattern

	songTitles=`tempfile`
	cat $search | egrep -o 'class="b1">[^<]*</a>' | cut -f 2 -d '>' | cut -f 1 -d '<' > $songTitles

	if [ `cat $songTitles | wc -l` -eq 0 ]
	then
		echo "-1"
		return
	fi

	songIds=`tempfile`
	cat $search | egrep -o "listen/([[:digit:]]|[[:alpha:]])*/" | cut -f 2 -d "/" | cut -f 1 -d '/' > $songIds

    # We get the descriptions of every song
    descriptions=`tempfile`
    cat $search | egrep -io '<div style="color:[^;]*;font-size:11px;padding-left:13px;">[^<]*</div>' | cut -f 2 -d '>' | cut -f 1 -d '<' >> $descriptions
 
 	# We will search in the first 2 result pages. We don't check if a second page exists, it doesn't matter
	wget -qO $search "http://www.goear.com/search.php?q=$searchPattern&p=1"
	cat $search | egrep -o 'class="b1">[^<]*</a>' | cut -f 2 -d '>' | cut -f 1 -d '<' >> $songTitles
	cat $search | egrep -o "listen/([[:digit:]]|[[:alpha:]])*/" | cut -f 2 -d "/" | cut -f 1 -d '/' >> $songIds
    cat $search | egrep -io '<div style="color:[^;]*;font-size:11px;padding-left:13px;">[^<]*</div>' | cut -f 2 -d '>' | cut -f 1 -d '<' >> $descriptions

	# Now it's time to search within descriptions
	# Let's find the longest word in artist
	longestWord=`longestWord $artist`

	songNumber=0
	lines=`cat $descriptions | wc -l`
	for i in `seq 1 $lines`
	do
		line=`cat $descriptions | head -$i | tail -1`
		echo $line | grep -i "$longestWord" > /dev/null
		result=`echo $?`

		if [ $result -eq 0 ]
		then
			songNumber=$i
			break
		fi
	done

    if [ $songNumber -ne 0 ]
    then
        songId=`cat $songIds | head -$songNumber | tail -1`
        echo $songId
    else
        echo 0
    fi
}

downloadSong() {
	# $1 (First parameter) is the songId to download
	songId=$1

	# Download the metadata from goear in a XML
	infoline=`wget -qO- "http://www.goear.com/tracker758.php?f=$songId" | grep ".mp3"`
	mp3url=`echo $infoline | cut -d '"' -f 6`

	# Parse song title and artist from param and finally download the song
	songTitle=`trimmer $(echo $param | cut -f 1 -d '[')`
	artist=`trimmer $(echo $param | cut -f 2 -d ']')`
	echo "Downloading the song $songTitle FROM $artist"
	wget -O "$songTitle $artist.mp3" -q $mp3url 
}

# Parsing goear options 
BOTH=
NAME=
while getopts "b:n:h" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         b)
             BOTH=$2
             ;;
         n)
             NAME=$2
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if ([ -z "$BOTH" ] && [ -z "$NAME" ])
then
	usage
	exit 1
fi

# We get the parameter for searching the song
# -n method
if [ -z "$BOTH" ] 
then
	param=$NAME 
    songTitle=`trimmer $(echo $param | cut -f 1 -d '[')`
    artist=`trimmer $(echo $param | cut -f 2 -d ']')`

	fileName=`echo "$songTitle $artist.mp3"`
    if [ -s "$fileName" ]
	then
		echo "+mp3 already exists, skipping+"
		exit 1
	fi

	songId=`descriptionSearch "$param"`

# -b method
else  
	param=$BOTH
    songTitle=`trimmer $(echo $param | cut -f 1 -d '[')`
    artist=`trimmer $(echo $param | cut -f 2 -d ']')`
    
	echo
	fileName=`echo "$songTitle $artist.mp3"`
	if [ -s "$fileName" ]
	then
		echo "+mp3 already exists, skipping+"
		exit 1
	fi
	
	echo SEARCHING $songTitle FROM $artist, please wait
	songId=`songArtistSearch "$param"`
fi

# If search was futile
if [ $songId = "0" ]
then
	# If both was used we will try with to search by description
	if [ -z "$NAME" ]
	then
	   echo "...The song was not found..."
	   echo "...let's try to search different..."
	   ./GoearBestMatch.sh -n "$param"
	   result=`echo $?`

	   # We return what the child returned
	   if [ $result -eq 0 ]
	   then
	      exit 0
	   else
	   	  exit 1
	   fi

	# If name method was used
	else
	   echo "...Song still not found, last try..."
	   longestWord=`longestWord $artist`

	   # Let's try to do a last search, using the songtitle and the longest Word of the artist
	   songId=`songArtistSearch "$(echo "$songTitle [] $longestWord")"`

	   if [ $songId = "0" ] 
	   then
	   	  echo "...Impossible to find song, sorry..."
	      exit 1
	   fi	   
 	fi
elif [ $songId = "-1" ]
then
	  echo "...Impossible to find song, sorry..."
	  exit 1
fi

# Let's download the song
downloadSong $songId
exit 0
