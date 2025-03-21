#!/bin/bash

export XDG_DATA_HOME=$HOME/.local/share
export XDG_CONFIG_HOME=$HOME/.config
export XDG_STATE_HOME=$HOME/.local/state
export XDG_CACHE_HOME=$HOME/.cache

mkdir -p -- "$XDG_DATA_HOME"
mkdir -p -- "$XDG_CONFIG_HOME"
mkdir -p -- "$XDG_STATE_HOME"
mkdir -p -- "$XDG_CACHE_HOME"

# GUI programs started via Desktop shortcuts should have these defined in .profile or /etc/X11/Xsession, I think.
# export ANDROID_USER_HOME="$XDG_DATA_HOME"/android
# export DOTNET_CLI_HOME="$XDG_DATA_HOME"/dotnet
# export GNUPGHOME="$XDG_DATA_HOME"/gnupg
# export MPLAYER_HOME="$XDG_CONFIG_HOME"/mplayer

export IPFS_PATH="$XDG_DATA_HOME"/ipfs
export RUSTUP_HOME="$XDG_DATA_HOME"/rustup
export VAGRANT_HOME="$XDG_DATA_HOME"/vagrant

export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME"/aws/credentials
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME"/aws/config
export DOCKER_CONFIG="$XDG_CONFIG_HOME"/docker
export PARALLEL_HOME="$XDG_CONFIG_HOME"/parallel
export _JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java

export ICEAUTHORITY="$XDG_CACHE_HOME"/ICEauthority

export NPM_CONFIG_INIT_MODULE="$XDG_CONFIG_HOME"/npm/config/npm-init.js
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME"/npm
export NPM_CONFIG_TMP="$XDG_RUNTIME_DIR"/npm

export SQLITE_HISTORY="$XDG_CACHE_HOME"/sqlite_history


xset -b &>/dev/null  # Turn bell off

# https://unix.stackexchange.com/questions/332791/how-to-permanently-disable-ctrl-s-in-terminal
stty -ixon

########################### Log session with script ############################

# add before opening history file. Open script to log session
#if test ! "$(ps -ocommand= -p $PPID | awk '{print $1}')" == 'script'; then
#    script $HOME/.bash_scripts/$(date +%Y-%m-%d_%H-%M-%S_%N).script --flush --timing=$HOME/.bash_scripts/$(date +%Y-%m-%d_%H-%M-%S_%N).time
#fi

############################ Bash History Settings #############################

HISTCONTROL=''
HISTFOLDER=$XDG_DATA_HOME/bash_histories
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
PROMPT_COMMAND="history -a $HISTFILE; $PROMPT_COMMAND"  # This command is executed after every typed command -> save history after each command instead after only closing the session

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

# find out if we are connected to some server with SSH
REMOTE_SESSION=0
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    REMOTE_SESSION=1
else
    case "$( ps -o comm= -p $PPID )" in
        sshd|*/sshd) REMOTE_SESSION=1 ;;
    esac
fi

isGitRepo() { git rev-parse --git-dir &>/dev/null; }
if ! type GitPS1 &>/dev/null | 'grep' -q 'function'; then
    GitPS1() {
        if isGitRepo; then
            # not using --short, because it's not available in Git 1.7.1
            local branchName="$( git symbolic-ref HEAD -q 2>/dev/null )"
            branchName="${branchName##*/}"
            if [ -z "$branchName" ]; then
                branchName="$( git rev-parse --short HEAD )"
            fi
            echo "($branchName)"
        fi
    }
fi

function getMountPoints() {
    mount | sed -nE 's/.* on (.*) type .* \(.*\)/\1/p' | tac
}

function pswd() {
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

ErrorCodePS1()
{
    local exitCode=$?
    if ! test "$exitCode" -eq 0; then
        echo -e "($exitCode) "
    fi
}

color_prompt='yes'
if [ "$color_prompt" = yes ]; then
    # Note that the \e[32m style of doing color codes will lead to line wrapping issues!
    # Instead use \033 instead of \e
    # Actually the reason was that all non-printable characters must be enclosed in \[  \]
    # http://stackoverflow.com/questions/1133031/shell-prompt-line-wrapping-issue
    PS1='\[\e[0m\]\[\e[31m\]$( ErrorCodePS1 )\[\e[0m\]${debian_chroot:+($debian_chroot)}\[\e[2m\]\u@\h\[\e[0m\]:\[\e[33m\]$( GitPS1 )\[\e[0m\]\[\e[32m\]$( pswd )\[\e[0m\]\$ '
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
    if [ "$REMOTE_SESSION" -eq 1 ]; then
        PS1_REMOTE_HOSTNAME="[$( hostname )] "
    else
        PS1_REMOTE_HOSTNAME=
    fi
    PS1='\[\e]0;$PS1_REMOTE_HOSTNAME$(pswd)\a\]'"$PS1"
    # Show currently running command as window title
    trap 'echo -ne "\e]0;$BASH_COMMAND\007"' DEBUG
    ;;
*)
    ;;
esac


################### aliases and custom environment variables ###################

function commandExists() {
    # http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
    command -v "$1" > /dev/null 2>&1;
}

