### USB only writable as root

because USB mounted by `fstab` instead of xfce-prog, `fstab` is run by root
```Shell
mount with -ouser,umask=0000
```
can also be used in fstab, without -o of course


### Mount USB manually

```Shell
lsusb           # see if usb device was actually recognized
sudo fdisk -l   # show at wich /dev/sd## the device is
chmod a+rwx /media/transcend
mount /dev/sdb1 /media/transcend # mount usb device
```


### brightness keys not working

Install `xfce4-power-manager` and or `xfce4-power-manager-plugins`
```Shell
sudo sed -i "s;GRUB_CMDLINE_LINUX_DEFAULT=\";GRUB_CMDLINE_LINUX_DEFAULT=\"acpi_osi=Linux acpi_backlight=vendor ;" /etc/default/grub
```


### application based firewall

```Shell
sudo addgroup blocknetwork
bngid=$(cat /etc/group | grep blocknetwork | sed 's/:/ /g' | awk '{ print $3 }')
sudo iptables -A OUTPUT -m owner --gid-owner $bngid -j DROP
sudo iptables -A INPUT  -m owner --gid-owner $bngid -j DROP
sudo -g blocknetwork ping 127.0.0.1
```


### Add Programs to Autostart

move their `.desktop`-shortcut to `~/.config/autostart/`


### p7zip can not decompress password encrypted 7z-archives

`7z` command line can if `p7zip-full` is installed, but `xarchiver` still can not.

