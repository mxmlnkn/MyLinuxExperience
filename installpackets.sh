#!/bin/bash
# installed debs are in /var/cache/apt/archives
# show installed: /var/log/dpkg.log  /var/log/apt/history.log  $(dpkg --get-selections "*")
# search installed dpkg-query -l '*wicd*"
# see also /var/cache/apt/archives/

if ! 'grep' -q 'n=sid' /etc/apt/preferences; then
    sudo bash -c 'cat <<EOF >> /etc/apt/preferences
Package: *
Pin: release n=sid
Pin-Priority: 54
EOF
'
fi

# lrzip needed for sage tarballs
# apt-get install sudo
sudo apt-get install apt-transport-https # needed for apt-get update
sudo apt-get update

packagelistsid=(
    # More beautiful login screen
    lightdm

    vim

    # linux headers for compiling new kernel e.g. for CUDA-installation
    linux-headers-$(uname -r)

    wkhtmltopdf pandoc

    # printer prerequesite
    xsltproc

    # only notebook
    # xfce4-power-manager xfce4-power-manager-plugins
    # only pc
    #cuda

    # hexdump, ... might be linux-tools-common on ubuntu?
    coreutils bsdmainutils moreutils geoip-bin htop cpulimit cpuinfo read-edid get-edid

    # scala 2.11 doesn't work with spark 1.6.0 yet -.-
    #scala scala-doc

    x11-apps screenruler # xclock for testing
    libcdio-utils

    # Programming toolchain
    linux-tools gcc g++ gdb clang ccache ninja-build mold libopenmpi-dev openmpi-bin openmpi-common openmpi-doc
    libboost-all-dev gnuplot perl freeglut3 libthrust-dev uncrustify clang-tidy linux-perf heaptrack heaptrack-gui
    python3 ipython3 jupyter python3-pip python3-numpy python3-scipy python3-matplotlib python3-tk python3-seaborn
    python3-venv python3-virtualenv pylint

    # steam things like glxinfo
    mesa-utils

    filezilla audacity gimp ristretto pngtools optipng libtiff-tools libtiff5 libtiff-doc libtiff5-dev libtiffxx5 secure-delete openjdk-7-jre openjdk-7-jdk icedtea-7-plugin evince qpdf xchm xdotool lynx telegram-desktop
    scite meld gnome-themes-standard gnome-themes-extras pdftk
    fonts-dejavu fonts-firacode ttf-bitstream-vera ttf-unifont unifont-bin fonts-symbola

    pavumeter pavucontrol
    # audacious: use appearance->winamp-skin
    # sable-theme builds upon this theme, this is why it's needed
    gtk2-engines-murrine gtk2-engines-pixbuf gnome-themes-standard gtk-theme-switch lxappearance
    adwaita-qt* gnome-themes-extra

    # XnView prerequisites
    libphonon4 reportbug

    # WLAN
    wireless-tools
    # times new roman and so in in libreoffice
    ttf-mscorefonts-installer

    xorg x11-xfs-utils xorg-docs xclip libhdf5-doc elfutils gnuplot-doc doc-base

    # for creating local repo from cached .deb files using dpkg-scanpackages
    dpkg-dev environment-modules
    # Login Manager
    # slim
    xscreensaver
    # networking: hostapd (Create WiFi Access Point)
    hostapd iw isc-dhcp-server firmware-atheros firmware-realtek firmware-iwlwifi haveged
    # conky/conky-manager prerequesites
    lm-sensors xsensors psensor curl hddtemp dmidecode conky conky-all arandr realpath cpuid
    # install new window manager to prevent tearing
    compton

    # screencasting
    kazam scrot shutter
    # some programming libraries often used
    libfftw3-dev
    # cmake newest + dependendencies
    cmake cmake-doc cmake-qt-gui cmake-curses-gui hexchat
    # Rainlendar prerequisites
    libjavascriptcoregtk-1.0-0 libwebkitgtk-1.0-0 libwebkitgtk-1.0-common

    # networking
    hostname openssh-client openssh-server fail2ban sshfs ntp ntpdate dhcpdump tcpdump dnsutils ftp nmap telnet
    # needed for extract macro function
    zip unzip cabextract p7zip p7zip-full lzma rar unrar zipmerge tnef
    # parallel compression tools
    pxz plzip pigz lbzip2 lrzip
    caja arj lzip lzop ncompress rzip sharutils unace unalz zoo unar jq

    vlc libaacs0 libbluray* smplayer mplayer libqt5gui5 libqt5network5 libqt5xcbqpa5
    streamripper streamtuner2
    thunderbird lightning

    # Programming toolchain
    colorgcc nasm selfhtml lsof colordiff wdiff valgrind cppcheck splint doxygen doxygen-doc graphviz debian-history mercurial git git-lfs git-doc gitk subversion subversion-tools
    # Java Toolchain
    maven ant ant-doc

    # audio control (weird dependendencies would remove gparted and inkscape on upgrade ... -.- )
    pavucontrol gparted inkscape flashplugin-nonfree
    #synfigstudio
    # Battery / power tools
    tlp acpi-call-dkms dkms tp-smapi-dkms

    # picongpu prerequesites
    #build-essential freeglut3-dev libgl1-mesa-glx libglu1-mesa-dev libx11-dev libxi-dev libxmu-dev
    #zlib1g zlib1g-dev openmpi-common libpng-dev libhdf5-openmpi-dev libboost-all-dev

    # Some things needed for LeMonADE(-Viwer)
    libfltk1.3-dev povray povray-includes povray-doc povray-examples

    pidgin pidgin-otr pidgin-latex pidgin-blinklight pidgin-themes pidgin-data pidgin-plugin-pack pidgin-audacious pidgin-extprefs purple-discord telegram-purple
    # Caution: pidgin-openpgp segfaults pidgin in Ubuntu 20.04!!!
    # Outdated and only produces warnings I don't need: pidgin-skype

    # Tools
    # https://launchpad.net/pidgin-character-counting
    # http://3d.benjamin-thaut.de/?p=12
    powertop iotop sysstat iptraf nethogs speedometer hwinfo lshw lsscsi procps bsdutils
    cython cython-doc libhdf5-dev libhdf5-doc python-h5py python-h5py-doc python-pip vitables
    trans-de-en ding translate anacron scite rfkill trash-cli strace chm2pdf
    # catfish
    galculator gdmap sqlite3 cpuburn fancontrol shred wipe
    wine64-preloader wine wine64 wine32 libwine:i386 pv

    # XFCE
    xfce4 xfce4-terminal xfce4-timer-plugin thunar-archive-plugin xfce4-screenshooter xfce4-screenshooter-plugin xfce4-taskmanager xfce4-clipman-plugin xfce4-datetime-plugin xfce4-netload-plugin xfce4-wavelan-plugin xfce4-whiskermenu-plugin xfce4-xkb-plugin xfce4-goodies xfce4-mount-plugin xfce4-pulseaudio-plugin xfce4-mixer xfburn wodim
    xfwm4-themes gtk3-engines-xfce xscreensaver

    # ntfs read write support, necessary for truecrypt volumes !!
    ntfs-3g attr xbacklight hibernate mlocate duplicity go-mtpfs gvfs-backends gvfs-mtp exfat-fuse exfat-utils
    firmware-linux-nonfree firmware-linux-free
    # data recovery
    testdisk disktype scalpel
    # printer prerequesite
    lsb system-config-printer sane
    # aplay for timerle script
    alsa-utils xloadimage
    # dependendencies for remarkable
    python3-markdown python3-bs4 gir1.2-webkit-3.0 yelp wkhtmltopdf

    # seems to be in repo now (nonfree repo?)
    ffmpeg audacious

    fonts-ipa* ibus ibus-anthy qrencode qtqr memtop xzoom vorbistools cuetools shntool gpick gcolor2 wireshark wireshark-qt
    time

    ###### documentation (partially this means manuals) ######
    # generated with:
    #   for package in ${packagelist[*]}; do
    #       if apt-cache search $package-doc | grep -q $package-doc; then
    #           echo -n "$package-doc ";
    #       fi
    #   done
    # and then hand selected useful docs
    gcc-doc gfortran-doc gdb-doc
    python-matplotlib-doc python-doc python-numpy-doc ipython-doc python-setuptools-doc python-scipy-doc

    # science for siunitx, pictures for includegraphics and tikz => ~350mb download!
    texlive-latex-recommended texlive-science texlive-science-doc texlive-pictures texlive-pstricks texlive-generic-extra
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

    #octave-*

    # LibreOffice
    libreoffice-common libreoffice-core libreoffice-pdfimport libreoffice-l10n-de libreoffice-help-de hyphen-de myspell-de-de mythes-de libreoffice-help-en-us libreoffice-writer libreoffice-impress

    marble-qt # 3D offline globe
    virtualbox-qt virtualbox virtualbox-guest-utils

    gimagereader tesseract-ocr-jpn tesseract-ocr-jpn-vert

    opera-stable chromium cups imagemagick imagemagick-common

    # machine learning
    python3-keras keras-doc

    pv progress parallel aptitude net-tools zenity efibootmgr gfio fio conky libncurses5 gsmartcontrol
    tidy calibre memtester memtest86 bless bash shellcheck oathtool

    # https://askubuntu.com/questions/1185277/screen-tearing-in-linux-with-nvidia-graphics/1185328?noredirect=1#comment2061233_1185328
    nvidia-settings
)

for package in "${packagelistsid[@]}"; do
    echo "Install '$package'"
    sudo apt-get install --yes "$package" #-t sid
    sudo apt-get -f install
done
sudo apt-get autoremove


# hold some largish rarely used packages for traffic reason
#sudo apt-mark hold libreoffice* texlive*

exit



More programs installed manually in /opt/
    sudo dpkg -i conky-manager-latest-amd64.deb

    Steam:
        wget http://repo.steampowered.com/steam/archive/precise/steam_latest.deb
        sudo dpkg -i steam_latest.deb
        sudo apt-get install -f
        or: sudo apt install steam_latest.deb

    FreeFileSync: http://www.fosshub.com/FreeFileSync.html -> extract to /opt/
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

sudo apt-get purge xterm

# Could not connect to wicd's D-Bus interface. Check the wicd log for error messages.
#   - make sure you actually have wicd installed and not only wicd-gtk or try
#   - sudo bash -c "service wicd stop; dpkg-reconfigure wicd; sudo service wicd start"

# Scite theme fallback ... use darktheme in xfce4-appearance-settings ... still doesn't work perfect...

sudo easy_install seaborn mpltools
