#!/usr/bin/env bash
cd -- "$( dirname -- "$( readlink -f -- "${BASH_SOURCE[0]}" )" )"
APPDIR=$( pwd )

# Not using firejail because by default everything is available, including all mount points.
# This is exactly what I want to avoid!
#firejail --chroot="$PWD" --profile=firejail.conf --private="$PWD/home" --blacklist=/ "$PWD/AppRun" --no-sandbox

cd -- "$APPDIR"
mkdir -p home/{.config,.cache} run-user

args=()

# Unfortunately, it is near impossible to further cut down the /usr bind because at least 'sh', but also 'which',
# and possibly 'git' and other tools will be needed in the integrated Code editor shell.
# Too bad that this makes all installed programs of the host visible that way.
# I guess the next level of sandboxing would really be a container, but I don't wanna run docker as root.
# Examples:
#   https://github.com/containers/bubblewrap/blob/main/demos/bubblewrap-shell.sh
#   https://github.com/containers/bubblewrap/blob/main/demos/flatpak-run.sh
#   https://wiki.archlinux.org/title/Bubblewrap
robinds=(
  # Many of these are symlinks!
  #   bin -> usr/bin
  #   lib -> usr/lib
  #   lib32 -> usr/lib32
  #   lib64 -> usr/lib64
  #   libx32 -> usr/libx32
  #   sbin -> usr/sbin
  /lib
  /lib64
  /sbin
  /bin
  #/usr/sbin
  # Host Google Chrome for OAuth. (It has a built-in electron browser, so why is that not used -.-?)
  #/usr/bin
  /etc/alternatives
  /opt/google/chrome
  # Fonts and GUI / GTK, ...
  #/usr/share
  /etc/fonts
  /etc/scite
  # Internet access requires:
  /etc/resolv.conf
  /sys/class/net
  /sys/devices/virtual/net
  # git clone / libcurl:
  #/usr/lib/git-core
  #/usr/lib/python3
  #/usr/lib/python3.12
  /etc/ssl
  # Had crash:
  #   (codium:2): Gtk-WARNING **: 00:12:23.813: Could not load a pixbuf from /org/gtk/libgtk/icons/16x16/actions/dialog-information.png.
  #   This may indicate that pixbuf loaders or the mime database could not be found.
  #   **
  #   Gtk:ERROR:../../../gtk/gtkiconhelper.c:495:ensure_surface_for_gicon: assertion failed (error == NULL): Failed to load /org/gtk/libgtk/icons/48x48/status/image-missing.png: Unrecognized image file format (gdk-pixbuf-error-quark, 3)
  #   Bail out! Gtk:ERROR:../../../gtk/gtkiconhelper.c:495:ensure_surface_for_gicon: assertion failed (error == NULL): Failed to load /org/gtk/libgtk/icons/48x48/status/image-missing.png: Unrecognized image file format (gdk-pixbuf-error-quark, 3)
  /usr
  # For X11 display access
  /tmp/.X11-unix
)
for robind in "${robinds[@]}"; do
    if [[ -e "$robind" ]]; then
        args+=(--ro-bind "$robind" "$robind")
    fi
done

#binds=(
#    /run/dbus/system_bus_socket
#)
#for bind in "${binds[@]}"; do
#    args+=(--bind "$bind" "$bind")
#done

# Clicking the underlined "Continue" link int he Continue plugin ReadMe, I got this error:
#   (codium:2): Gtk-WARNING **: 00:12:23.813: Could not load a pixbuf from /org/gtk/libgtk/icons/16x16/actions/dialog-information.png.
#   This may indicate that pixbuf loaders or the mime database could not be found.
#   **
#   Gtk:ERROR:../../../gtk/gtkiconhelper.c:495:ensure_surface_for_gicon: assertion failed (error == NULL): Failed to load /org/gtk/libgtk/icons/48x48/status/image-missing.png: Unrecognized image file format (gdk-pixbuf-error-quark, 3)
#   Bail out! Gtk:ERROR:../../../gtk/gtkiconhelper.c:495:ensure_surface_for_gicon: assertion failed (error == NULL): Failed to load /org/gtk/libgtk/icons/48x48/status/image-missing.png: Unrecognized image file format (gdk-pixbuf-error-quark, 3)
# https://bbs.archlinux.org/viewtopic.php?id=266852
# -> Setting XDG_DATA_DIRS fixes this.

# By default the environment is inherited even through bubblewrap! So disable that with env -i.
# A writable /run/user/1000 is necessary because the Electron app opens some IPC socket there.
# Display / X11 access requires:
#    DISPLAY="$DISPLAY" \
#    /tmp/.X11-unix \
env -i bwrap \
  --die-with-parent \
  --new-session \
  --dev /dev \
  --tmpfs /tmp \
  --proc /proc \
  --unshare-all \
  --share-net \
  --bind "$APPDIR/home" /home/user \
  --ro-bind "$APPDIR" /opt/app \
  --setenv USER user \
  --setenv TERM "$TERM" \
  --setenv DISPLAY "$DISPLAY" \
  --setenv HOME /home/user \
  --bind run-user /run/user/1000 \
  --setenv XDG_RUNTIME_DIR /run/user/1000 \
  --setenv XDG_CONFIG_HOME "/home/user/.config" \
  --setenv XDG_DATA_DIRS "$XDG_DATA_DIRS" \
  --setenv XDG_CACHE_HOME "/home/user/.cache" \
  "${args[@]}" \
  bash /opt/app/AppRun --no-sandbox