function checkCommand()
{
    local package
    if [[ $# -lt 2 ]]; then package=$1; else package=$2; fi
    if ! commandExists "$1"; then
        echoerr "$1 command not found, please install the '$package' package"
        return 1
    fi
    return 0
}

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color'
    # the always option is important to color it also when piping to head, tail, ...
    alias grep='grep --color=always' # --recursive is not a good idea because it is problematic when piping to grep --line-number can also be obnoxious, especially when piping
    alias dmesg='dmesg --color=always'
fi
# if you want to use the original mv,cp,rm then use either /bin/mv,... or command mv or "mv" or 'mv' or \mv
if commandExists 'trash'; then alias rm='trash'; fi
function mv2dir()
{
    # if multiple files are moved, then create directory?
    # Or can I catch this warning somehow? mv: target 'foo' is not a directory
    local targetDidNotExist=0
    if ! test -d "${@: -1}"; then
        mkdir -p -- "${@: -1}"
        targetDidNotExist=1
    fi
    ( mv --no-clobber "$@" && rm -r "${@:1:$#-1}" ) ||
    if test "$targetDidNotExist" -eq 1; then rmdir -- "${@: -1}"; fi
}
alias mv='mv -i'
alias cp='cp -i --preserve=timestamps'
alias la='ls -lAh --group-directories-first'
alias l='la'
alias tbz2='tar --use-compress-program=lbzip2'
alias tgz='tar --use-compress-program="bgzip --threads $( nproc )"'
alias scp='scp -p'

if commandExists 'git'; then
    function gcl()
    {
        # https://github.com/git-lfs/git-lfs/issues/3559#issuecomment-472873934
        GIT_LFS_SKIP_SMUDGE=1 git clone --recursive "$@" && ( folder="${_##*/}"; cd -- "${folder%.git}" && git lfs fetch; )
    }
    alias gb='git branch --color=always'
    alias gba='git branch --color=always --all'
    alias gbl='git blame'
    alias gs='git status'
    alias gm='git commit'
    alias gpf='git push -f'
    alias grba='git rebase --abort'
    alias glo='git log --pretty=format:"%C(yellow)%h %C(red)%ad %C(cyan)%an%C(green)%d %Creset%s" --date=short'
    alias gls='git log --stat'
    alias glp='git log --pretty --update --graph --decorate --oneline'
    alias grhh='git reset --hard HEAD'
    alias gcp='git cherry-pick'
    alias gch='git checkout HEAD'
    alias gcpa='git cherry-pick --abort'
    alias gcpc='git cherry-pick --continue'
    alias gpoc='git push --set-upstream own "$( git symbolic-ref HEAD -q 2>/dev/null | sed "s|.*/||" )"'

    function grbc()
    {
        # automatically stage all unstaged changes and merge conflicts if merge-conflict markers are removed
        if ! git diff --quiet && git diff --check; then
            git add --update
        fi
        git rebase --continue
    }

    function gl()
    {
        # show pretty-printed log history of current or specified branch to master if there is a common merge base
        if ! git rev-parse --verify master &>/dev/null; then
            git log --pretty=format:"%C(yellow)%h %C(red)%ad %C(cyan)%an%C(green)%d %Creset%s" --date=short "$@"
            return
        fi

        local range=
        local options=()

        while test $# -gt 0; do
            if [[ "$1" =~ --.* ]]; then
                options+=( "$1" )
            elif test "$#" -eq 1; then
                range="$1"
            else
                options+=( "$1" )
                echo "Can't parse arguments, will simply forward all to git log call."
                shift
                break
            fi
            shift
        done

        if [[ -f $range ]]; then
            git log --follow "${options[@]}" "$@" "$range"
            return
        fi

        if test $# -eq 0; then
            local endPoint="$( git rev-parse HEAD )"
            if test -n "$range" && git rev-parse "$range" &>/dev/null; then
                endPoint="$( git rev-parse "$range" )"
            fi

            local startPoint="$( git merge-base master $endPoint )"
            if test "$startPoint" != "$endPoint"; then
                range=$startPoint..$endPoint
            fi
        fi

        git log --pretty=format:"%C(yellow)%h %C(red)%ad %C(cyan)%an%C(green)%d %Creset%s" --date=short "${options[@]}" "$@" $range
    }

    function ga()
    {
        if ! 'git' diff --quiet --name-only --staged; then
            # if there is something staged, then simply commit all staged
            git commit --amend --no-edit
        elif ! 'git' diff --quiet --name-only; then
            # if there is noting staged but something changed, then simply commit all
            git commit --amend --no-edit --all
        else
            # if no changed files, open without --no-edit to change last commit message
            git commit --amend
        fi
    }

    alias grh='git reset HEAD'
    alias gss='git show --stat'
    alias gco='git checkout'
    alias gdc='git diff --cached'
    alias gcf='git commit --fixup'
    alias gap='git add -p'

    alias gp='git pull'

    # delete merged branches (except specially named like master, dev, develop
    # Not that this gives different results depending on which checked out branch you currently are!
    # But you can call gdbm master
    function gbdmToCurrent()
    {
        if [[ $# -ne 1 ]]; then
            echo "Please specify the branch that all other branches should be merged into."
            return 1
        fi

        local mainBranch="$1"
        git branch --no-color --merged "$mainBranch" |
            command grep -vE "^([*+]|\s*(master|develop|dev)\s*$)" |
            command xargs -n 1 git branch -d

        echo "Branches that seem to have been merged even though git does not think so:"

        for branch in $( git branch --no-color | command grep -vE "^([*+]|\s*(master|develop|dev)\s*$)" ); do
            if ! git show "own/$branch" &>/dev/null; then
                readarray -t -d $'\n' commits < <( git log --pretty=format:%s "$( git merge-base "$mainBranch" "$branch" )..$branch" )

                mismatches=0
                for commit in "${commits[@]}"; do
                    if ! git log --pretty=format:%s "$mainBranch" | 'grep' -q -Fx -- "$commit"; then
                        mismatches=1
                    fi
                done

                if [[ $mismatches -eq 0 && ${#commits[@]} -gt 0 ]]; then
                    echo git branch -D "$branch"
                fi
            fi
        done
    }

    alias gbdm='gbdmToCurrent master'

    # @todo open changed files (). either currently in staging and modified or in last commit (git show)
    # goc()

    function gfd()
    (
        # sorts all modified uncommitted files into parent commits as fixups
        # basically only needs git add, commit, and log, so it should be fine to run this while rebasing interactively

        if test -n "$( command git diff --cached --name-only )"; then
            echo "Won't sort changed files into previous commits as fixups because there are staged files already"'!' 1&>2
            return 1
        fi

        cd -- "$( git rev-parse --show-toplevel )"
        local startPoint="$( git merge-base master HEAD )"

        local changedFile changedFiles=()
        readarray -t -d $'\n' changedFiles < <( command git diff --name-only )
        for changedFile in "${changedFiles[@]}"; do
            local lastFileTouchingCommit="$( git log --format='%H' --follow $startPoint..HEAD -- "$changedFile" | head -1 )"
            if test -n "$lastFileTouchingCommit"; then
                git add "$changedFile"
                if ! git commit -m "fixup ${lastFileTouchingCommit:0:9} ${changedFile##*/}"; then
                    echo 'Committing was not successful! Will quit now.' 1>&2
                    return 1
                fi
            fi
        done

        if ! command git diff --name-only --quiet || ! command git diff --cached --quiet; then
            git commit -a -m 'changed files which were not changed in any previous commit until the merge base'
        fi

        rebaseCommands="$( mktemp )"
        touch "$rebaseCommands"

        # output interactive rebasing instructions which can be copy-pasted into git rebase -i
        for commit in $( git log --reverse --format='%H' $startPoint..HEAD ); do
            local line="$( git log --format='%h %s' "$commit~1..$commit" )"
            if command grep -q -F "$line" "$rebaseCommands"; then
                continue
            fi

            printf 'pick %s\n' "$line" >> "$rebaseCommands"
            # find and append all fixup commits after it
            git log --format='%h %s' $commit..HEAD | command grep -F "fixup ${commit:0:9}" | sed 's|^|fixup |' >> "$rebaseCommands"
        done

        echo -e "Use git rebase -i with the following commit command list to apply the fixup commits at the correct parents\n" 1>&2
        cat "$rebaseCommands"
    )

    function gdt()
    {
        # "git duplicate touches" finds files in a given range which were modified more than once
        # and whose commits therefore might be a candidate for squashing
        local nCommits="$( git log --format='%h' "$@" | wc -l )"
        if test "$nCommits" -le 0; then
            echo "'git log --oneline $@' returned no commits"'!' 1>&2
            return 1
        fi

        local findMultipleModifiedFiles="$( mktemp --suffix='.py' )"
        cat <<EOF > "$findMultipleModifiedFiles"
#!/usr/bin/env python3

import sys, string

files = {}

currentCommit = None
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    if all( c in string.hexdigits for c in line ):
        currentCommit = line
        continue
    assert( currentCommit is not None )

    files[line] = files.setdefault( line, [] ) + [ currentCommit ]

commitOverlap = {}
for file, commits in files.items():
    if len( commits ) > 1:
        key = ' '.join( commits )
        commitOverlap[key] = commitOverlap.setdefault( key, [] ) + [ file ]

for commits, files in commitOverlap.items():
    print( len( commits.split( ' ' ) ), "commits (" + commits + ") modify the following files:" )
    for file in files:
        print( '    ' + file )
EOF

        git log --format='%h' --name-only "$@" | sed '/^$/d' | python3 "$findMultipleModifiedFiles"
        rm -- "$findMultipleModifiedFiles"
    }

    function grbi()
    {
        if test $# -eq 0; then
            git rebase -i "$( git merge-base master HEAD )"
        else
            git rebase -i "$@"
        fi
    }

    function findInBranches()
    {
        local branch range
        for branch in $( git rev-parse --symbolic --branches ); do
            range=$( git merge-base upstream/master $branch 2>/dev/null )..$branch
            if git log --oneline "$range" 2>/dev/null | 'grep' -q "$@"; then
                echo "Found matches in branch $branch:"
                git log --oneline "$range" | grep "$@"
            fi
        done
    }
fi

alias lc='locate -i'
alias sup='sudo apt-get update'
alias si='sudo apt-get install'
# go into old upper diretory on cd .., even if the current folder was moved e.g. to trash
# use command cd for original behavior. Unfortunately 'cd' does not work, because
# that only prevents alias lookup, not function lookup it seems (This also puts
# my usage of 'command' in scripts into persepctive :S
cd()
{
    if [ "$1" == '..' ]; then
        if [[ -z "${PWD%/*}" ]]; then
            command cd /
        else
            command cd "${PWD%/*}"
        fi
    else
        command cd "$@";
    fi
}

alias crawlSite='wget --limit-rate=200k --no-clobber --convert-links --random-wait --recursive --page-requisites --adjust-extension -e robots=off -U mozilla --no-remove-listing --timestamping'
alias gc='git reflog expire --expire=30d --all && git gc && git gc --aggressive --prune=now'
alias ..='cd ..'
# https://github.com/nvbn/thefuck
alias f=fuck

function fu()
{
    for file in "$@"; do
        fusermount -u -- "$file"
    done
}

function addToPath()
{
    local target=$1
    local toPrepend=$2

    if [[ ! -d $toPrepend ]]; then
        return 1;
    fi

    if [[ $target == PATH ]]; then
        if [[ ":$PATH:" != *":$toPrepend:"* ]]; then
            export PATH="$toPrepend:${PATH}"
        fi
    elif [[ $target == LIBRARY_PATH ]]; then
        if [[ ":$LIBRARY_PATH:" != *":$toPrepend:"* ]]; then
            export LIBRARY_PATH="$toPrepend:${LIBRARY_PATH}"
        fi
    elif [[ $target == LD_LIBRARY_PATH ]]; then
        if [[ ":$LD_LIBRARY_PATH:" != *":$toPrepend:"* ]]; then
            export LD_LIBRARY_PATH="$toPrepend:${LD_LIBRARY_PATH}"
        fi
    fi
}


function removeFromPath()
{
    local target=$1
    local toRemove=$2
    local ToRemoveEscaped regex

    toRemoveEscaped=$( printf %s "$toRemove" | sed -r 's|([][])|[\1]|g; s|([^][/])|[\1]|g; s|/|/+|g; s|/*(/[+])?$|/*|;' )
    regex='s#(^|:+)'"${toRemoveEscaped}"'(:+|$)#:#'

    if [[ $target == PATH ]]; then
        export OLD_PATH=$PATH
        export PATH=$( printf %s "$PATH" | sed -r "$regex" )
    elif [[ $target == LIBRARY_PATH ]]; then
        export OLD_LIBRARY_PATH=$LIBRARY_PATH
        export LIBRARY_PATH=$( printf %s "$LIBRARY_PATH" | sed -r "$regex" )
    elif [[ $target == LD_LIBRARY_PATH ]]; then
        export OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH=$( printf %s "$LD_LIBRARY_PATH" | sed -r "$regex" )
    fi
}

function installFolder()
{
    local folder="$1"
    if [[ ! -d "$folder" ]]; then
        echo -e "\e[31mCould not find folder '$folder' to export.\e[0m" 1>&2
        return 1
    fi

    if [[ -d "$folder/bin" ]]; then
        addToPath 'PATH' "$folder/bin"
    fi
    if [[ -d "$folder/lib" ]]; then
        addToPath 'LIBRARY_PATH' "$folder/lib"
        addToPath 'LD_LIBRARY_PATH' "$folder/lib"
    fi
    if [[ -d "$folder/lib64" ]]; then
        addToPath 'LIBRARY_PATH' "$folder/lib64"
        addToPath 'LD_LIBRARY_PATH' "$folder/lib64"
    fi

    # There is no global variable for include folders.
    # You have to use CMake or add it manually to compilations.

    return 0;
}

function uninstallFolder()
{
    removeFromPath 'PATH' "$1/bin"
    removeFromPath 'LIBRARY_PATH' "$1/lib"
    removeFromPath 'LIBRARY_PATH' "$1/lib64"
    removeFromPath 'LD_LIBRARY_PATH' "$1/lib"
    removeFromPath 'LD_LIBRARY_PATH' "$1/lib64"
}


# function keyword necessary if function name already is defined as an alias!

function splitImages(){
    local file
    for file in "$@"; do
        convert -crop 50%x100% "$file" "${file%.*}-%0d.${file##*.}";
    done
}

function prettyPrintSeconds(){
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

function sp()
{
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
    fi
    xfce4-session-logout --suspend &&
    sleep 10s && (
        # only necessary for NVIDIA driver bug ...
        #if lspci | 'grep' -i --color 'hdmi\|vga\|3d\|2d' | 'grep' -q -i nvidia; then
        if lshw -class display 2>/dev/null | 'grep' -q -i 'vendor: .*nvidia'; then
            refreshWallpaper;
            if command -v xfce4-panel &>/dev/null; then
                xfce4-panel -r
            fi
        fi
        if [ -n "$( pgrep hostapd )" ]; then
            sleep 2s
            startap
        fi
    )
}

function lb(){ locate -i -b '*'"$*"'*'; }

function up() {
    if [ "$1" -lt 256 ] 2>/dev/null; then
        for ((i=0;i<$1;i++)); do
            cd ..;
        done;
    fi
}

function echoerr() { echo "$@" 1>&2; }

function stringContains() {
    #echo "    String to test: $1"
    #echo "    Substring to test for: $2"
    [ -z "${1##*$2*}" ] && [ ! -z "$1" ]
}

# This function returns all links found in the given html-file.
# One link begins with http:// or https:// and ends on the first "-mark,
# because the format expected is: href="http://..."
# This function is independent of the site to crawl! The returned links need
# to be filtered differently depending on what to crawl. See filterUrls()
function getUrls() {
    sed -r 's|(<a href=")|\n\1|g' -- "$@" | sed -nr 's|^<a href="([^"]+)".*|\1|p; s| |%20|g;'
}

function getImageUrls() {
    sed -r 's|(src=")|\n\1|g' -- "$@" | sed -nr 's|^src="([^"]+)".*|\1|p; s| |%20|g;'
}

function getmac() {
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

function offSteamUpdates() {
    for lib in "$@"; do
        find "$lib" -name '*.acf' -execdir bash -c "
            if grep -q 'AutoUpdateBehavior.*\"[^1]\"' \"\$1\"; then
            "'  echo $(pwd)/{};
                sed -i -E'" 's|(AutoUpdateBehavior.*\")[^1]\"|\11\"|' '{}';
            fi;
        " bash {} \; ; done
}
function getLargestSide() {
    local w=$(convert "$1" -format "%w" info:)
    local h=$(convert "$1" -format "%h" info:)
    if [ "$w" -gt "$h" ]; then echo $w; else echo $h; fi
}

function makeIcon() {
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

function mvsed() {
    # $1 rule for sed how to work on file name
    local dryrun
    if [ "$1" == '-n' ]; then
        dryrun='echo'
        shift
    fi

    local sedCommand="$1"
    if [ -z "$sedCommand" ]; then
        cat <<EOF
mvsed [-n] <sed-rule>
 -n   dry-run, just show mv commands
EOF
        return
    fi

    if ! echo '' | sed -r "$sedCommand" 2>/dev/null; then
        echoerr "sed command '$sedCommand' seems to be invalid."
        # E.g. if sed rule is wrong
        return
    fi

    local tmpFile="$( mktemp )"
    find . -mindepth 1 -maxdepth 1 -print0 | sed -z 's|^\./||' | sed -z -E "$sedCommand" > "$tmpFile"
    if test "$( cat "$tmpFile" | tr -cd '\0' | wc -c )" -ne "$( sort -uz "$tmpFile" | tr -cd '\0' | wc -c )"; then
        echo "The renaming sed command '$sedCommand' is not bijective"'!' 1>&2
        echo 'There are overlapping target names, which leads to data loss!' 1>&2
        echo '' 1>&2
        echo 'Overlaps | Target Name' 1>&2
        sort -z "$tmpFile" | uniq -cz | sort -nz | sed -zE '/^ *1[ \t]+/d' | tr '\0' '\n'
        echo 'Will quit now. Please use "rm" to delete your files instead.' 1>&2
        return
    fi

    find . -mindepth 1 -maxdepth 1 -execdir bash -c '
        fname=$1
        fname=$( basename "$fname" ) # this strips the leading ./ and adds trailing / for directories, find doesnt give trailing /
        if [ -d "./$fname" ]; then fname=$fname/; fi
        newname=$( printf "%s" "$fname" | sed -r '"'$sedCommand'"' )
        if [ "$fname" != "$newname" ]; then
            if [ -n "'$dryrun'" ]; then
                '"printf \"mv '%s'\n-> '%s'\n\" "'"$fname" "$newname"
            else
                mkdir -p -- "$( dirname -- "./$newname" )"
                if test -e "./$newname"; then
                    echo "Will not move \"$fname\" -> \"$newname\" because the target already exists and data loss would ensue. Please delete the file manually as this script is just a renamer." 1>&2
                else
                    mv "./$fname" "./$newname"
                fi
            fi
        fi
    ' bash {} \;
}

function lac() {
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
            local name=$( echo "$line" |
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
    done < <( 'ls' --color -lah --group-directories-first "$@" )
}

function equalize-volumes() {
    local masterVolume sink
    masterVolume=$(amixer get 'Master' | sed -nr 's|.*\[([0-9]*%)\].*|\1|p' | head -1)
    for sink in $(pactl list sink-inputs | sed -nr 's/^Sink Input #(.*)/\1/p'); do
        pactl set-sink-input-volume $sink $masterVolume
    done
}

function githubSize() {
    # expects a github clone link, e.g. https://github.com/chrissimpkins/Hack.git
    echo "$1" |
        perl -ne 'print $1 if m!([^/]+/[^/]+?)(?:\.git)?$!' |
        xargs -i curl -s -k https://api.github.com/repos/'{}' |
        'grep' size |
        sed -nr 's|.*: ([0-9]*).*|\1 KB|p'
}

function colorinfo16() {
    for clbg in {40..47} {100..107} 49 ; do
        for clfg in {30..37} {90..97} 39 ; do
            for attr in 0 1 2 4 5 7 ; do
                echo -en "\e[${attr};${clbg};${clfg}m ^[${attr};${clbg};${clfg}m \e[0m"
            done
            echo
        done
    done
}

function  igcc() {
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
#include <bitset>
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
#include <regex>
#include <set>
#include <sstream>
#include <stdexcept>                            // invalid_argument
#include <stack>
#include <string>
#include <thread>
#include <typeinfo>
#include <type_traits>
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
    g++ tmp.cpp -std=c++17 -Wall -o a.out
    ./a.out
    local exitCode=$?
    rm -r "$folder"
    cd "$oldDir"
    return $exitCode
}

function o() { xdg-open "$*"; }

function downo() {
    local link
    for link in $@; do
        wget "$link"
        xdg-open "${link##*/}"
    done

}

alias getip='wget -q -O /dev/stdout http://checkip.dyndns.org/ | cut -d : -f 2- | cut -d \< -f -1'

function findPath()
{
    local path
    for path in "$@"; do
        if [ -f "$path" ]; then
            printf '%s' "$path"
            break
        fi
    done
}

function toUTF8()
{
    iconv -f ISO8859-15 -t UTF8 "$1" -o "$1".utf8
    echo -ne '\xEF\xBB\xBF' > "$1".utf8 && iconv -f ISO8859-15 -t UTF8 "$1" >> "$1".utf8
    trash "$1"
    mv --no-clobber "$1.utf8" "$1"
}

function splitCue()
{
    shnsplit -f "$1" -t '%n - %t' -o flac -- "${1%.cue}".[^c]*
}

function trash-empty()
{
    local mountpoint folder dry
    local ndays=$1
    if [ "$1" == '-d' ] || [ "$2" == '-d' ]; then dry=echo; fi

    local foldersToTry=()
    # Filtering the mount points is not that important because most of them would be filtered anyway
    # by checking for existence of mountPoint/.Trash folder.
    for mountpoint in $( cat /proc/mounts | sed -r '/(cgroup|devpts|hugetlbfs|mqueue|tmpfs|veracrypt) /d; / \/(boot|sys|proc)[/ ]/d; /^\/dev\/loop/d' | awk '{ print $2; }' ); do
        for folder in ".Trash/$UID" ".Trash-$UID" '$RECYCLE.BIN'; do
            foldersToTry+=( "$mountpoint/$folder" )
        done
    done

    if [ -d "$XDG_DATA_HOME" ]; then
        foldersToTry+=( "$XDG_DATA_HOME/Trash" )
    elif [ -d "$HOME" ]; then
        foldersToTry+=( "$HOME/.local/share/Trash" )
    fi

    for folder in "${foldersToTry[@]}"; do
        if [ -d "$folder" ]; then
            echo "Deleting '$folder/' ..." 1>&2
            if [ "$ndays" -eq "$ndays" ] 2>/dev/null && [ "$ndays" != 0 ] && [ -d "$folder/info/" ]; then
                # assuming that file modification date for .trashinfo files is the same as the DeletionDate stored inside that file
                # note that -mtime +0 will find all files older than 24h and +1 all files older than 2 days, ...
                find "$folder/info/" -mtime "+$(( ndays-1 ))" -name '*.trashinfo' -print0 |
                sed -rz "s|^(.*)/${folder//./\\.}/info/(.*)\.trashinfo$|\1$folder/info/\2.trashinfo\x00\1$folder/files/\2|" |
                xargs -0 $dry 'rm' -r
            else
                $dry command rm -rf "$folder/"
            fi
        fi
    done
}

# cleanes filename of files in current folder and its subdirectories
# no target directory or file argument possible at the moment
#
# ToDo: create list of files, run sed over this whole list instead of per each file name and then diff this .... Something like find -print0 | tee original.lst | sed -z '...' > changed.lst; diff {original,changed}.lst | xargs -0 -L3 -l3 ...

# takes piped input!
function cleanFilenames() {
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

function isodate() { date "$@" +%Y-%m-%dT%H-%M-%S; }

function hexdump()
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

function hexdiff()
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

function hexlinedump()
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

function hexdiff()
{
    # real	0m12.958s
    # user	0m18.908s
    # sys	0m0.564s
    colordiff <( hexlinedump 16 "${@: -2:1}" ) <( hexlinedump 16 "${@: -1:1}" )
}

function diffLines()
{
    if test $# -ne 3; then
        echoerr "Got $# instead of 3 arguments"'!'
        echo "Usage: diffLines <file> <sed command to extract first section> <sed command for second section>"
        echo "Suggestion for sed commands: '<start line number>,<end line number>p'"
        return 1
    fi

    local file="$1"
    if ! test -f "$file"; then
        echoerr "First argument must be file but is: $1"'!'
        return 1
    fi

    # @todo Ignore all space might be difficult. Maybe, allow supplying colordiff options in diffLines call?
    # use diff first because wdiff does not have --ignore-white-space
    # use wdiff --avoid-wraps because colordiff is too simple to understand multiline word diffs
    diff --unified --ignore-all-space <( sed -n -E "$2" "$file" ) <( sed -n -E "$3" "$file" ) | wdiff --diff-input --avoid-wraps | colordiff
}

function sourceWhitspaces()
{
    folder=$1
    tmp=$( mktemp )
    for file in "$folder"/*.cu "$folder"/*.?pp; do
        sed 's|[ \t]*$||g; s|\t|    |g; s|\r||g' -- "$file" > "$tmp"
        if ! diff "$tmp" "$file"; then # returns nonzero (no success) if they differ
            echo "Adjusted whitespaces in: $file" 1>&2
            command mv "$tmp" "$file"
        fi
    done
}

function dumpsysinfo()
{
    local file='sysinfo.log'
    if [ -n "$1" ]; then file=$1; fi
    touch "$file"
    local command commands=(
        'ifconfig'
        'ip route'
        'ip addr show'
        'uname -a'              # includes hostname as second word on line
        'lscpu'
        'lsblk'
        'lsusb'
        'lspci'
        'lspci -v'
        'lspci -t'
        'mount'
        'ps aux'
        'cat /proc/meminfo'
        'cat /proc/cpuinfo'
        'cat /proc/uptime'
        'cat /etc/hosts'
        'nvidia-smi'
        'nvidia-smi -q'
    )
    local path paths=(
        ''
        '/usr/local/bin'
        '/usr/local/sbin'
        '/usr/bin'
        '/usr/sbin'
        'bin'
        'sbin'
    )
    for command in "${commands[@]}"; do
        echo -e "\n===== $command =====\n" >> "$file"
        for path in "${paths[@]}"; do
            if commandExists $command; then
                $command 2>&1 >> "$file"
                break
            fi
        done
    done
}

function crawlTwitterData()
(
    # scroll to bottom (ctrl+end), save es HTML (on my system this takes several minutes) and call this bash function with that html file. Use the "No Image" addon to save time and bandwidth for this step.
    mkdir -p "$1-crawled"
    cp "$1" "$1-crawled"
    cd "$1-crawled"
    while read line; do
        if [ "${line:0:4}" != 'http' ]; then
            sTime="$line"
        elif [ ! -f "$sTime-${line##*/}" ]; then
            wget -O "$sTime-${line##*/}" "${line}:large"
            sleep 1s
        fi
    done < <( sed -nr ' s|.*data-image-url="([^"]*)".*|\1|p;
                        s|.*data-time="([^"]*)".*|\1|p;' -- "$1" )
    # crawlTwitterData 'Twitter Name | Twitter9.html'
)

function sqlToCsv()
(
    # also included in 'extract' command
    # https://github.com/darrentu/convert-db-to-csv/blob/master/convert-db-to-csv.sh
    local fname=$1
    local folder=${fname%.*}
    mkdir -p "$folder" && cd "$folder"
    local table tables=( $( sqlite3 "$1" .tables ) )
    for table in "${tables[@]}"; do
        sqlite3 "$1" <<EOF
.mode csv
.headers on
.output $table.csv
SELECT * FROM $table;
.exit
EOF
    done
    cd ..
)

function getOpenTabs()
{
    local profile=$( sed -n -r -z 's|.*Path=([^\n]*)\nDefault=1.*|\1|p' "$HOME/.mozilla/firefox/profiles.ini" )
    # https://github.com/avih/dejsonlz4/blob/master/src/dejsonlz4.c
    dejsonlz4 "$HOME/.mozilla/firefox/$profile/sessionstore-backups/recovery.jsonlz4" |
        jq -c '.windows[].tabs[].entries[-1].url' |
        sed 's|^"||; s|"$||;' |
        xclip -selection c
}

function getffpasswords()
{
    local profile=$( sed -n -r -z 's|.*Path=([^\n]*)\nDefault=1.*|\1|p' "$HOME/.mozilla/firefox/profiles.ini" )
    # si pass && pass init defaultGpgID
    local iProfile=$( ~/bin/firefox_decrypt/firefox_decrypt.py --list | 'grep' -F "$profile" | sed -n -r 's|^([0-9]+) -> .*|\1|p;' | head -1 )
    ( read -sp "Master Password: " PASSWORD && printf '%s' "$PASSWORD" | python3 ~/bin/firefox_decrypt/firefox_decrypt.py --export --no-interactive --choice "$iProfile" )
}

# https://unix.stackexchange.com/a/4529/111050
function stripColors(){ perl -pe 's/\e\[?.*?[\@-~]//g'; }
function stripControlCodes(){ perl -pe 's/\e\[[\d;]*m//g'; }


function resolveAptHosts()
{
    mapfile -t hosts < <(
        sed -n -r '/^#/d; s;deb(-src)? (http://|ftp://)?([^/ ]+).*;\3;p'\
        /etc/apt/sources.list | sort | uniq )
    # delete all hosts from /etc/hosts, e.g., from an earlier call
    sudo sed -i -r '/^[0-9]{1,3}(\.[0-9]{1,3}){3}[ \t]+('"$( printf '|%s'\
        "${hosts[@]//./\\.}" | sed 's/^|//' )"')[ \t]*$/d' /etc/hosts
    for host in ${hosts[@]}; do
        ip=$( nslookup "$host" | sed -n -r 's|Address:[ \t]*([0-9.]+).*|\1|p' |
              tail -1 )
        sudo bash -c "echo $ip $host >> /etc/hosts"
    done
}

function refreshPanels()
{
    # fixes: https://bugzilla.xfce.org/show_bug.cgi?id=10725
    for plugin in $( xfconf-query -c xfce4-panel -lv | 'grep' tasklist | cut -f1 -d' ' ); do
        xfconf-query -c xfce4-panel -p $plugin/include-all-monitors -s true
        xfconf-query -c xfce4-panel -p $plugin/include-all-monitors -s false
    done
}

function getCurrentScreen()
{
    # Returns Monitor ID to be used with 'xrandr --output $monitorID'
    # https://superuser.com/a/992924/240907
    eval "$( xdotool getmouselocation --shell )" # sets X and Y variables
    monitor=
    while read name width height xoff yoff; do
        if [ "${X}" -ge "$xoff" -a "${X}" -lt "$(($xoff+$width))" -a \
             "${Y}" -ge "$yoff" -a "${Y}" -lt "$(($yoff+$height))" ]; then
            monitor=$name; break
        fi
    done < <( xrandr --current | sed -n -r 's|(.+) .*connected.* (([0-9]+[x+]){3}[0-9]+).*|\1 \2|p' | sed 's|[x+]| |g' )
    printf '%s' "$monitor"
}

function openUrls()
{
    while read line; do
        xdg-open "$line" 2>/dev/null
    done < <( xclip -o )
}

alias op=openUrls

function demuxStreams()
{
    local file="$1"
    if ! test -f "$file"; then
        echo "Given file does not exist: $file"
        return 1
    fi

    local i indexCodecs=( $( ffprobe -loglevel warning -show_streams "$file" | sed -nE 's/^(index|codec_name|TAG:language)=//p;' ) )
    for (( i=0; i < ${#indexCodecs[@]}; ++i )); do
        # load codec and language spefication if exists from list, knowing that language shouldn't be numeric but IDs are
        local id="${indexCodecs[i]}" codec= numberRegex='^[0-9]+$'
        local fname="$file.$id"
        if [[ $(( i + 1 )) -lt ${#indexCodecs[@]} && ! ${indexCodecs[i+1]} =~ $numberRegex ]]; then
            (( ++i ))
            codec="${indexCodecs[i]}"
            if [[ $(( i + 1 )) -lt ${#indexCodecs[@]} && ! ${indexCodecs[i+1]} =~ $numberRegex ]]; then
                (( ++i ))
                fname="$fname.${indexCodecs[i]}"
            fi
            fname="$fname.$codec"
        fi
        ffmpeg -loglevel warning -i "$file" -map 0:"$id" -codec copy "$fname"
    done
}

if commandExists scite; then
function scite()
{
    # goto command documented here: https://www.scintilla.org/SciTEDoc.html
    if test $# -eq 1; then
        if [[ $1 =~ :[0-9]*$ ]]; then
            local line="${1##*:}" file="${1%:*}"
            if test -f "$file"; then
                command scite "$file" -goto:"$line" 2>/dev/null
                return
            fi

            local line="${file##*:}" file="${file%:*}"
            if test -f "$file"; then
                command scite "$file" -goto:"$line" 2>/dev/null
                return
            fi
        fi
    fi

    # See man dbus-launch
    # If you run dbus-launch myapp (with any other options), dbus-daemon will not exit when myapp terminates:
    # this is because myapp is assumed to be part of a larger session, rather than a session in its own right.
    # https://access.redhat.com/solutions/3257651
    # TODO Correctly close down dbus-launch started session!
    # dbus-launch not necessary anymore after this fix: https://askubuntu.com/a/1350804/437748
    #dbus-launch scite "$@"
    command scite "$@" 2>/dev/null
}
fi

alias s=scite


function dcat()
{
    local sizeB sizeMiB offsetMiB fileName

    fileName=$1
    if [[ ! -f $fileName ]]; then return 1; fi

    sizeB=$( stat --format='%s' -- "$fileName" ) # bytes
    sizeMiB=$(( ( $sizeB + 1024*1024 - 1 ) / ( 1024*1024 ) )) # ceil( Bytes / MiB )

    for (( offsetMiB = 0; offsetMiB < $sizeMiB; ++offsetMiB )); do
        dd bs=1M skip=$offsetMiB count=1 if="$fileName" 2> /dev/null
        fallocate --punch-hole --offset="$offsetMiB"MiB --length=1MiB -- "$fileName"
    done
}


function urldecode() {
    python3 -c "import sys; from urllib.parse import unquote; print( unquote( sys.stdin.read() ) );"
}


function rand()
{
    # rand [[<smallest>] <largest>]
    # returns integer in [smallest,largest]
    # The default corresponds to [0,2^30-1]

    # RANDOM only returns a number in [0,2^15-1], therefore combine two for gerater accuracy for large subranges
    local u30r=$(( RANDOM * 65536 + RANDOM ))
    if [[ $# -eq 0 ]]; then
        echo $u30r
        return 0;
    fi

    local start=0
    local end=$(( 2**32 - 1 ))
    if [[ $# -eq 1 ]]; then
        end=$1
    elif [[ $# -eq 2 ]]; then
        start=$1
        end=$2
    else
        echo "Too many arguments given!" 1>&2
        return 1
    fi

    if [[ ! ( ( $start =~ ^[0-9+-]+$ ) && ( $end =~ ^[0-9+-]+$ ) ) ]]; then
        echo "Arguments must be integers!" 1>&2
    fi

    echo $(( u30r % ( end - start + 1 ) + start ))
}


function startBackground()
{
    local launcher
    case "$1" in
        dbus-launch)
            launcher=$1
            shift
            ;;
    esac

    if [[ -z "$1" ]]; then echoerr "First argument must be program to start"; return 1; fi
    if ! checkCommand "$1"; then echoerr "First argument must be an existing binary or command"; return 1; fi
    if pgrep --full "$1" 1>/dev/null; then echoerr "$1 already running"; return 0; fi
    name=$( basename -- "$1" )
    # use dbus-launch because of the obnoxious bug where programs hang when trying to display the file open dialog REEEEEE!
    nohup $launcher "$@" 1>"$HOME/logs/$name.out" 2>"$HOME/logs/$name.err" &
}


function createMultiFrameZstd()
{
    local file frameSize fileSize offset frameFile
    # Detect being piped into
    if [ -t 0 ]; then
        file=$1
        frameSize=$2
        if [[ ! -f "$file" ]]; then echo "Could not find file '$file'." 1>&2; return 1; fi
        fileSize=$( stat -c %s -- "$file" )
    else
        if [ -t 1 ]; then echo 'You should pipe the output to somewhere!' 1>&2; return 1; fi
        echo 'Will compress from stdin...' 1>&2
        frameSize=$1
    fi
    if [[ ! $frameSize =~ ^[0-9]+$ ]]; then
        echo "Frame size '$frameSize' is not a valid number." 1>&2
    fi

    # Create a temporary file. I avoid simply piping to zstd
    # because it wouldn't store the uncompressed size.
    if [[ -d /dev/shm ]]; then frameFile=$( mktemp --tmpdir=/dev/shm ); fi
    if [[ -z $frameFile ]]; then frameFile=$( mktemp ); fi
    if [[ -z $frameFile ]]; then
        echo "Could not create a temporary file for the frames." 1>2
        return 1
    fi
    trap "'rm' -- '$frameFile'" EXIT

    if [ -t 0 ]; then
        > "$file.zst"
        for (( offset = 0; offset < fileSize; offset += frameSize )); do
            dd if="$file" of="$frameFile" bs=$(( 1024*1024 )) \
               iflag=skip_bytes,count_bytes skip="$offset" count="$frameSize" 2>/dev/null
            zstd -c -q -f --no-progress -- "$frameFile" >> "$file.zst"
        done
    else
        while true; do
            dd of="$frameFile" bs=$(( 1024*1024 )) \
               iflag=count_bytes count="$frameSize" 2>/dev/null
            # pipe is finished when reading it yields no further data
            if [[ ! -s "$frameFile" ]]; then break; fi
            zstd -c -q -f --no-progress -- "$frameFile"
        done
    fi
}

alias make='make -j $( nproc )'

function build()
{
    local prefix
    # Triggers https://bugreports.qt.io/browse/QTBUG-61710
    # -> Seems to work now with Vampir 10.1, Qt 6.2.2, mold 1.1.1, and clang 14.0.0
    if commandExists mold; then
        prefix='mold --run'
    fi

    if [ -f CMakeCache.txt ]; then
        $prefix cmake --build . --parallel $( nproc ) -- "$@"
    elif [ -f Makefile ]; then
        $prefix 'make' -j "$( nproc )" "$@"
    elif [ -f build.ninja ]; then
        $prefix ninja "$@"
    elif [ -f Cargo.toml ]; then
        cargo build "$@"
    else
        echo 'Could not determine a suitable build command!' 1>&2
    fi
}


function buildRepository()
(
    if [[ -f CMakeLists.txt ]]; then
        mkdir -p build
        cd build
        if commandExists ninja; then
            cmake -GNinja -DCMAKE_BUILD_TYPE=Release ..
        else
            cmake ..
        fi
    elif [[ -x configure ]]; then
        ./configure
    elif [[ -x autogen.sh ]]; then
        ./autogen.sh
        ./configure
    elif [[ -x configure.py ]]; then
        python3 configure.py
    fi

    build
)


alias n=ninja
alias m=build
alias nb='build beautify'

alias c='CXX=clang++-19 CC=clang-19 cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G Ninja -DCMAKE_COLOR_DIAGNOSTICS=ON ..'
#function c()
#{
#    local gitRoot
#    gitRoot=$( git rev-parse --show-toplevel )
#    CXX=clang++-14 CC=clang-14 cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G Ninja -DLICENSE=None -DCMAKE_CXX_FLAGS="-ffile-prefix-map=$gitRoot=$( realpath --relative-to="$PWD" "$gitRoot" )" "$@"
#}


function ma()
{
    # The gvfs mtp service interferes when trying to use go-mtpfs
    # Also don't use caja for file transfers. Connection aborts seem to be very frequent when using it.
    # However a simple 'cp' works just fine ... Shite MTP support
    # pkill gvfsd-mtp
    # pkill gvfs-mtp-volume-monitor

    local mountDir='/media/phone'
    if [ "$1" == '-x' ]; then
        fusermount -u "$mountDir"
        return 0
    fi
    mkdir -p "$mountDir"
    if mount | 'grep' -q "$mountDir"; then
        # this also generally exits old go-mtpfs processes
        fusermount -u "$mountDir"
        sleep 2s
    fi
    go-mtpfs "$mountDir" &
}

function killpc()
{
    sudo bash -c "echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger"
}
alias hardshutdown='killpc'

function setLanguage() {
    local LC
    for LC in LC_{CTYPE,NUMERIC,TIME,COLLATE,MONETARY,MESSAGES,PAPER,NAME,ADDRESS,TELEPHONE,MEASUREMENT,IDENTIFICATION}; do
        export ${LC}="en_US.UTF-8"
    done
}

function lgb()
(
    if [ -d "$1" ]; then cd -- "$1"; fi
    # character lengths for the columns to be shown
    local nFolder=30
    local nBranch=20
    local nMessage=$(( $( tput cols ) - 2 - nFolder - nBranch ))

    for folder in */; do
        if [ -e "$folder/.git" ]; then
        (
            cd "$folder"
            if [ "$nMessage" -ge 10 ]; then
                printf "%-${nFolder}s %-${nBranch}s %-$nMessage.${nMessage}s\n" "$folder" "$( git rev-parse --abbrev-ref HEAD )" "$( git log -1 --pretty=%B | head -1 )"
            else
                printf "%-${nFolder}s %-${nBranch}s\n" "$folder" "$( git rev-parse --abbrev-ref HEAD )"
            fi
        )
        fi
    done
)

function sgrep()
{
    # open all matching files in scite @todo or another arbitrary program
    local fileNames=()
    readarray -t -d $'\n' fileNames < <( command grep --files-with-matches "$@" )
    if test "${#fileNames[@]}" -gt 0; then
        nohup scite "${fileNames[@]}" -find:"${@: -2:1}" &> "$( mktemp --suffix=.scite.log )" &
    else
        echo "No matching files found." 1>&2
    fi
}

function omc()
{
    local fileName fileNames absoluteNames=()
    readarray -t -d $'\n' fileNames < <( git diff --name-only --diff-filter=U )
    local topLevel="$( git rev-parse --show-toplevel )"
    for fileName in "${fileNames[@]}"; do
        absoluteNames+=( "$topLevel/$fileName" )
    done
    nohup scite "${absoluteNames[@]}" -find:'<<<<' &>/dev/null &
}

alias x='extract'

function getPdfTitle() { pdfinfo "$@" | sed -nr 's|^Title:[ \t]*||p'; }
# E.g., for file in *pdf; do mv "$file" "$( getPdfTitle "$file" | cleanFilenames )".pdf; done


# Completion for aliases

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

completeAliasScript="$( dirname -- "$BASH_SOURCE" )/complete-alias/complete_alias"
if [[ -f $completeAliasScript ]]; then
    . "$completeAliasScript"
fi

for aliasToComplete in $( alias -p | sed -n -E "s;^alias ([A-Za-z0-9]+)='(git|ls|cp|mv|make|ninja|tar) .*;\1;p" ); do
    complete -F _complete_alias "$aliasToComplete"
done

for aliasToComplete in si make; do
    complete -F _complete_alias "$aliasToComplete"
done


function confirm()
{
    # This is a general-purpose function to ask Yes/No questions in Bash, either
    # with or without a default answer. It keeps repeating the question until it
    # gets a valid answer. @see https://djm.me/ask
    # Usage: echo -n "Do you want to..?"; confirm -[yn]
    local prompt default reply
    while true; do
        if   [ "$1" = "-y" ]; then prompt="Y/n"; default=Y
        elif [ "$1" = "-n" ]; then prompt="y/N"; default=N
        else                       prompt="y/n"; default=
        fi

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n " [$prompt] "
        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty
        # Default?
        if [ -z "$reply" ]; then reply=$default; fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}


function watchSync() {
  watch -n1 'grep -E "(Dirty|Write)" /proc/meminfo; echo; ls /sys/block/ | while read device; do awk "{ print \"$device: \"  \$9 }" "/sys/block/$device/stat"; done'
}
