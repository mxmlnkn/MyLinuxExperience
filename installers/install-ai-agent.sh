#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "$( readlink -f -- "${BASH_SOURCE[0]}" )" )" && pwd )

wget 'https://github.com/VSCodium/vscodium/releases/download/1.103.05312/VSCodium-1.103.05312.glibc2.29-x86_64.AppImage'
./VSCodium*.AppImage --appimage-extract
APPDIR=VSCodium.AppDir
mv squashfs-root "$APPDIR"

# Fix libselinux.so.1 AppImage problem:
#     sed: /opt/app/lib/x86_64-linux-gnu/libselinux.so.1: no version information available (required by sed)
SOURCE_LIBSELINUX=$( ldconfig -p | sed -nE 's|.* => (/.*x86_64.*libselinux[.]so[.]1.*)|\1|p' | tail -1 )
TARGET_LIBSELINUX=$( find "$APPDIR" -name 'libselinux.so.1' | tail -1 )
if [[ -f "$SOURCE_LIBSELINUX" && -f "$TARGET_LIBSELINUX" ]]; then
    'cp' -- "$SOURCE_LIBSELINUX" "$TARGET_LIBSELINUX"
fi

# AppImage also has --appimage-portable-home and --appimage-portable-config options, which could work.
mkdir -p -- "$APPDIR/home" &&
(
    cd -- "$APPDIR/home"
    # MyLinuxExperience is the most important one for bashrc and the AppRun sandbox wrapper.
    for project in MyLinuxExperience ratarmount indexed_bzip2 mfusepy; do
        if [[ ! -e "$project" ]]; then
            git clone --recursive "https://github.com/mxmlnkn/${project}.git"
        fi
    done
    if test -e ".bashrc" && ! 'grep' -q MyLinuxExperience ".bashrc"; then
        echo 'test -f ~/MyLinuxExperience/.bashrc && . ~/MyLinuxExperience/.bashrc' >> ".bashrc"
    fi
    for name in .bashrc .vimrc .inputrc .config; do
        if [[ ! -e "$name" ]]; then
            ln -s "MyLinuxExperience/$name" "$name"
        fi
    done
)

cp -- "$SCRIPT_DIR/VSCodium-AppRun-Sandboxed.sh" "$APPDIR/AppRun-Sandboxed"
chmod u+x "$APPDIR/AppRun-Sandboxed"
# Remove x permissions to avoid accidental non-sandboxed starts.
chmod u-x "$APPDIR/AppRun"
ln -s -- "$APPDIR/AppRun-Sandboxed" ~/bin/vscodium

# Extensions to install:
#  - https://github.com/RooCodeInc/Roo-Code/
#  - ms-python
#  - Bookmarks: https://github.com/alefragnani/vscode-bookmarks.git
