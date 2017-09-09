#!/bin/bash

# This script tries to "synchronize" the target folder file names to those
# in the source folder. For that it manages a list of all file sizes and
# checksums and searches for identical files in the target folder and renames
# them to the given file in the source folder
#
# Usage: syncFilenames [options] <srcFolder> <targetFolder>

function echoerr() { echo "$@" 1>&2; }


# Handle command line arguments
fast=0
dryrun=0
while [ "$1" != "" ]; do
  case $1 in
    "-f" | "--fast")
        fast=1
        ;;
    "-n" | "--dry-run")
        dryrun=1
        ;;
    "--")
        break;
        ;;
    *)  # default case (neither one of the options from above, nor empty)
        if [ ${1:0:1} == '-' ]; then
            echo "Wrong parameters specified! (\$1=$1)"
            exit 1
        else
            break
        fi
        ;;
  esac
  shift
done

if [ ! $# -eq 2 ] || [ ! -d "$1" ] || [ ! -d "$2" ]; then
    echoerr -e "\e[31mNeed exactly two folder locations.\e[0m"
    exit
fi


tmp=$(mktemp -d)

echo -n "Collecting file size informations of destination '$2' into '$tmp/sizes.lst' ... "
find "$2" -type f -print0 | xargs -0 -I {} -P 4 bash -c '
    echo "$(wc -c "$0" | cut -d'"\" \""' -f 1) $0"
' {} > "$tmp/sizes.lst"
touch "$tmp/checksums.lst"
echo "Done"

# returns all file names in the target folder which have the same file size and
# the same checksum if fast=0 as a \0 separated list
findFile() {
    local size,lns,checksum1,checksum

    size=$( 'wc' -c "$1" | 'cut' -d ' ' -f 1 )    # file size in bytes
    if [ "$fast" -eq 0 ]; then
        checksum1=$( 'md5sum' "$1" | 'cut' -d ' ' -f 1 )
    fi
    # Get files with the same file size as the given one in $1 from the target folder
    lns=$( 'cut' -d ' ' -f 1 "$tmp/sizes.lst" | 'grep' -n "^$size\$" | 'cut' -d : -f 1 )
    #echoerr "  Try to find file '$1' containing $size B with MD5 $checksum1
    #Found Line Numbers: $lns"
    for ln in $lns; do
        fname=$( 'sed' -n "${ln}p" "$tmp/sizes.lst" | 'cut' -d ' ' -f 2- )
        #echoerr "    Possible match: $fname"
        # Compare only files smaller than 1MB directly, else use cached checksums if fast=0, else just assume they are identical
        if [ "$size" -lt $(( 1024*1024 )) ]; then
            if [ diff "$1" "$fname" 2&>1 1>/dev/null ]; then
                echo -n "$fname\0"
            fi
        else
            if [ "$fast" -eq 1 ]; then
                #echoerr "  -> found and printed"
                echo -n -e "$fname\0"
                continue
            fi
            # try to find checksum. if not found, append / cache it
            checksum=$( 'grep' -F "$fname" "$tmp/checksums.lst" | 'cut' -d ' ' -f 1 )
            if [ -z "$checksum" ]; then
                checksum=$( 'md5sum' "$fname" | 'cut' -d ' ' -f 1 )
                echo "$checksum $fname" >> "$tmp/checksums.lst"
            fi
            if [ "$checksum1" == "$checksum" ]; then
                echo -n -e "$fname\0"
            fi
        fi
    done
}

printCommand() {
    replaced=$(printf '%s' "$1" | sed "s|'|'\\\\''|g")
    echo "'$replaced'"
}

find "$1" -type f -size '+100M' -print0 | while IFS= read -r -d $'\0' fname; do
    #echoerr "Search for '$fname' in destination '$2':"
    findFile "$fname" | while IFS= read -r -d $'\0' foundFile; do
        name1=$(echo "$fname"     | sed 's|.*/||')
        name2=$(echo "$foundFile" | sed 's|.*/||')
        dir2=$( echo "$foundFile" | sed 's|/[^/]*$||')
        #echo "Test '$fname' and '$foundFile' -> '$name1' and '$name2'"
        if [ "$name1" != "$name2" ]; then
            #echoerr -e "\e[35m  '$fname' was renamed to '$foundFile' at the destination\e[0m"
            if [ "$dryrun" -eq 1 ]; then
                echo "mv -n $(printCommand "$dir2/$name2") $(printCommand "$dir2/$name1") "
            else
                echo mv "$fname" "$foundFile"
                # mv "$fname" "$foundFile"
            fi
        #else
        #    echoerr -e "\e[37m  File '$fname' was not renamed at destination '$foundFile'\e[0m"
        fi
    done
done


rm -r "$tmp"