Download [`peazip`](http://sourceforge.net/projects/peazip/files/5.6.1/peazip_5.6.1.LINUX.GTK2-2_i386.deb/download)
not working, because x86 -.-

  => just use command line for these archives -.-


### For some reason it does not suspend automatically even though set up in power manager.

I only set times for display in `xfce4-power-manager-settings` -.-. Need to also configure 'System' tab
Differences in display-settings:
```Shell
xset --help # user preference utility for X
```

>To control Energy Star (DPMS) features:        </br>
>-dpms      Energy Star features off            </br>
>+dpms      Energy Star features on             </br>
> dpms [standby [suspend [off]]]                </br>
>      force standby                            </br>
>      force suspend                            </br>
>      force off                                </br>
>      force on                                 </br>
>      (also implicitly enables DPMS features)  </br>
>      a timeout value of zero disables the mode</br>

=> no real differences in timing, like mentioned [here](http://superuser.com/questions/443739/xfce-power-manager-monitor-difference-between-sleep-switch-off), see also http://webpages.charter.net/dperr/dpms.htm
settings are saved in `.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml`
But they can also be set manually in e.g. `/etc/X11/xorg.conf.d/10-monitor.conf` (or any other file in `/etc/xorg.conf.d` which will be autoloaded by X-Server)

    Section "Monitor"
        Option "DPMS" "true"
    EndSection

    Section "ServerLayout"
        Identifier "ServerLayout0"
        Option "StandbyTime" "10"
        Option "SuspendTime" "20"
        Option "OffTime" "30"
    EndSection

>Warning: XScreenSaver or xfce4-power-manager use its own DPMS settings and override xset configuration. See XScreenSaver#DPMS settings for more information.


>systemd-udevd[12365]: failed to execute '/lib/udev/socket:@/org/freedesktop/hal/udev_event'

This error happened because I upgraded debian instead of installing debian 8 from scratch. Use:
```Shell
sudo apt-get purge hal
```
  => seems to work now!


### Upgrade Debian 7 to 8

```Shell
echo "/cygdrive/d/Programs/OS/Debian1.iso /mnt/debiso3 iso9669 loop 0 0
/cygdrive/d/Programs/OS/Debian1.iso /mnt/debiso3 iso9669 loop 0 0
/cygdrive/d/Programs/OS/Debian1.iso /mnt/debiso3 iso9669 loop 0 0" >> /etc/fstab
mount -a
echo "deb file:/mnt/debiso1 jessie main contrib
deb file:/mnt/debiso1 jessie main contrib
deb file:/mnt/debiso1 jessie main contrib" >> /etc/sources.list
apt-get update
script -t 2 > ~/upgradejessie.time -a ~/upagradejessie.script
apt-get autoremove
apt-get upgrade # minimales system upgrade
apt-get dist-upgrade
dpkg -l 'linux-image*' # if not updated, to it with apt-get now before rebooting!
apt-get purge $(dpkg -l | awk '/^rc/ { print $2 }') # purge packets which were removed but whose configs still are on the system
```


### Failed to hibernate session

> GDBus.Error:org.freedesktop.login1.SleepVerbNotSupported: Sleep verb not supported

```Shell
sudo systemctl hibernate
```

> A dependency job for hibernate.target failed. See 'journalctl -xn' for details.

```Shell
journalctl -xn
```

> No journal files were found.

```Shell
sudo journalctl -xn
```

>Jun 22 23:37:50 LenovoE330 kernel: PM: Cannot find swap device, try swapon -a.</br>
>Jun 22 23:37:50 LenovoE330 kernel: PM: Cannot get swap writer

 => Swap partitions seems to be missing. I will not be able to create one now :(


#### Create Swap-File (not partition)

https://www.digitalocean.com/community/tutorials/how-to-add-swap-on-ubuntu-14-04
```Shell
free -m or sudo swapon -s to show if swap exists -> does not
sudo bash -c "fallocate -l 6G /swapfile; chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile; swapon -s; printf '\n/swapfile   none    swap    sw    0   0\n' >> /etc/fstab"
cat /proc/sys/vm/swappiness
sudo sysctl vm.swappiness=30   # value of 0 will not write to swap unless really necessary (default is 60) (only temporary setting -> sysctl.conf)grep
'swappiness' /etc/sysctl.conf
sudo bash -c "printf '\nvm.swappiness = 30\nvm.vfs_cache_pressure = 50\n' >> /etc/sysctl.conf"
```
>  Jun 23 00:20:32 LenovoE330 kernel: PM: Swap header not found!

Hibernate does not work with swapfiles out of the box and will exhibit behavior similar to this bug:

> [Ubuntu bug 313724, Red Hat bug 466408] "PM: Swap header not found!"


#### Make swapfile usable for hibernating
```Shell
sudo apt-get install hibernate
rootuuid=$(sudo lsblk --noheadings --output UUID $(mount | grep ' / ' | awk '{print $1}') )  # get uuid
physoff=$(sudo filefrag -v /swapfile | head -n 4 | tail -n 1 | awk '{print $4}' | sed 's/\.\.//')
sudo bash -c "echo 'resume=UUID=$rootuuid resume_offset=$physoff' > /etc/initramfs-tools/conf.d/resume"
sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"resume=UUID=$rootuuid resume_offset=$physoff /" /etc/default/grub
sudo update-grub; sudo update-initramfs -u
```
Reboot and then try hibernate function :) If not working, try with commandline sudo hibernate


### Clock changes by 2 hours when switching between linux and windows

    HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation
        Create DWORD (32-bit) Value 'RealTimeIsUniversal' set to 1
    sudo date --set 03:57:10


### View two displays side by side

Install `arandr`, execute it and set up to your likings


### Redirect sound to HDMI-Output

Install and use `pavucontrol`


### Fix Tearing in Iceweasel and Firefox:

#### Method 1: Activate TearFree Feature of intel driver (does not seem to work)

```Shell
# sudo apt-get install xserver-xorg-video-intel
sudo bash -c 'cat > /etc/X11/xorg.conf.d/20-intel.conf << EOF
Section "Device"
    Identifier "Intel Graphics"
    Driver "intel"
    Option "SwapbuffersWait" "true"
    Option "AccelMethod" "sna"
    Option "TearFree" "true"
EndSection
EOF'
```

#### Method 2: Install new window manager

```Shell
    sudo apt-get install compton
xfconf-query -c xfwm4 -p /general/use_compositing -s false
compton --backend glx --vsync opengl-swc
cat > ~/.compton.conf << EOF
    backend = "glx";
    paint-on-overlay = true;
    glx-no-stencil = true;
    glx-no-rebind-pixmap = true;
    vsync = "opengl-swc";
EOF
compton -b --config ~/.config/compton.conf   # daemonize process
cat > .config/autostart/Compton.desktop << EOF
    [Desktop Entry]
    Encoding=UTF-8
    Version=0.9.4
    Type=Application
    Name=Compton
    Comment=Window Manager to fix tearing
    Exec=compton -b --config ~/.config/compton.conf
    OnlyShowIn=XFCE;
    StartupNotify=false
    Terminal=false
    Hidden=false
EOF
xfce->settings->session and startup-> bash -c "sleep 5 && compton -b --config ~/.config/compton.conf &"
```


### When scrolling a web page and pressing Ctrl, even after the mouse wheel is not moving anymore, the web page gets resized

This is beause of synaptics scroll inertia which keeps sending some scroll events after mouse wheel stopped. Those will then be interpreted as Ctrl+Scroll = Resize.

**Solution:** Disable scroll intertia:

- Add:
  > Option "CoastingSpeed" "0"
  to Section "InputClass" which matches all touchpads not just specific ones in `/etc/X11/xorg.conf.d/50-synaptics.conf`
- restart to apply settings or just "pkill X" (closes all opened windows!)


### No connection, even to router, even though router shows ip
Check `ifconfig`. If config shows now ipv4, but ipv6 ips -> that is why. Add `-4` option to `dhclient`

No idea, why this has not happened before -.- update?


### Remove service from autostart

```Shell
    sudo update-rc.d ssh disable
```
Now needs to be started manually
```Shell
   sudo service ssh start
```


### Remember history of all opened terminals, not just last ones

Browse all history if new one opened, but only browse own one commands since startup of that terminals
```Shell
man bash
```

    history [n]
    history -c                                                              
    history -d offset                                                       
    history -anrw [filename]                                                
    history -p arg [arg ...]                                                
    history -s arg [arg ...]                                                
        With no options, display the command history list with line num‐ 
        bers.  Lines listed with a * have been modified.  An argument of 
        n  lists only the last n lines.  If the shell variable HISTTIME‐ 
        FORMAT is set and not null, it is used as a  format  string  for 
        strftime(3)  to display the time stamp associated with each dis‐ 
        played history entry.  No intervening blank is  printed  between 
        the  formatted  time stamp and the history line.  If filename is 
        supplied, it is used as the name of the history  file;  if  not, 
        the  value  of HISTFILE is used.  Options, if supplied, have the 
        following meanings:                                              
        -c         Clear the history list by deleting all the entries.       
        -d offset  Delete the history entry at position offset.              
        -a         Append the 'new' history lines (history  lines  entered   
                   since  the  beginning of the current bash session) to the 
                   history file.                                             
        -n         Read the history lines not already read from the  history 
                   file  into  the  current  history  list.  These are lines 
                   appended to the history file since the beginning  of  the 
                   current bash session.                                     
        -r         Read  the contents of the history file and append them to 
                   the current history list.                                 
        -w         Write the current history list to the history file, over‐ 
                   writing the history file's contents.                      

Paste this into your `.bashrc`:
```Shell
HISTCONTROL=''
HISTFOLDER=~/.bash_histories
HISTFILEEXT=history      # only files in $HISTFOLDER with this extension will be read
shopt -s histappend   # append when closing session
mkdir -p $HISTFOLDER
HISTFILE=$HISTFOLDER/$(date +%Y-%m-%d_%H-%M-%S_%N).$HISTFILEEXT  # create unique file name for this session. Nanoseconds seems to be unique enough, try: for ((i=0; i<=10; i++)); do date +%Y-%m-%d_%H-%M-%S_%N; done
# if HISTFILE unset, history is not saved on exit -> not really necessary if we save after each command, but its a double net safety
HISTSIZE=       # maximum number of commands to hold inside bash history buffer. if empty then infinite
HISTFILESIZE=   # maximum number of lines in history file
# history -a $HISTFILE # bash saves the total history commands entered since startup or since the last save and saves that amount of commands to the file. This means reading a history file after typing commands will trip up bash, but this will not be a problem if the history file is only loaded in the beginning. This means that only new commands are saved not all the old loaded commands, thereby we can load as many history files into the buffer as we want and still only save newly thereafter typed commands
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
```


### fix non-windows-conform filenames in automatically

windows forbidden: `\ / : * ? " < > |`
```Shell
mv 'file' $(echo 'file' | sed -e 's/[^A-Za-z0-9._-]/_/g')
# Watch out! Following does not work:
  find . -exec {};
  find . -exec {}\;
# This works -.- notice the space:
  find . -exec {} \;
echo "'" | hexdump
    0000000 0a61
    -> echo "'" | sed 's/\x27/MEH/'
# Show function definition:
    declare -f cleanfilenames
```
Watch out! If alias is still defined funcftion will be ignored (at least if there are no arguments to it)

  -> see `cleanfilenames.sh`

See also these bugs:
 - [Special Characters in filename](https://bugzilla.mozilla.org/show_bug.cgi?id=1189730)
 - [Saving web pages with illegal characters in the file name (replace/escape them) on Linux](https://bugzilla.mozilla.org/show_bug.cgi?id=397645)


### Firefox automatically appends .html when saving, even if .mht is choosen in drop-down list

... its a hazzle to delete .html every time I save something... -> bug
https://bugzilla.mozilla.org/show_bug.cgi?id=514493
see script for 'fix non-windows-conform filenames' which includes this replacement


### Install CUDA (4th try -.- ...) use recovery mode from install disk

```Shell
apt-get install linux-headers-$(uname -r)
# Installing CUDA with .run-installer:
# Fucking installer will not install, because repo nvidia driver version is 340, while cuda needs 343 >:OOOO gottverdammt
# Nvidia does not work anymore anyway after reboot -.- ... try to install only using this install in rescue mode
sudo apt-purge nvidia-*
sudo apt-purge cuda-*   # frees fricking 3gb !!! besides that cuda is insanely large, it seems like it was installed somehow -.- ...
sudo apt-get autoremove
sudo apt-get upgrade
sudo vim /etc/modprobe.d/nvidia-installer-disable-nouveau.conf
    # generated by nvidia-installer
    blacklist nouveau
    options nouveau modeset=0
reboot
sh cuda_7.0.28_linux.run   # this also install nvidia driver
# does not run. Log points out, that gcc version is not the same as the kernel was built with :(
cat /proc/version
export CC=/usr/bin/gcc-4.8
sh cuda_7.0.28_linux.run
    WARNING: Unable to find a suitable destination to install 32-bit
     compatibility libraries. Your system may not be set up for 32-bit
     compatibility. 32-bit compatibility files will not be installed;
     if you wish to install them, re-run the installation and set a
     valid directory with the --compat32-libdir option.

    [...]

    ===========
    = Summary =
    ===========

    Driver:   Installed
    Toolkit:  Installed in /opt/cuda-7.0
    Samples:  Installed in /opt/cuda-7.0/samples

    Please make sure that
     -   PATH includes /opt/cuda-7.0/bin
     -   LD_LIBRARY_PATH includes /opt/cuda-7.0/lib64, or, add /opt/cuda-7.0/lib64 to /etc/ld.so.conf and run ldconfig as root

    To uninstall the CUDA Toolkit, run the uninstall script in /opt/cuda-7.0/bin
    To uninstall the NVIDIA Driver, run nvidia-uninstall

    Please see CUDA_Getting_Started_Guide_For_Linux.pdf in /opt/cuda-7.0/doc/pdf for detailed information on setting up CUDA.
export CUDA_ROOT=/opt/cuda-7.0
export PATH=$PATH:$CUDA_ROOT/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CUDA_ROOT/lib64
sudo bash -c "echo $CUDA_ROOT/lib64 > /etc/ld.so.conf.d/cuda-x86_64.conf"
sudo ldconfig
cd /opt/cuda-7.0/samples
sudo chmod -R a+rw .
make
/opt/cuda-7.0/samples/bin/x86_64/linux/release/simplePrintf
    GPU Device 0: "GeForce GTX 760" with compute capability 3.0

    Device 0: "GeForce GTX 760" with Compute 3.0 capability
    printf() is called. Output:

    [3, 0]:		Value is:10
    [3, 1]:		Value is:10
    [3, 2]:		Value is:10
    [3, 3]:		Value is:10
    [3, 4]:		Value is:10
```


### Install 32-bit compatibility files for CUDA / Steam NVidia OpenGL 32 Bit libraries

```Shell
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install ia32-libs
    Package ia32-libs is not available, but is referred to by another package.
    The following packages replace it:
      lib32z1 lib32ncurses5
sudo apt-get install lib32z1 lib32ncurses5
    well not really what I want, but the dependency libc6-i386 seems to be ok
sh ./cuda_7.0.28_linux.run --compat32-libdir
    Unknown option: compat32-libdir
        ... -.- fick dich! <- this is because cuda installer extracts and calls nvidia installer which prints that messages
./NVIDIA-Linux-x86_64-352.30.run --version
    nvidia-installer:  version 352.30  (buildmeister@swio-display-x64-rhel04-18)  Tue Jul 21 19:36:36 PDT 2015
        -> version is higher than needed by CUDA 7.0 (346.00), so I guess it should work :S
export CC=/usr/bin/gcc-4.8
./NVIDIA-Linux-x86_64-352.30.run
    uninstall old driver (346.52) -> yes
    install 32-bit compatibility files -> yes
    run nvidia-xconf -> yes
steam    # now running :)
```


### Ctrl+Alt+F1 does not show username-password-prompt anymore after nvidia driver installation

It only shows some kernel boot up logs before the graphic driver was loaded. (other people seem to have a completely black screen)

This is a framebuffer problem known for YEARS!! -.-

It also leads to this:
>Ctrl+Alt+F1 not working after NVidia installation (can not switch to ttyX)

*temporary test:*

In grub press e for edit and append `nomodeset` to line starting with `linux /boot/vmlinuz-` and possibly ending with `ro quiet`

**permanent:**

    /etc/default/grub
        GRUB_GFXMODE=1920x1080x32
        GRUB_GFXPAYLOAD_LINUX=keep
    or:
        GRUB_CMDLINE_LINUX_DEFAULT="quiet nomodeset"


### Reboot from slim without logging into xfce

    You may shutdown, reboot, suspend, exit or even launch a terminal from the 
    SLiM login screen. To do so, use the values in the username field, and the 
    root password in the password field:
        To launch a terminal, enter console as the username (defaults to xterm 
        which must be installed separately... edit /etc/slim.conf to change 
        terminal preference)
        For shutdown, enter halt as the username
        For reboot, enter reboot as the username
        To exit to bash, enter exit as the username
        For suspend, enter suspend as the username. Suspend is disabled by 
        default, edit /etc/slim.conf as root to uncomment the suspend_cmd line 
        and, if necessary, modify the suspend command itself (by e.g. changing 
        /usr/sbin/suspend to sudo /usr/sbin/pm-suspend).


### Too much output for vbeinfo in grub console

In GRUB Console:

    set pager=1
    vbeinfo
    # 0x14d 1920x1080x32 (7680) Direct color, mask 8/8/8/8 pos 16/8/0/24

or use

    sudo hwinfo --framebuffer


### Black screen after installing CUDA (from repo was it, i think :S)

use recovery mode from deb-netinst and mount `/dev/sdb` as root to
```Shell
apt-get purge bumblebee
apt-get autoremove
```


### X11: Fatal server error: no screens found / no devices detected / xinit unable to connect to x server / only shell after reboot

    Xorg --configure
    Xorg -config /root/xorg.conf.new &

  -> works like a charm :3. maybe should have run this before uninstalling intel driver ...

See `~/.local/Xorg.0.log` for errors.

Try reinstalling the NVIDIA driver
```Shell
wget http://us.download.nvidia.com/XFree86/Linux-x86_64/361.42/NVIDIA-Linux-x86_64-361.42.run
chmod u+x NVIDIA*
sudo ./NVIDIA*.run
```
Try to prevent this from happening again:
```Shell
sudo apt-get mark hold xorg xserver xserver-xorg
```
Check if really held:
```Shell
dpkg --get-selections | grep hold
```

### Create a local repository in order to use old cached .deb files

```Shell
cd /media/d/Linux/debarchives
sudo apt-get install dpkg-dev
dpkg-scanpackages . > Packages
gzip -f Packages
sudo bash -c "echo 'deb file:///media/d/Linux/debarchives ./' >> /etc/apt/sources.list"
```

After updating the following problem appears:

    File not found - /media/d/Linux/archives/./Packages (2: No such file or directory)
      Reading package lists... Done
      N: can not drop privileges for downloading as file '/media/d/Linux/archives/./InRelease' could not be accessed by user '_apt'. - pkgAcquire::Run (13: Permission denied)
      W: The repository 'file:/media/d/Linux/archives ./ Release' does not have a Release file.
      N: Data from such a repository can not be authenticated and is therefore potentially dangerous to use.
      N: See apt-secure(8) manpage for repository creation and user configuration details.
      W: Failed to fetch file:/media/d/Linux/archives/./Packages  File not found - /media/d/Linux/archives/./Packages (2: No such file or directory)
      E: Some index files failed to download. They have been ignored, or old ones used instead.

    apt-ftparchive # apt-utils, Create a toplevel Release file
    - Sign it. You can do this by running gpg --clearsign -o InRelease Release and gpg -abs -o Release.gpg Release.
     -> see https://github.com/spotify/debify


### Steam "libGL error: unable to load driver: swrast_dri.so"

    LIBGL_DEBUG=verbose steam

        Running Steam on debian 8 64-bit
        STEAM_RUNTIME is enabled automatically
        Installing breakpad exception handler for appid(steam)/version(0)
        libGL: screen 0 does not appear to be DRI3 capable
        libGL: screen 0 does not appear to be DRI2 capable
        libGL: OpenDriver: trying /usr/lib/i386-linux-gnu/dri/tls/swrast_dri.so
        libGL: OpenDriver: trying /usr/lib/i386-linux-gnu/dri/swrast_dri.so
        libGL: dlopen /usr/lib/i386-linux-gnu/dri/swrast_dri.so failed (~/.local/share/Steam/ubuntu12_32/steam-runtime/i386/usr/lib/i386-linux-gnu/libstdc++.so.6: version 'GLIBCXX_3.4.20' not found (required by /usr/lib/i386-linux-gnu/dri/swrast_dri.so))
        libGL: OpenDriver: trying ${ORIGIN}/dri/tls/swrast_dri.so
        libGL: OpenDriver: trying ${ORIGIN}/dri/swrast_dri.so
        libGL: dlopen ${ORIGIN}/dri/swrast_dri.so failed (~/.local/share/Steam/ubuntu12_32/steam-runtime/i386/usr/lib/i386-linux-gnu/libstdc++.so.6: version 'GLIBCXX_3.4.20' not found (required by /usr/lib/i386-linux-gnu/dri/swrast_dri.so))
        libGL: OpenDriver: trying /usr/lib/dri/tls/swrast_dri.so
        libGL: OpenDriver: trying /usr/lib/dri/swrast_dri.so
        libGL: dlopen /usr/lib/dri/swrast_dri.so failed (/usr/lib/dri/swrast_dri.so: cannot open shared object file: No such file or directory)
        libGL error: unable to load driver: swrast_dri.so
        libGL error: failed to load driver: swrast
        
    ldconfig --verbose | grep libGL.so
        libGL.so.1 -> libGL.so.1.2.0
        libGL.so.1 -> libGL.so.346.46
    locate libGL.so.1.2.0 libGL.so.346.46
        /usr/lib/i386-linux-gnu/libGL.so.1.2.0
        /usr/lib/x86_64-linux-gnu/libGL.so.346.46

  -> remember that nvidia installer mentioned that it did not install 32bit version, because the whole system did not have 32bit downwards compatibility files installed
  => see "Install 32-bit compatibility files for CUDA / Steam NVidia OpenGL 32 Bit libraries"

    steam
        [2015-08-09 15:18:46] Downloading update (224,058 of 226,536 KB)...
            .. 200mb gott

  -> Done :)


### Do not remember opened Terminals

-.-... This feature does not work anyway in a satisfying manner

 - uncheck "save session for future logins" checkbox in log-off-panel
 - uncheck settings->session and startup->general->Automaticall save session on logout
 - Settings Manager -> Sessions and Startup -> Sessions Tab -> Clear Saved Sessions

similar to:  `rm -r .cache/sessions/*`  but this also deletes the thumb-caches which clear sessions does not


### Enable Transparent Label Text Background On The Xfce Desk

Why is this not default in the first place:

    ~/.gtkrc.mine # loaded by ~/.gtkrc-2.0
        style "xfdesktop-icon-view" {
            XfdesktopIconView::label-alpha = 0
            XfdesktopIconView::selected-label-alpha = 170  # 255 completely opaque
            XfdesktopIconView::cell-spacing = 6
            XfdesktopIconView::cell-padding = 6
            XfdesktopIconView::cell-text-width-proportion = 1.8
        }
        widget_class "*XfdesktopIconView*" style "xfdesktop-icon-view"
    sudo pkill xfdesktop
        should restart automatically, if not start with xfdesktop from tty1 or reboot


### XnViewMP images have jagged edges / have noise

    F12->View->High Zoom Quality->Zoom-out & Zoom-in
        Was only for Zoom-out before!

Settings are ignored after using crop ...
See:
    http://newsgroup.xnview.com/viewtopic.php?uid=27552&f=62&t=31725&start=0
    http://www.xnview.com/mantisbt/view.php?id=669
    http://newsgroup.xnview.com/viewtopic.php?f=62&t=27377

 => Fixed in Version 0.75
    seems like I only have 0.72! -> that is beause 0.75 does not seem to be downloadable


### Remove file system icons from the desktop

    xfdesktop-settings->Icons->uncheck


### Moving a group of icons resets their relative position

See  https://bugzilla.xfce.org/show_bug.cgi?id=12127


### Renaming icons on desktop resets position in xfdesktop

https://bugzilla.xfce.org/show_bug.cgi?id=1678

Solved just not in Debian -> upgrade to Debian testing

    /etc/apt/sources.list
        # testing
        deb     http://ftp.de.debian.org/debian/ sid         non-free main contrib
        #deb     http://ftp.de.debian.org/debian/ sid-updates non-free main contrib
        deb-src http://ftp.de.debian.org/debian/ sid         non-free main contrib
        #deb-src http://ftp.de.debian.org/debian/ sid-updates non-free main contrib

        # unstable
        deb     http://ftp.de.debian.org/debian/ stretch         non-free main contrib
        #deb     http://ftp.de.debian.org/debian/ stretch-updates non-free main contrib
        deb-src http://ftp.de.debian.org/debian/ stretch         non-free main contrib
        #deb-src http://ftp.de.debian.org/debian/ stretch-updates non-free main contrib

        # stable
        deb     http://ftp.de.debian.org/debian/ jessie          non-free main contrib
        #deb     http://ftp.de.debian.org/debian/ jessie-updates  non-free main contrib
        deb-src http://ftp.de.debian.org/debian/ jessie          non-free main contrib
        #deb-src http://ftp.de.debian.org/debian/ jessie-updates  non-free main contrib
    apt-cache policy    # check pinning settings
    /etc/apt/preferences
        Package: *
        Pin: release n=jessie
        Pin-Priority: 950

        Package: *
        Pin: release n=stretch
        Pin-Priority: 50

        Package: *
        Pin: release n=sid
        Pin-Priority: 54

    # ! note that n=stretch, not a=stretch! but a=testing would also work!
    apt-get install -t stretch xfce4
    man 5 apt_preferences


### Rip CD to iso:

    cat /dev/cdrom > /media/d/Downloads/CSL-WLAN-Adapter-Driver.iso

Copying with dd is a LOT faster!
```Shell
isoinfo -d -i /dev/cdrom
    Logical block size is: 2048
    Volume size is: 34683
dd if=/dev/cdrom of=/media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso bs=2048 count=34683
md5sum /media/d/Downloads/CSL-WLAN-Adapter-Driver.iso
    9bb878dbe8cbff162200a2ae7463d3f6  /media/d/Downloads/CSL-WLAN-Adapter-Driver.iso
md5sum /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
    9bb878dbe8cbff162200a2ae7463d3f6  /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
md5sum /dev/cdrom
    9bb878dbe8cbff162200a2ae7463d3f6  /dev/cdrom
```    
Wow, would not have expected cat and dd to return the identical checksum :3 nice
well interestingly 1 count less will change md5sum, but not 1 count more
```Shell
/bin/ls -la /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
    -rwx------ 1 71030784 Aug 12 01:27 /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
rm /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
dd if=/dev/cdrom of=/media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso bs=2048 count=35000
    34683+0 records in
    34683+0 records out
    71030784 bytes (71 MB) copied, 0.965694 s, 73.6 MB/s
/bin/ls -la /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
    -rwx------ 1 71030784 Aug 12 01:28 /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
md5sum /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
    9bb878dbe8cbff162200a2ae7463d3f6  /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
/bin/ls -la /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
    -rwx------ 1 71030785 Aug 12 01:31 /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
md5sum /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
    bb629f9aad0c1bb41cbe8acd5315ea81  /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
```
All these show, that md5sum does not ignore padded zero-bytes, but dd stops if end of device is reached even if more counts were specified, but 'volume size' was the correct 'count' :). But is it so wrong to write a GUI prog for this shit -.-?

    dd if=/dev/cdrom of=/media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
        138732+0 records in
        138732+0 records out
        71030784 bytes (71 MB) copied, 3.67338 s, 19.3 MB/s

Actuallly it seems bs and count are not even necessary, but without specifying the blocksize the copy process is a LOT slower !
It actually is possible to increade the block size and increase the reading speed! The fastest I could achieve was 150MB/s with at least bs=8192 though:

    dd if=/dev/cdrom of=/media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso bs=8192
        8670+1 records in
        8670+1 records out
        71030784 bytes (71 MB) copied, 0.475861 s, 149 MB/s
    md5sum /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso
        9bb878dbe8cbff162200a2ae7463d3f6  /media/d/Downloads/CSL-WLAN-Adapter-Driver-dd.iso

 -> The problem I ran into is that `dd` only captures the ISO image. It does not grab the HFS data for Apple systems if it is a mixed mode CD. For that I use `readom dev=/dev/scd0`.
```Shell
man ddrescue  # for bad cds
```
http://www.commandlinefu.com/commands/view/1396/create-a-cddvd-iso-image-from-disk.
```Shell
sudo apt-get install wodim
readom dev=/dev/scd0 f=/path/to/image.iso
```
Many like to use `dd` for creating CD/DVD iso images. This is bad. Very bad. The reason this is, is `dd` does not have any built-in error checking. So, you do not know if you got all the bits or not. As such, it is not the right tool for the job. Instead, `reaom` (read optical media) from the wodim package is what you should be using. It has built-in error checking. Similarly, if you want to burn your newly creating ISO, stay away from `dd`, and use:
```Shell
wodim -v -eject /path/to/image.iso
```


### Install Printer

Search for 'sx218' [here](http://download.ebz.epson.net/dsc/search/01/search/?OSC=LX) -> [driver](http://esupport.epson-europe.com/ProductHome.aspx?lng=de-DE&data=FCFfEfoyEiHf0b4o4RP2NRCglNceN1KtpMePYTzEqhQU003D&tc=6)   
```Shell
sudo apt-get install lsb
sudo apt-get -f install
sudo dpkg -i epson-inkjet-printer-workforce-320-sx218_1.0.0-1lsb3.2_amd64.deb
sudo apt-get instal system-config-printer
system-config-printer  # einfach durcklicken bis zur testseite :) imemrhin das funzt sehr einfach
# Zusatz: do what system-config-printer did with command line (configure cups server, I think)
```


### Install Scanner

```Shell
sudo apt-get install sane xsltproc
sudo dpkg -i iscan-data_1.36.0-1_all.deb
sudo dpkg -i iscan_2.30.1-1~usb0.1.ltdl7_amd64.deb #ltdl7 is for debian 6.0 or later
sudo xscanimage   # comes with sane
sudo iscan
```
uninstall:
```Shell
dpkg --remove iscan-data_1.36.0-1_all iscan_2.30.1-1~usb0.1.ltdl7_amd64
```


### Root privileges needed for scanning (why?!)

    xscanimage

>Failed to open device 'epkowa:usb:003:004': Access to ressource has been denied.

    adduser [options] user group

http://wiki.ubuntuusers.de/Brother/Scanner

Find out what is being done (communication with linux kernel)
```Shell
strace xscanimage 2>&1 | grep EACCES | sort -u
```

>open("/dev/bus/usb/001/001", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/001/002", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/002/001", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/002/002", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/002/003", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/002/004", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/002/005", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/002/006", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/003/001", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/003/002", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/003/003", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/003/004", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/004/001", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/004/002", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/004/003", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/004/004", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/005/001", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/bus/usb/006/001", O_RDWR)    = -1 EACCES (Permission denied) </br>
>open("/dev/port", O_RDWR|O_NOCTTY)      = -1 EACCES (Permission denied) </br>
>open("/dev/sg0", O_RDWR|O_NONBLOCK)     = -1 EACCES (Permission denied) </br>
>open("/dev/sg1", O_RDWR|O_NONBLOCK)     = -1 EACCES (Permission denied) </br>
>open("/dev/sg2", O_RDWR|O_NONBLOCK)     = -1 EACCES (Permission denied) </br>
>open("/dev/sg3", O_RDWR|O_NONBLOCK)     = -1 EACCES (Permission denied) </br>
>open("/dev/sg5", O_RDWR|O_NONBLOCK)     = -1 EACCES (Permission denied) </br>
>open("/dev/sg6", O_RDWR|O_NONBLOCK)     = -1 EACCES (Permission denied) </br>
>open("/dev/sg7", O_RDWR|O_NONBLOCK)     = -1 EACCES (Permission denied) </br>

```Shell
lsusb | grep Epson
    Bus 003 Device 004: ID 04b8:0865 Seiko Epson Corp. ME OFFICE 520 Series
        => printer is at /dev/bus/usb/003/004 xscanimage seems to try out every usb port to find the scanner ...
la /dev/bus/usb/003/004
    crw-rw-r-- 1 root lp 189, 259 Aug 12 04:39 /dev/bus/usb/003/004
=> we would have write (communication) access, if we  would be in lp-group
sudo adduser $USER lp  # may be necessary to reboot :S?
```
Now I get:
>Failed to open device: Device busy
This was because I tried to solve permissions by uncommenting this:

    /etc/sane.d/dll.conf
        epson
        epson2
    change it back to:
        #epson
        epson2
    sudo service saned restart

Also turn scanner off and again on, because a bad or incomplete command seems to have been sent because of the use of `epson` instead of `epson2` interface ...

    xscanimage

  -> working :)

    iscan  # there is also launcher in start->graphics->Image Scan!

  => gott... da habe ich aber wieder tief ins system greifen müssen, um das hinzubiegen -.-... darf einfach nicht sein!


### Use other compression algorithm instead of .tar.gz for duplicity

Because opening files only to get filenames takes ages -.-, or create some kind of file list.
```Shell
duplicity uses the compression of gpg, this is configurable via --gpg-options
e.g. --gpg-options="--compress-algo=bzip2 --bzip2-compress-level=9"
duplicity list-current-files file:///media/d/Linux/backups/pc/config/
```

    Synchronizing remote metadata to local cache...                                                
    Copying duplicity-full-signatures.20150811T195003Z.sigtar.gz to local cache.                   
    Copying duplicity-full.20150811T195003Z.manifest to local cache.                               
    Copying duplicity-inc.20150811T195003Z.to.20150811T200223Z.manifest to local cache.            
    Copying duplicity-new-signatures.20150811T195003Z.to.20150811T200223Z.sigtar.gz to local cache.
    Last full backup date: Tue Aug 11 21:50:03 2015                                                
    Tue Aug 11 17:58:53 2015 .                                                                     
    Tue Aug 11 21:56:35 2015 etc                                                                   
    Sun Aug  9 15:10:22 2015 etc/X11                                                               
    Sat Jun 27 08:00:50 2015 etc/X11/xorg.conf.d                                                   
    Sat Jun 27 08:00:50 2015 etc/X11/xorg.conf.d/20-intel.conf                                     
    Fri Jul  3 01:21:53 2015 etc/X11/xorg.conf.d/50-synaptics.conf                                 
    Tue Aug 11 21:31:19 2015 etc/apt                                                               
    Fri Aug  7 06:51:56 2015 etc/apt/apt.conf.d                                                    
    Fri Aug  7 06:45:43 2015 etc/apt/apt.conf.d/00CDMountPoint                                     

  => just look in the sigtar files for filenames, although that may not simplify actually extracting a sought for file


### find out the PPA to which a package belongs to
```Shell
apt-cache policy xarchiver
```


### Audacious plays only one song in playlist, must skip manually

 - https://bugs.launchpad.net/ubuntu/+source/audacious/+bug/225391
 - http://redmine.audacious-media-player.org/projects/audacious/issues/new
   make bugreport or try to upgrade to newest version :S
 - http://audacious-media-player.org/download
 - Press Ctrl+N

**Solution:**
```Shell
mv ~/.config/audacious ~/.config/audacious.old
```

Finding out whichs setting exactly was at fault:
```Diff
diff .config/audacious/config .config/audacious-play-next-bug/config
1a2,13
> [alsa]
> mixer-element=Master
>
> [audacious]
> no_playlist_advance=TRUE    # <---- FUCKING THIS !!!
>
> [audgui]
> filebrowser_win=332,137,700,450
> playlist_manager_win=482,237,400,250
> queue_manager_win=482,237,400,250
> url_opener_win=482,303,400,117
>
5,6c17,20
< player_x=579
< player_y=279
---
> player_height=501
> player_width=701
> player_x=284
> player_y=267
9a24,27
>
> [skins]
> playlist_visible=TRUE
> skin=/usr/share/audacious/Skins/Default
```
Common subdirectories: `~/.config/audacious/playlists` and `~/.config/audacious-play-next-bug/playlists`
```Diff
diff .config/audacious/playlist-state .config/audacious-play-next-bug/playlist-state
2c2
< playing 0
---
> playing -1
4c4
< position 4
---
> position 0
6c6
< resume-time 297780
---
> resume-time 0
```
Only in `~/.config/audacious-play-next-bug/`: plugin-registry

  => Actually this option can also be toggled in playlist->no playlist advance <kbd>Ctrl</kbd>+<kbd>N</kbd>` ... -.- of course


### openid

openid.stackexchange.com



### VLC sound not working anymore / no sound

VLC for some reason suddenly choose HDMI sound device output instead of standard device -> <kbd>Alt</kbd>+<kbd>a</kbd>->audio device->choose correct one



### Can't get wlan0 up

```Shell
sudo ip link set wlan0 up
    RTNETLINK answers: Operation not possible due to RF-kill
# did not test, whether this blacklisting is really necessary
sudo bash -c 'echo "blacklist hp_wmi"> /etc/modprobe.d/blacklist-hp_wmi.conf'
reboot
sudo apt-get install rfkill
sudo rfkill list          # shows 'Wireless LAN' as '1' to be softblocked
sudo rfkill unblock 1
#sudo rfkill unblock all
sudo rfkill list
```

### Move to trash instead of deleting file
```Shell
sudo apt-get install trash-cli
```
and then use trash instead of `rm` or use
```Shell
alias rm='trash'
```


### Change Terminal title, to better differentiate it in taskbar

```Shell
set | grep PS1
    PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
PS1="\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ "
echo -en "\033];local HZDR\a"
set_title () {
    PS1="\033];$1\a${debian_chroot:+($debian_chroot)}\u@\h:\w\$ "  # command prompt style
    echo -en "\033];$1\a"
}
# unset set_title
```


### Cant connect to WLAN after connecting to eth0:

```Shell
sudo ifdown eth0
wlanconnect
# or next time try to adjust routing order:
ip route show
ip route add default via 192.168.1.254
ip route delete 192.168.1.0/24 dev eth0
```

### Thunar/xarchiver 'Extract here' only extracts first selection, instead of every archive selected

```Shell
vim /usr/lib/thunar-archive-plugin/xarchiver.tap
    case $action in
    create)
        exec xarchiver "--add-to=$@"
        ;;

    extract-here)
        # --multi-extract does not seem to work, so we will just use a loop
        # not sure here whether $@ vs. $* to use, both seem to work for me
        for name in "$@"; do
            xarchiver "--extract-to=$folder" "'$name'"
        done
        ;;

    extract-to)
        exec xarchiver --extract "$@"
        ;;

    *)
        echo "Unsupported action '$action'" >&2
        exit 1
    esac
```

### USB only writable as root even when mounted by xfce/Thunar volume manager

remount manually ... :(
```Shell
sudo umount /media/usb0
sudo mount /dev/sdb1 /media/transcend -ouser,umask=0000
```
Maybe some options in volume manager exist?

Volume Manager reads options from fstab, if device is listed there, so either uncomment these lines:

    #/dev/sdb1               /media/usb0     auto    rw,user,noauto  0       0
    #/dev/sdb2               /media/usb1     auto    rw,user,noauto  0       0

or do a

    sudo chmod a+rwx /media/usb*


### Crontab isn't running

    sudo vim /etc/crontab

=> see that it would have been run between 6 and 7 o'clock, when the notebook is not running in most days ...

Change it to 16 or 20 o'clock.

Or install `anacron` (or fcron ... not recommended), to run cronjobs after the pc is turned on and some cronjobs were missing in the meantime
http://serverfault.com/questions/52335/job-scheduling-using-crontab-what-will-happen-when-computer-is-shutdown-during
```Shell
mv /etc/crontab /etc/anacrontab
touch /etc/crontab
```


### Hide Firefox title bar when maximized:

https://addons.mozilla.org/de/firefox/addon/hide-caption-titlebar-plus-sma/
