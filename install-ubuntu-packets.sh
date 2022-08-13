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

pip3 install --user --upgrade pip
python3 -m pip install --user --upgrade matplotlib numpy virtualenv ratarmount scipy pylint setuptools requests lxml weasyprint beautifulsoup4 jupyter jupyter_contrib_nbextensions pillow grip
jupyter contrib nbextension install --user

packagelistsid=(
    # For Vampir
    otf-trace libotf-trace-dev libssl-dev

    wkhtmltopdf pandoc wmctrl

    # printer prerequesite
    xsltproc

    # hexdump, ... might be linux-tools-common on ubuntu?
    coreutils bsdmainutils moreutils geoip-bin htop cpulimit cpuinfo read-edid

    x11-apps screenruler # xclock for testing
    libcdio-utils

    # Programming toolchain
    gcc gfortran g++ g++-8 g++-9 gdb clang clang-tidy libopenmpi-dev openmpi-bin openmpi-common openmpi-doc gnuplot perl uncrustify heaptrack # heaptrack-gui libboost-all-dev
    python3 ipython3 python3-pip cython3

    steam gimp audacity xdotool lynx telegram-desktop ristretto webp-pixbuf-loader pngtools scite meld pdftk vim kazam scrot caja sharutils jq vlc libaacs0 libbluray* smplayer mplayer thunderbird xul-ext-lightning galculator gdmap sqlite3 fancontrol wipe exiftool jpeginfo
    #filezilla optipng libtiff-tools libtiff5 libtiff-doc libtiff5-dev libtiffxx5 secure-delete openjdk-7-jre openjdk-7-jdk icedtea-7-plugin evince qpdf xchm
    fonts-dejavu ttf-bitstream-vera ttf-unifont unifont-bin fonts-symbola
    # times new roman and so in in libreoffice
    ttf-mscorefonts-installer

    #pavumeter pavucontrol
    # sable-theme builds upon this theme, this is why it's needed
    #gtk2-engines-murrine gtk2-engines-pixbuf gnome-themes-standard gtk-theme-switch lxappearance

    # WLAN
    wireless-tools

    doc-base elfutils

    #xorg x11-xfs-utils xorg-docs xclip libhdf5-doc gnuplot-doc

    # networking: hostapd (Create WiFi Access Point)
    hostapd iw isc-dhcp-server haveged # firmware-atheros firmware-realtek firmware-iwlwifi
    # conky/conky-manager prerequesites
    lm-sensors xsensors psensor curl hddtemp dmidecode conky conky-all arandr cpuid
    # install new window manager to prevent tearing
    compton

    # cmake newest + dependendencies
    cmake cmake-doc cmake-qt-gui cmake-curses-gui hexchat qbittorrent ninja-build

    # networking
    hostname openssh-client openssh-server fail2ban sshfs ntp ntpdate dhcpdump tcpdump dnsutils ftp nmap telnet
    # needed for extract macro function
    zip unzip cabextract p7zip p7zip-full lzma rar unrar zipmerge tnef unace unalz unar arj lzop ncompress rzip
    # parallel compression tools
    pixz plzip pigz pbzip2 lbzip2 lrzip lzip bsdtar libarchive-tools

    # Programming toolchain
    lsof colordiff wdiff valgrind cppcheck doxygen doxygen-doc graphviz mercurial git git-doc gitk subversion subversion-tools

    # audio control (weird dependendencies would remove gparted and inkscape on upgrade ... -.- )
    pavucontrol gparted inkscape flashplugin-nonfree
    # Battery / power tools
    tlp acpi-call-dkms dkms tp-smapi-dkms

    # Tools
    pidgin pidgin-otr pidgin-latex pidgin-blinklight pidgin-themes pidgin-data pidgin-plugin-pack pidgin-extprefs purple-discord telegram-purple
    # https://launchpad.net/pidgin-character-counting
    # http://3d.benjamin-thaut.de/?p=12
    powertop iotop sysstat iptraf nethogs speedometer hwinfo lshw lsscsi procps bsdutils
    #vitables
    trans-de-en ding translate anacron rfkill trash-cli strace
    # catfish

    #wine64-preloader wine wine64 wine32 libwine:i386 pv
    # requirements for ZKanji
    wine fonts-ipa*

    # XFCE
    xfce4 xfce4-terminal xfce4-timer-plugin thunar-archive-plugin xfce4-screenshooter xfce4-taskmanager xfce4-clipman-plugin xfce4-datetime-plugin xfce4-netload-plugin xfce4-wavelan-plugin xfce4-whiskermenu-plugin xfce4-xkb-plugin xfce4-goodies xfce4-mount-plugin xfce4-pulseaudio-plugin xfburn wodim
    xfwm4-themes gtk3-engines-xfce

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

    git-hg ibus ibus-anthy qrencode qtqr memtop xzoom vorbistools cuetools shntool gpick gcolor2 wireshark wireshark-qt
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

# https://askubuntu.com/questions/1341909/file-browser-and-file-dialogs-take-a-long-time-to-open-or-fail-to-open-in-all-ap/1350804#1350804
sudo mv /usr/libexec/gvfsd-trash{,.bak}

trashPackages=(
    # snap pollutes mountpoints, memory, and everything and is slow, who would want that. flatpak is not much better
    flatpak snapd
    # Kills X session when out of memory. At that point I can also fully restart. Absolutely useless!
    systemd-oomd
    # Currently, I only have ubuntu-desktop installed but maybe next time do a clean install with xubuntu-desktop instead!
    # tracker
)

for package in "${trashPackages[@]}"; do
    sudo apt purge --yes "$package"
done


# Memory leak problems. They take up >2 GB after a month or so and are only needed for flatpak, which I don't use
sudo mv /usr/libexec/xdg-desktop-portal{,.bak}
sudo mv /usr/libexec/xdg-desktop-portal-gtk{,.bak}

# Fucking tracker using up resource unnecessarily
systemctl --user mask tracker-extract-3.service tracker-miner-fs-3.service tracker-miner-rss-3.service tracker-writeback-3.service tracker-xdg-portal-3.service tracker-miner-fs-control-3.service
tracker3 reset -s -r

exit

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

    OpenFOAM:
        apt-get install build-essential flex bison cmake zlib1g-dev libopenmpi-dev openmpi-bin gnuplot libreadline-dev libncurses-dev libxt-dev qt4-dev-tools libqt4-dev libqt4-opengl-dev freeglut3-dev libqtwebkit-dev libscotch-dev libcgal-dev
        git clone git://github.com/OpenFOAM/OpenFOAM-2.4.x.git /opt/OpenFOAM-2.4.x
        export FOAM_INST_DIR=/opt/
        source /opt/OpenFOAM-2.4.x/etc/bashrc
        /opt/OpenFOAM-2.4.x/foamSystemCheck
        ./Allwmake
    FreeFileSync: http://www.fosshub.com/FreeFileSync.html -> extract to /opt/
    ffmpeg (because debian maintainers hate ffmpeg programmer -.-):
        sudo apt-get install autoconf automake build-essential libass-dev libfreetype6-dev libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev  libxcb-xfixes0-dev pkg-config texi2html zlib1g-dev yasm libx264-dev cmake mercurial libfdk-aac-dev libfdk-aac0 libmp3lame-dev libopus-dev libvpx1 libvpx-dev
        mkdir -p /opt/ffmpeg/src /opt/ffmpeg/build /opt/ffmpeg/bin
        # libx265:
            cd /opt/ffmpeg/src
            hg clone https://bitbucket.org/multicoreware/x265
            cd /opt/ffmpeg/src/x265/build/linux
            cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/opt/ffmpeg/build" -DENABLE_SHARED:bool=off ../../source
            make && make install && make distclean
        cd /opt/ffmpeg/src
        wget http://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2; tar xjvf ffmpeg-snapshot.tar.bz2; cd ffmpeg
        export PATH="/opt/ffmpeg/bin:$PATH"
        PKG_CONFIG_PATH="/opt/ffmpeg/build/lib/pkgconfig" ./configure \
          --prefix="/opt/ffmpeg/build" \
          --pkg-config-flags="--static" \
          --extra-cflags="-I/opt/ffmpeg/build/include" \
          --extra-ldflags="-L/opt/ffmpeg/build/lib" \
          --bindir="/opt/ffmpeg/bin" \
          --enable-gpl --enable-libass --enable-libfdk-aac --enable-libfreetype --enable-libmp3lame --enable-libopus --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 --enable-nonfree
        make && make install && make distclean && hash -r
        echo "MANPATH_MAP /opt/ffmpeg/bin /opt/ffmpeg/build/share/man" >> ~/.manpath
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
    Firefox (Do not like iceweasel):
        https://download.mozilla.org/?product=firefox-39.0-SSL&os=linux64&lang=de
        from: https://www.mozilla.org/de/firefox/new/
    manually add manual programs to applications menu through entry in: /usr/share/applications
    http://sourceforge.net/projects/defragfs/files/defragfs/defragfs-1.1/defragfs-1.1.1.gz/download
    JDownloader2

sudo apt-get purge xterm

# Could not connect to wicd's D-Bus interface. Check the wicd log for error messages.
#   - make sure you actually have wicd installed and not only wicd-gtk or try
#   - sudo bash -c "service wicd stop; dpkg-reconfigure wicd; sudo service wicd start"

# Scite theme fallback ... use darktheme in xfce4-appearance-settings ... still doesn't work perfect...

sudo easy_install seaborn mpltools
