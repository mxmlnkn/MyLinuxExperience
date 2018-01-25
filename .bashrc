#!/bin/bash

xset -b

########################### Log session with script ############################

# add before opening history file. Open script to log session
#if test ! "$(ps -ocommand= -p $PPID | awk '{print $1}')" == 'script'; then
#    script $HOME/.bash_scripts/$(date +%Y-%m-%d_%H-%M-%S_%N).script --flush --timing=$HOME/.bash_scripts/$(date +%Y-%m-%d_%H-%M-%S_%N).time
#fi

############################ Bash History Settings #############################

HISTCONTROL=''
HISTFOLDER=$HOME/.bash_histories
HISTFILEEXT=history      # only files in $HISTFOLDER with this extension will be read
shopt -s histappend   # append when closing session
mkdir -p $HISTFOLDER
HISTFILE=$HISTFOLDER/$(date +%Y-%m-%d_%H-%M-%S_%N).$HISTFILEEXT  # create unique file name for this session. Nanoseconds seems to be unique enough, try: for ((i=0; i<=10; i++)); do date +%Y-%m-%d_%H-%M-%S_%N; done
# if HISTFILE unset, history is not saved on exit -> not really necessary if we save after each command, but its a double net safety
# HIST[FILE]SIZE=-1 resulted in =0 on a certain server, i.e. no history. bash --version:
#   GNU bash, version 4.2.46(1)-release (x86_64-redhat-linux-gnu)
HISTSIZE=10000        # maximum number of commands to hold inside bash history buffer
HISTFILESIZE=100000   # maximum number of lines in history file
# history -a $HISTFILE # bash saves the total history commands entered since startup or since the last save and saves that amount of commands to the file. This means reading a history file after typing commands will trip up bash, but this won't be a problem if the history file is only loaded in the beginning. This means that only new commands are saved not all the old loaded commands, thereby we can load as many history files into the buffer as we want and still only save newly thereafter typed commands
PROMPT_COMMAND="history -a $HISTFILE; $PROMPT_COMMAND"  # This command is executed after very typed command -> save history after each command instead after only closing the session

# Load old histories from last 5 files/sessions
HISTLINESTOLOAD=2000
# --reverse lists newest files at first
names=($(ls --reverse $HISTFOLDER/*.$HISTFILEEXT 2>/dev/null))
toload=()
linecount=0
# Check if is really file and count lines and only append to $toload if linecount under $HISTLINESTOLOAD
for fname in ${names[*]}; do
    if test -f $fname; then
        linecount=$((linecount+$(wc -l < $fname) ))
        if test $linecount -ge $HISTLINESTOLOAD; then
            break
        fi
        toload+=($fname)
    fi
done
# Beginning with the oldest load files in $toload into bash history buffer
for (( i=${#toload[*]}-1; i>=0; i-- )); do
    history -r ${toload[$i]}
done
unset names toload linecount

############################# Other Bash Settings ##############################

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
#   http://askubuntu.com/questions/372849/
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

isGitRepo() { git rev-parse --git-dir &>/dev/null; }
if ! type GitPS1 &>/dev/null | grep -q 'function'; then
    GitPS1() {
        if isGitRepo; then
            local branchName=$(git symbolic-ref --short HEAD -q 2>/dev/null)
            if [ -z "$branchName" ]; then
                branchName=$(git rev-parse --short HEAD)
            fi
            echo "($branchName)"
        fi
    }
fi
getMountPoints() {
    mount | sed -nE 's/.* on (.*) type .* \(.*\)/\1/p' | tac
}
pswd() {
    # like pwd, bugt limits length to 40 characters
    local dir=$(pwd)
    if [ ${#dir} -gt 40 ]; then
        local mountPoints=($(getMountPoints))
        local path
        for path in ${mountPoints[@]}; do
            if [ "${dir##$path}" != "$dir" ]; then break; fi
        done
        dir=$(printf '%s' "${dir##$path}" | sed -E 's|.*((/.*){3})|\1|')
        echo "[${path##*/}]…$dir"
    else
        echo "$dir"
    fi
}

