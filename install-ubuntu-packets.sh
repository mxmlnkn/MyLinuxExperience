#!/bin/bash
# installed debs are in /var/cache/apt/archives
# show installed: /var/log/dpkg.log  /var/log/apt/history.log  $(dpkg --get-selections "*")
# search installed dpkg-query -l '*wicd*"
# see also /var/cache/apt/archives/

sudo apt-get update

# https://www.veracrypt.fr/en/Downloads.html
# https://www.rainlendar.net/cms/index.php?option=com_rny_download&Itemid=30
# https://www.xfce-look.org/p/1171748/
# https://riot.im/download/desktop/
# https://discordapp.com/download
# https://freefilesync.org/download.php
# https://www.opera.com/download
# https://www.google.com/chrome/
# https://jdownloader.org/jdownloader2
# https://developer.nvidia.com/cuda-downloads
# https://cmake.org/download/
#   dpkg -l '*nvidia*' | grep ii # check installed version and then check for compatibility here:
#   https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html
#   sudo ln -s $( which g++-8 ) "$( dirname -- $( which nvcc ) )"/g++
#   sudo ln -s $( which gcc-8 ) "$( dirname -- $( which nvcc ) )"/gcc

packagelistsid=(
    wmctrl

    # printer prerequesite
    xsltproc

    # hexdump, ... might be linux-tools-common on ubuntu?
    coreutils bsdmainutils moreutils geoip-bin htop cpulimit cpuinfo read-edid anacron rfkill trash-cli strace

    x11-apps screenruler # xclock for testing
    libcdio-utils

    # Programming toolchain
    gcc g++ gdb clang clang-tidy ccache ninja-build mold heaptrack
    # heaptrack-gui  # Bit of dependency bloat because fall the KDE libkf5* dependencies
    python3 ipython3 python3-pip cython3

    steam gimp audacity xdotool lynx ristretto webp-pixbuf-loader pngtools scite meld pdftk vim kazam scrot
    caja sharutils jq vlc libaacs0 libbluray* smplayer mplayer thunderbird xul-ext-lightning galculator gdmap
    sqlite3 fancontrol wipe exiftool jpeginfo remmina guvcview mupdf

    fonts-dejavu fonts-firacode ttf-bitstream-vera ttf-unifont unifont-bin fonts-symbola

    # sable-theme builds upon this theme, this is why it's needed
    #gtk2-engines-murrine gtk2-engines-pixbuf gnome-themes-standard gtk-theme-switch lxappearance
    adwaita-qt* gnome-themes-extra

    # WLAN
    wireless-tools

    doc-base elfutils

    # networking: hostapd (Create WiFi Access Point)
    hostapd iw isc-dhcp-server haveged # firmware-atheros firmware-realtek firmware-iwlwifi
    # conky/conky-manager prerequesites
    lm-sensors xsensors psensor curl hddtemp dmidecode conky conky-all arandr cpuid
    # install new window manager to prevent tearing
    compton

    # cmake newest + dependents
    cmake cmake-doc cmake-qt-gui cmake-curses-gui hexchat qbittorrent ninja-build

    # SSH Server
    #openssh-server fail2ban
    # networking
    hostname openssh-client sshfs ntp ntpdate dhcpdump tcpdump dnsutils ftp nmap
    # needed for extract macro function
    zip unzip cabextract p7zip p7zip-full lzma rar unrar zipmerge tnef unace unalz unar arj lzop ncompress rzip
    # parallel compression tools
    pixz plzip pigz pbzip2 lbzip2 lrzip lzip bsdtar libarchive-tools tabix isal

    # Programming toolchain
    lsof colordiff wdiff valgrind cppcheck doxygen doxygen-doc graphviz mercurial git git-lfs git-doc gitk subversion subversion-tools

    # audio control (weird dependendencies would remove gparted and inkscape on upgrade ... -.- )
    pavucontrol gparted inkscape flashplugin-nonfree
    # Battery / power tools
    tlp

    # Tools
    # https://launchpad.net/pidgin-character-counting
    # http://3d.benjamin-thaut.de/?p=12
    duf tree powertop iotop sysstat iptraf nethogs speedometer hwinfo lshw lsscsi procps bsdutils

    #wine64-preloader wine wine64 wine32 libwine:i386 pv
    # requirements for ZKanji
    wine fonts-ipa*

    # XFCE
    xfce4 xfce4-terminal xfce4-timer-plugin thunar-archive-plugin xfce4-screenshooter xfce4-taskmanager xfce4-clipman-plugin xfce4-datetime-plugin xfce4-netload-plugin xfce4-wavelan-plugin xfce4-whiskermenu-plugin xfce4-xkb-plugin xfce4-goodies xfce4-mount-plugin xfce4-pulseaudio-plugin xfburn wodim
    xfwm4-themes gtk3-engines-xfce slick-greeter xscreensaver

    # ntfs read write support, necessary for truecrypt volumes !!
    ntfs-3g
    firmware-linux-nonfree firmware-linux-free
    # data recovery
    testdisk disktype scalpel
    # printer prerequesite
    lsb system-config-printer sane
    # aplay for timerle script
    alsa-utils xloadimage

    # seems to be in repo now (nonfree repo?)
    ffmpeg audacious

    ibus ibus-anthy qrencode qtqr memtop xzoom vorbistools cuetools shntool gpick gcolor2 wireshark wireshark-qt
    time

    ###### documentation (partially this means manuals) ######
    # generated with:
    #   for package in ${packagelist[*]}; do
    #       if apt-cache search $package-doc | grep -q $package-doc; then
    #           echo -n "$package-doc ";
    #       fi
    #   done
    # and then hand selected useful docs

    # science for siunitx, pictures for includegraphics and tikz => ~350mb download!
    texlive-latex-recommended texlive-science texlive-science-doc texlive-pictures texlive-pstricks texlive-xetex
    # german for ngerman, fonts-recommended for ecrm1000 for uniinput.dtx
    texlive-lang-german texlive-fonts-recommended texlive-bibtex-extra lmodern
    # for animate,tcolorbox,esint,multirow,bbm,cancel,tensor,braket packages; large packet!
    texlive-latex-extra
    # for Mnsymbol which was for sumint; large packet!
    texlive-fonts-extra
    # prerequisite for octave and TUBAF-Latex-Style
    texlive-lang-greek
    # texlive documentation
    texlive-latex-recommended-doc texlive-science-doc texlive-pictures-doc texlive-pstricks-doc texlive-fonts-recommended-doc texlive-latex-extra-doc texlive-fonts-extra-doc
    # nice GUI editor
    texmaker hunspell-en-gb myspell-de-de hunspell-de-de-frami

    # LibreOffice
    libreoffice-common libreoffice-core libreoffice-pdfimport libreoffice-l10n-de libreoffice-help-de hyphen-de myspell-de-de mythes-de libreoffice-help-en-us libreoffice-writer libreoffice-impress

    #marble-qt # 3D offline globe
    virtualbox-qt virtualbox virtualbox-guest-utils virtualbox-guest-additions-iso

    #gimagereader tesseract-ocr-jpn tesseract-ocr-jpn-vert

    cups imagemagick imagemagick-common

    pv progress parallel aptitude net-tools zenity efibootmgr gfio fio conky libncurses5 gsmartcontrol
    tidy calibre memtester bless bash shellcheck oathtool

    # Because Ubuntu didn't ship an OOM-killer in the past and the default one in 22.04 is shit and kills my whole X session
    earlyoom

    # For setfattr used in my setIcons script
    attr
)

