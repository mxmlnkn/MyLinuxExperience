#!/bin/bash
# install-gracefuk-logout.sh
# This script installs the .desktop links needed for the yad-Skript to work
# and also missing icons (doesn't overwrite existing icons)

configPath="$HOME/.config/graceful-logout"
mkdir -p "$configPath"
cd "$configPath"

################ copy icons to currently activated icon theme ################

wget 'https://github.com/daniruiz/Super-Flat-Remix/files/54449/icons.zip'
unzip -o icons.zip && rm icons.zip
iconNames=( "logout" "reboot" "shutdown" "suspend" "hibernate" "lock-screen" )

# ~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml:    <property name="IconThemeName" type="string" value="sable-ultra-flat-icons"/>
iconTheme=$(sed -rn 's/^.*IconThemeName.*value="([^"]*)".*/\1/p' $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml)
targetDir=""
if [ -d "/usr/share/icons/$iconTheme/" ]; then targetDir="/usr/share/icons/$iconTheme"; fi
if [ -d "$HOME/.icons/$iconTheme/"     ]; then targetDir="$HOME/.icons/$iconTheme"; fi

# copy files to icon theme, but don't overwrite existing icons
for icon in "${iconNames[@]}"; do
    fname="system-$icon.svg"
    targetIcon="$targetDir/apps/scalable/$fname"
    if [ ! -f "$targetIcon" ]; then
        echo "create $targetIcon"
        cp --no-clobber "$fname" "$targetIcon"
    fi
    rm $fname
    targetIcon="$targetDir/apps/scalable/xfsm-$icon.svg"
    if [ ! -f "$targetIcon" ]; then
        echo "create $targetIcon"
        ln -s -T "$targetDir/apps/scalable/$fname" "$targetIcon"
    fi
done

################ create .desktop files ################

names=( "Logout" "Reboot" "Shutdown" "Suspend" "Hibernate" "Lock" )
closeCmd="gracefully-close-windows && xfce4-session-logout --fast"
execs=( "$closeCmd --logout" "$closeCmd --reboot" "$closeCmd --halt"
        "xfce4-session-logout --suspend" "xfce4-session-logout --hibernate"
        "xflock4" )

for ((i=0; i<${#names[@]}; i++ )); do
    lowercaseName=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    fileName="$configPath/0$i-$lowercaseName.desktop"
    cat > "$fileName" << EOF
[Desktop Entry]
Name=${names[i]}
Comment=${names[i]} system
Exec=${execs[i]}
Icon=system-${iconNames[i]}
Termina=false
Type=Application
EOF
    chmod a+x "$fileName"
done

################ change xfce-whiskermenu logout command to script ################

#~/.config/xfce4/panel/whiskermenu-5.rc:command-logout=~/bin/graceful-logout
sed -ir 's/^command-logout=.*/command-logout=$HOME/bin/graceful-logout/' "$HOME/.config/xfce4/panel/whiskermenu-5.rc"