color_prompt='yes'
if [ "$color_prompt" = yes ]; then
    # Note that the \e[32m style of doing color codes will lead to line wrapping issues!
    # Instead use \033 instead of \e
    # Actually the reason was that all non-printable characters must be enclosed in \[  \]
    # http://stackoverflow.com/questions/1133031/shell-prompt-line-wrapping-issue
    PS1='\[\e[0m\]${debian_chroot:+($debian_chroot)}\[\e[2m\]\u@\h\[\e[0m\]:\[\e[33m\]$(GitPS1)\[\e[0m\]\[\e[32m\]$(pswd)\[\e[0m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

############################### Set Window Title ###############################

# the "\e]0;" code tells it to write everything up to the "\a" in both the
# title and icon-name properties. You need to remove that and set it to
# something like this (i.e. without the \e]0; code):
case "$TERM" in
xterm*|rxvt*)
    # escape characters explained in man bash | grep PROMPTING:
    # \w  the current working directory, with $HOME abbreviated with
    #     a tilde (uses the value of the PROMPT_DIRTRIM variable)
    PS1='\[\e]0;$(pswd)\a\]'"$PS1"
    ;;
*)
    ;;
esac


################### aliases and custom environment variables ###################

commandExists() {
    # http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
    command -v "$1" > /dev/null 2>&1;
}

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color'
    # the always option is important to color it also when piping to head, tail, ...
    alias grep='grep --color=always' # --line-number'
    alias dmesg='dmesg --color=always'
fi
# if you want to use the original mv,cp,rm then use either /bin/mv,... or command mv or "mv" or 'mv' or \mv
if commandExists 'trash'; then alias rm='trash'; fi
alias mv='mv -i'
alias cp='cp -i'
alias la='ls -lah --group-directories-first'
alias l='la'
# make nvcc workw ith g++ 4.9 instead of default g+ 5.2, which it can't work with
alias nvcc='nvcc -ccbin=/usr/bin/g++-4.9 --compiler-options -Wall,-Wextra'
if commandExists 'git'; then
    alias gb='git branch --color=always'
    alias gs='git status'
fi
alias lc='locate -i'
alias sup='sudo apt-get update'
alias si='sudo apt-get install -t sid'
# go into old upper diretory on cd .., even if the current folder was moved e.g. to trash
# use command cd for original behavior. Unfortunately 'cd' does not work, because
# that only prevents alias lookup, not function lookup it seems (This also puts
# my usage of 'command' in scripts into persepctive :S
cd(){ if [ "$1" == '..' ]; then command cd "${PWD%/*}"; else command cd "$@"; fi; }

alias crawlSite='wget --limit-rate=200k --no-clobber --convert-links --random-wait --recursive --page-requisites --adjust-extension -e robots=off -U mozilla --no-remove-listing --timestamping'
alias splitImages='for file in *; do convert -crop 50%x100% "$file" "${file%.*}-%0d.${file##*.}"; done'


# function keyword necessary if function name already is defined as an alias!

function prettyPrintSeconds() {
    local d h m s
    r=$1
    (( s = r % 60 ))
    (( r = r / 60 ))
    (( m = r % 60 ))
    (( r = r / 60 ))
    (( h = r % 24 ))
    (( r = r / 24 ))
    (( d = r      ))
    if ! [ "$d" -eq 0 ]; then printf "%02dd " "$d"; fi
    if ! [ "$h" -eq 0 ]; then printf "%02dh " "$h"; fi
    if ! [ "$m" -eq 0 ]; then printf "%02dm " "$m"; fi
    if ! [ "$s" -eq 0 ]; then printf "%02ds " "$s"; fi
    printf "\n"
}

function t0(){
    _T0=$(date +%s)
    echo "Recorded time t0 at $(date)"
}