for package in "${packagelistsid[@]}"; do
    echo "Install '$package'"
    sudo apt-get install --yes "$package" #-t sid
    sudo apt-get -f install
done
sudo apt-get autoremove

gsettings set org.gnome.desktop.interface color-scheme prefer-dark

# Install Python packages only after (possibly) upgrading Python
pip3 install --user --upgrade pip
python3 -m pip install --user --upgrade matplotlib numpy virtualenv ratarmount scipy pylint setuptools requests lxml weasyprint beautifulsoup4 jupyter jupyter_contrib_nbextensions pillow grip thefuck
jupyter contrib nbextension install --user


# https://askubuntu.com/questions/1341909/file-browser-and-file-dialogs-take-a-long-time-to-open-or-fail-to-open-in-all-ap/1350804#1350804
#sudo mv /usr/libexec/gvfsd-trash{,.bak}
# Hopefully fixed by 2025

trashPackages=(
    # snap pollutes mountpoints, memory, and everything and is slow, who would want that. flatpak is not much better
    flatpak snapd
    # Kills X session when out of memory. At that point I can also fully restart. Absolutely useless!
    systemd-oomd
    gnome-online-accounts
    # Currently, I only have ubuntu-desktop installed but maybe next time do a clean install with xubuntu-desktop instead!
    tracker ubuntu-pro* accountsservice-ubuntu-schemas gnome-*
    postfix
)

for package in "${trashPackages[@]}"; do
    sudo apt purge --yes "$package"
done

# Reinstall some tools that depended on lightweight gnome stuff.
# Evince wants gnome-desktop3-data libgnome-desktop-3-20t64
sudo apt install evince


# Memory leak problems. They take up >2 GB after a month or so and are only needed for flatpak, which I don't use
sudo mv /usr/libexec/xdg-desktop-portal{,.bak}
sudo mv /usr/libexec/xdg-desktop-portal-gtk{,.bak}

# Fucking tracker using up resource unnecessarily
systemctl --user mask tracker-extract-3.service tracker-miner-fs-3.service tracker-miner-rss-3.service tracker-writeback-3.service tracker-xdg-portal-3.service tracker-miner-fs-control-3.service
tracker3 reset -s -r
# Other fucking obnoxious Ubuntu bloat
sudo systemctl disable --now update-notifier-download
sudo systemctl disable --now update-notifier-download.timer
sudo systemctl disable --now update-notifier-motd.timer


# hold some largish rarely used packages for traffic reason
#sudo apt-mark hold libreoffice* texlive*

exit



More programs installed manually in /opt/
    FoxitReader
    sudo dpkg -i conky-manager-latest-amd64.deb

    Steam:
        wget http://repo.steampowered.com/steam/archive/precise/steam_latest.deb
        sudo dpkg -i steam_latest.deb
        sudo apt-get install -f
        or: sudo apt install steam_latest.deb

    FreeFileSync: http://www.fosshub.com/FreeFileSync.html -> extract to /opt/
    Thunderbird Notifications: https://addons.mozilla.org/en-US/thunderbird/addon/firetray/
    Latex Uniinput:
        wget http://www.eigenheimstrasse.de/neo/neo-bzr/latex/Neo.tex
        wget http://www.eigenheimstrasse.de/neo/neo-bzr/latex/README.rxr
        wget http://www.eigenheimstrasse.de/neo/neo-bzr/latex/uniinput.dtx
        wget http://www.eigenheimstrasse.de/neo/neo-bzr/latex/uniinput.ins
        latex uniinput.ins
        pdflatex uniinput.dtx
        kpsewhich -var-value=TEXMF
        kpsewhich -var-value=TEXMFHOME
        vim /usr/share/texlive/texmf-dist/web2c/texmf.cnf # locate texmf.cnf
            TEXMFHOME = ~/.texmf  # instead of ~/texmf
        mkdir -p $(kpsewhich -var-value=TEXMFHOME)/tex/latex/local
        cp uniinput.sty $(kpsewhich -var-value=TEXMFHOME)/tex/latex/local
        #texhash # or mktexlsr # not necessary on newer texlive versions
    Firefox (Do not like iceweasel or snap):
        https://download.mozilla.org/?product=firefox-esr-latest-ssl&os=linux64&lang=en-US
        from: https://www.mozilla.org/en-US/firefox/new/
    manually add manual programs to applications menu through entry in: /usr/share/applications
    JDownloader2

    Docker:
        https://docs.docker.com/engine/install/ubuntu/

        # Add Docker's official GPG key:
        sudo apt-get update
        sudo apt-get install ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        # Add the repository to Apt sources:
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    Chrome:
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo dpkg -i google-chrome-stable_current_amd64.deb

sudo apt-get purge xterm

# Could not connect to wicd's D-Bus interface. Check the wicd log for error messages.
#   - make sure you actually have wicd installed and not only wicd-gtk or try
#   - sudo bash -c "service wicd stop; dpkg-reconfigure wicd; sudo service wicd start"

# Scite theme fallback ... use darktheme in xfce4-appearance-settings ... still doesn't work perfect...

git clone --depth 1 https://github.com/junegunn/fzf.git "$XDG_DATA_HOME/fzf"
"$XDG_DATA_HOME/fzf/install" --xdg