function t1(){
    _T1=$(date +%s)
    echo "Recorded time t1 at $(date)"
    if ! [ "$_T0" -eq "$_T0" ]; then
        echo -e "\e[37mNo _T0 variable set. You need to call 't0' before 't1' to get a difference\e[0m"'!' 2>&1
    else
        echo -n "Difference to t0 is "
        prettyPrintSeconds "$(( _T1 - _T0 ))"
    fi
}

unalias sp lb 2>/dev/null
sp(){
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
    fi
    xfce4-session-logout --suspend &&
    sleep 10s && (
        refreshWallpaper;
        if [ -n "$( pgrep hostapd )" ]; then
            sleep 2s
            startap
        fi
    )
}

lb(){ locate -i -b '*'"$*"'*'; }

up() {
    if [ "$1" -lt 256 ] 2>/dev/null; then
        for ((i=0;i<$1;i++)); do
            cd ..;
        done;
    fi
}

echoerr() { echo "$@" 1>&2; }
stringContains() {
    #echo "    String to test: $1"
    #echo "    Substring to test for: $2"
    [ -z "${1##*$2*}" ] && [ ! -z "$1" ]
}

# This function returns all links found in the given html-file.
# One link begins with http:// or https:// and ends on the first "-mark,
# because the format expected is: href="http://..."
# This function is independent of the site to crawl! The returned links need
# to be filtered differently depending on what to crawl. See filterUrls()
getUrls() {
    sed 's|<a href="|\nKEEP!!|g' "$1" | sed '/^KEEP!!/!d; s/KEEP!!//; s/".*$//g; s/ /%20/g'
}

getmac() {
    #if [ ! -z "$1" ]; then
    #    ip addr ls "$1" | sed -nE 's|[ \t]*link/ether ([a-f0-9:]+) brd.*|\1|p'
    #else
    #    ip addr ls | sed -nE '/[ \t]*[0-9]+: ([A-Za-z0-9]*):/{
    #        s|[ \t]*[0-9]+: ([A-Za-z0-9]*):.*|\1|p;
    #        n;s|[ \t]*link/ether ([a-f0-9:]+) brd.*|  \1|p}';
    #fi
    local file
    for file in /sys/class/net/*/address; do
        printf '%-40s ' "$file"
        printf '%-20s ' "$( cat "$file" )" # this also removes \n from cat
        file=${file%/*}
        file=${file##*/}
        if commandExists ethtool; then ethtool -P "$file"; else echo; fi
    done
    #ifconfig eth0 | sed -nr 's|.*ether[ \t]*([0-9a-f:]+).*|\1|p'
}

offSteamUpdates() {
    for lib in "$@"; do
        find "$lib" -name '*.acf' -execdir bash -c "
            if grep -q 'AutoUpdateBehavior.*\"[^1]\"' \"\$1\"; then
            "'  echo $(pwd)/{};
                sed -i -E'" 's|(AutoUpdateBehavior.*\")[^1]\"|\11\"|' '{}';
            fi;
        " bash {} \; ; done
}
getLargestSide() {
    local w=$(convert "$1" -format "%w" info:)
    local h=$(convert "$1" -format "%h" info:)
    if [ "$w" -gt "$h" ]; then echo $w; else echo $h; fi
}

makeIcon() {
    if [ -z "$1" ]; then
        echo -e "\e[31m Please specify a path to an image.\e[0m"
        exit 1
    fi
    #set -vx
    local size=$(getLargestSide "$1")
    local tmpPng=$(mktemp)
    convert "$1" -alpha set -background none -gravity center -extent ${size}x${size}  "$tmpPng"
    convert "$tmpPng" -define icon:auto-resize=256,128,64,48,32,16 -compress none "$1.ico"
    rm "$tmpPng"
    test -f "$1.ico"
    #set +vx
}

mvsed() {
    # $1 rule for sed how to work on file name
    local dryrun
    if [ "$1" == '-n' ]; then
        dryrun='echo'
        shift
    fi
    if [ -z "$1" ]; then
        cat <<EOF
mvsed [-n] <sed-rule>
 -n   dry-run, just show mv commands
EOF
        return
    fi
    if ! echo '' | sed -r "$1"; then
        # E.g. if sed rule is wrong
        return
    fi
    find . -mindepth 1 -maxdepth 1 -execdir bash -c '
        fname=$1
        fname=$( basename "$fname" ) # this strips the leading ./ and trailing / for directories, find doesnt give trailing /
        if [ -d "./$fname" ]; then fname=$fname/; fi
        newname=$( printf "%s" "$fname" | sed -r '"'$1'"' )
        if [ "$fname" != "$newname" ]; then
            if [ -n "'$dryrun'" ]; then
                '"printf \"mv '%s'\n-> '%s'\n\" "'"$fname" "$newname"
            else
                mv "./$fname" "./$newname"
            fi
        fi
    ' bash {} \;
}

lac() {
    # show listing, but replace the second column (hard link count:
    # http://askubuntu.com/questions/19510/) with the number of files and
    # folders if it is a directory

    local folder=$1
    if [ -z "$folder" ]; then
        folder=.
    fi

    # line looks e.g. like this (only the file name is colored)
    #   drwx------ 1 grouo user 108K Jun  1 13:09 .
    local line
    while read line; do
        if echo "$line" | grep -q '^d'; then
            # this doesn't work if the username has spaces in it ...
            local style='\x1B\[[0-9]+(;[0-9]+)*m'
            local name=$(echo "$line" |
                'sed' -nr 's|^([^ ]+ +){8}('"$style"')*(.*)'"$style"'$|\4|p' )
                #             \1     \1   \2   \3   \2 \4\4
                # E.g.          19:34      \e[01;34m     .
                #                              ;34
            #echo "Line          : $line"
            #echo "Extracted Name: $name"
            if [ ! -d "$folder/$name" ]; then
                echo -e "\e[31mSomething went wrong, extracted folder '$name' name doesn't seem to exist"'!'"\e[0m" 1>&2
            fi
            local nFiles=$('ls' -A -1 "$folder/$name" | 'wc' -l)
        else
            #local nFiles=$(echo "$line" | 'sed' -r 's|^[^ ]+ [ ]*([0-9]+).*|\1|')
            local nFiles=1
        fi
        echo "$line" | 'sed' -r 's|^([^ ]+ )[ ]*[0-9]+|\1'"$('printf' '% 4i' $nFiles)|"
    done < <('ls' --color -lah --group-directories-first $@)
}

equalize-volumes() {
    local masterVolume sink
    masterVolume=$(amixer get 'Master' | sed -nr 's|.*\[([0-9]*%)\].*|\1|p' | head -1)
    for sink in $(pactl list sink-inputs | sed -nr 's/^Sink Input #(.*)/\1/p'); do
        pactl set-sink-input-volume $sink $masterVolume
    done
}

githubSize() {
    # expects a github clone link, e.g. https://github.com/chrissimpkins/Hack.git
    echo "$1" |
        perl -ne 'print $1 if m!([^/]+/[^/]+?)(?:\.git)?$!' |
        xargs -i curl -s -k https://api.github.com/repos/'{}' |
        'grep' size |
        sed -nr 's|.*: ([0-9]*).*|\1 KB|p'
}

colorinfo16() {
    for clbg in {40..47} {100..107} 49 ; do
        for clfg in {30..37} {90..97} 39 ; do
            for attr in 0 1 2 4 5 7 ; do
                echo -en "\e[${attr};${clbg};${clfg}m ^[${attr};${clbg};${clfg}m \e[0m"
            done
            echo
        done
    done
}

igcc() {
    # Use e.g. with:  igcc 'std::cout << "hello\n";'
    # to kinda test  things interactively
    local oldDir=$(pwd)
    local folder=$(mktemp -d)
    cd "$folder"
    cat <<EOF > tmp.cpp
// http://en.cppreference.com/w/cpp/header

#include <algorithm>                            // count_if, sort
#include <cassert>
#include <climits>                              // INT_MAX
#include <cfloat>                               // FLT_MAX
#include <cmath>                                // isnan
#include <ctime>
#include <cstdint>                              // uint8_t
#include <cstdio>
#include <cstdlib>                              // rand, malloc

#include <array>                                // template fixed size arrays
#include <algorithm>                            // sort, find, ...
#include <chrono>
#include <complex>
#include <deque>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <list>
#include <map>
#include <mutex>
#include <numeric>                              // accumulate
#include <queue>
#include <random>
#include <set>
#include <sstream>
#include <stdexcept>                            // invalid_argument
#include <stack>
#include <string>
#include <thread>
#include <typeinfo>
#include <utility>                              // pair
#include <vector>

#include <boost/core/demangle.hpp>

template <class T>
std::string
type_name()
{
    typedef typename std::remove_reference<T>::type TR;
    std::unique_ptr<char, void(*)(void*)> own( nullptr, std::free );
    std::string r = own != nullptr ? own.get() : typeid(TR).name();
    r = boost::core::demangle( r.c_str() );
    if (std::is_const<TR>::value)
        r += " const";
    if (std::is_volatile<TR>::value)
        r += " volatile";
    if (std::is_lvalue_reference<T>::value)
        r += "&";
    else if (std::is_rvalue_reference<T>::value)
        r += "&&";
    return r;
}

int main( int argc, char ** argv )
{
    $1
    return 0;
}
EOF
    g++ tmp.cpp -std=c++11 -Wall -o a.out
    ./a.out
    rm -r "$folder"
    cd "$oldDir"
}

o() { xdg-open "$*"; }

downo() {
    local link
    for link in $@; do
        wget "$link"
        xdg-open "${link##*/}"
    done

}

alias getip='wget -q -O /dev/stdout http://checkip.dyndns.org/ | cut -d : -f 2- | cut -d \< -f -1'

findPath()
{
    local path
    for path in "$@"; do
        if [ -f "$path" ]; then
            printf '%s' "$path"
            break
        fi
    done
}

toUTF8()
{
    iconv -f ISO8859-15 -t UTF8 "$1" -o "$1".utf8
    echo -ne '\xEF\xBB\xBF' > "$1".utf8 && iconv -f ISO8859-15 -t UTF8 "$1" >> "$1".utf8
    trash "$1"
    mv --no-clobber "$1.utf8" "$1"
}

splitCue()
{
    shnsplit -f "$1" -t '%n - %t' -o flac -- "${1%.cue}".[^c]*
}

trash-empty()
{
    local mountpoint folder dry
    local ndays=$1
    if [ "$1" == '-d' ] || [ "$2" == '-d' ]; then dry=echo; fi
    for mountpoint in $( cat /proc/mounts | awk '{ print $2; }' ); do
        for folder in ".Trash/$UID" ".Trash-$UID" '$RECYCLE.BIN'; do
            if [ -d "$mountpoint/$folder" ]; then
                echo "Deleting '$mountpoint/$folder/' ..." 1>&2
                if [ "$ndays" -eq "$ndays" ] 2>/dev/null && [ "$ndays" != 0 ] && [ -d "$mountpoint/$folder/info/" ]; then
                    # assuming that file modification date for .trashinfo files is the same as the DeletionDate stored inside that file
                    # note that -mtime +0 will find all files older than 24h and +1 all files older than 2 days, ...
                    find "$mountpoint/$folder/info/" -mtime "+$(( ndays-1 ))" -name '*.trashinfo' -print0 |
                    sed -rz "s|^(.*)/${folder//./\\.}/info/(.*)\.trashinfo$|\1$folder/info/\2.trashinfo\x00\1$folder/files/\2|" |
                    xargs -0 $dry 'rm' -r
                else
                    $dry command rm -r "$mountpoint/$folder/"
                fi
            fi
        done
    done
}

# cleanes filename of files in current folder and its subdirectories
# no target directory or file argument possible at the moment
#
# ToDo: create list of files, run sed over this whole list instead of per each file name and then diff this .... Something like find -print0 | tee original.lst | sed -z '...' > changed.lst; diff {original,changed}.lst | xargs -0 -L3 -l3 ...

# takes piped input!
cleanFilenames() {
    # Windows restrictions: https://msdn.microsoft.com/en-us/library/aa493942%28v=exchg.80%29.aspx
    #    / \ * ? < > |
    #    \x22->\x27 makes: double quote -> single quote
    #    pipestroke -> hyphen
    #    double quote -> single quote
    # Windows: https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx
    #   < > : " / \ | ? *
    # Change HTML-Codes:
    #    &#039; -> '
    #    here is how to correct html codes in existing folder names:
    #       find /media/m -type d -execdir bash -c 'if grep -q "&#039;" <(echo '"'{}'"'); then newname=$(printf "%s" '"'{}'"' | sed "s/&#039;/'"'"'/g"); echo mv "{}"; echo " -> $newname"; mv "{}" "$newname"; fi' \;
    # Use printf instead of echo to make it work for file names starting with e.g. '-e'
    sed -r '
        # $! - If its not a end of file.
        # N  - Append the next line with the pattern space delimited by \n
        # b  - jump to label
        :a
            N
        $!b a
        s/\n/ /g
        # for some reason s/\r//g wouldnt work now :S, that is why it is piped to another sed
    ' | perl -C -MHTML::Entities -pe 'decode_entities($_);' | sed -r '
        # windows restrictions -> the two most important replacements
        s/[|/\:]/ - /g;
        s/[*?<>]/_/g;
        s|—|-|g;
        s/\x22/\x27/g;
        # .html.mht -> .mht
        s/\.html\.mht/\.mht/g;
        # intrusive and not really necessary. was just because I thought it could spell trouble in bad bash scripts -.-
        #s/[$/_/g;
        # delete dots at the end of line (windows has issue with empty extensions -.-)
        s/\.+$//g;
        s/&#039;/'\''/g;
        # Replace & character. Also quite intrusive ...
        # s|&| and |g;
        s|";|'\''|g;
        # delete leading spaces
        s/^[ \t]+//g;
        # delete white spaces at end of extension
        s/[ \t]+$//g;
        # delete white spaces at end of file name
        s/[ \t]+(\.[0-9A-Za-z]{3})$/\1/g;
        # delete newlines and returns and other non-printables
        s/[\x01-\x1F\x7F]/ /g;
        s|\t| |g;
        s|[ \t]+| |g;
        # convert hex codes
        s|%20| |g;
        # convert extensions to lowercase (quite intrusive)
        # s|(\.[A-Za-z0-9]{3})$|\L\1|;
        # some other obnoxious extensions
        # intrusive
        # s|\.jpeg$|.jpg|;
        s|\.png\.jpg|.jpg|;
        s|\.jpg\.png|.png|;
    '
}

isodate() { date "$@" +%Y-%m-%dT%H-%M-%S; }

hexdump()
{
    # introduces artifical line breaks in hexdump output at newline characters
    # might be useful for comparing files linewise, but still be able to
    # see the differences in non-printable characters utilizing hexdump
    # first argument must be -n else normal hexdump will be used
    local isTmpFile=0
    if [ "$1" != '-n' ]; then command hexdump "$@"; else
        if [ -p /dev/stdin ]; then
            local file="$( mktemp )" args=( "${@:2}" )
            isTmpFile=1
            cat > "$file" # save pipe to temporary file
        else
            local file="${@: -1}" args=( "${@:2:$#-2}" )
        fi
        # sed doesn't seem to work on file descripts for some very weird reason,
        # the linelength will always be zero, so check for that, too ...
        local readfile="$( readlink -- "$file" )"
        if [ -n "$readfile" ]; then
            # e.g. readlink might return pipe:[123456]
            if [ "${readfile::1}" != '/' ]; then
                readfile="$( mktemp )"
                isTmpFile=1
                cat "$file" > "$readfile"
                file="$readfile"
            else
                file="$readfile"
            fi
        fi
        # we can't use read here else \x00 in the file gets ignored.
        # Plus read will ignore the last line if it does not have a \n!
        # Unfortunately using sed '<linenumbeer>p' prints an additional \n
        # on the last line, if it wasn't there, but I guess still better than
        # ignoring it ...
        local linelength offset nBytes="$( cat "$file" | wc -c )" line=1
        for (( offset = 0; offset < nBytes; )); do
            linelength=$( sed -n "$line{p;q}" -- "$file" | wc -c )
            (( ++line ))
            head -c $(( offset + $linelength )) -- "$file" |
            command hexdump -s $offset "${args[@]}" | sed '$d'
            (( offset += $linelength ))
        done
        # Hexdump displays a last empty line by default showing the
        # file size, bute we delete this line in the loop using sed
        # Now insert this last empty line by letting hexdump skip all input
        head -c $offset -- "$file" | command hexdump -s $offset "$args"
        if [ "$isTmpFile" -eq 1 ]; then rm "$file"; fi
    fi
}

hexdiff()
{
    # compares two files linewise in their hexadecimal representation
    # create temporary files, because else the two 'hexdump -n' calls
    # get executed multiple times alternatingly when using named pipes:
    # colordiff <( hexdump -n -C "${@: -2:1}" ) <( hexdump -n -C "${@: -1:1}" )
    local a="$( mktemp )" b="$( mktemp )"
    hexdump -n -v -C "${@: -2:1}" | sed -r 's|^[0-9a-f]+[ \t]*||;' > "$a"
    hexdump -n -v -C "${@: -1:1}" | sed -r 's|^[0-9a-f]+[ \t]*||;' > "$b"
    colordiff "$a" "$b"
    rm "$a" "$b"
}

#hexlinedump()
#{
#    # real	0m6.554s
#    # user	0m6.796s
#    # sys	0m0.204s
#    local nChars=$1 file=$2 a="$( mktemp )" b="$( mktemp )"
#    od -w$( cat -- "$file" | wc -c ) -tx1 -v -An -- "$file" |
#    sed 's| 0a| 0a\n|g' | sed -r 's|(.{'"$(( 3*nChars ))"'})|\1\n|g' |
#    sed '/^ *$/d' > "$a"
#    # need to delete empty lines, because 0a might be at the end of a char
#    # boundary, so that not only 0a, but also the character limit introduces
#    # a line break
#    sed -r 's|(.{'"$nChars"'})|\1\n|g' -- "$file" | sed -r 's|(.)| \1 |g' > "$b"
#    paste -d$'\n' -- "$a" "$b"
#    rm "$a" "$b"
#}

hexlinedump()
{
    # https://unix.stackexchange.com/questions/40694/why-real-time-can-be-lower-than-user-time
    # real	0m5.363s
    # user	0m7.224s
    # sys	0m0.192s
    # => is slower in total user time, but parallelizes better therefore smaller real time!
    local nChars=$1 file=$2
    paste -d$'\n' -- <( od -w$( cat -- "$file" | wc -c ) -tx1 -v -An -- "$file" |
        sed 's| 0a| 0a\n|g' | sed -r 's|(.{'"$(( 3*nChars ))"'})|\1\n|g' |
        sed '/^ *$/d' ) <(
    # need to delete empty lines, because 0a might be at the end of a char
    # boundary, so that not only 0a, but also the character limit introduces
    # a line break
    sed -r 's|(.{'"$nChars"'})|\1\n|g' -- "$file" | sed -r 's|(.)| \1 |g' )
}

#hexdiff()
#{
#    # real	0m16.114s
#    # user	0m19.792s
#    # sys	0m0.644s
#    local a="$( mktemp )" b="$( mktemp )"
#    hexlinedump 16 "${@: -2:1}" > "$a"
#    hexlinedump 16 "${@: -1:1}" > "$b"
#    colordiff --difftype=diffy "$a" "$b"
#    rm "$a" "$b"
#}

hexdiff()
{
    # real	0m12.958s
    # user	0m18.908s
    # sys	0m0.564s
    colordiff <( hexlinedump 16 "${@: -2:1}" ) <( hexlinedump 16 "${@: -1:1}" )
}
