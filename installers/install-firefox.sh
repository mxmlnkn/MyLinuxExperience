# Not a fully-tested script. Copy-paste as desired.
exit 1

wget 'https://ftp.mozilla.org/pub/firefox/releases/140.1.0esr/linux-x86_64/en-US/firefox-140.1.0esr.tar.xz'
cp -r f
if [[ -e firefox ]]; then
    cp -r firefox/distribution .
    mv firefox firefox "firefox-$( date +%Y-%m-%d )"
fi
tar -xf firefox*.tar*

mv distribution firefox/
chmod -R a-w firefox
sudo chown root firefox

cd ~/.mozilla/firefox/
tar --use-compress-program=lbzip2 -cf "firefox-profiles-$( date +%Y-%m-%d ).tar.bz2" */

# https://github.com/Izheil/Quantum-Nox-Firefox-Dark-Full-Theme/tree/master/Multirow%20and%20other%20functions/JS%20Loader
git clone 'https://github.com/Izheil/Quantum-Nox-Firefox-Dark-Full-Theme.git'
cd 'Quantum-Nox-Firefox-Dark-Full-Theme/Multirow and other functions'
cp -r 'JS Loader/root/'* /opt/firefox/
cp -r 'JS Loader/utils' ~/.mozilla/firefox/ff-84-personal/chrome/
cp 'Multirow tabs/MultiRowTab-scrollable.uc.js' ~/.mozilla/firefox/ff-84-personal/chrome/
    "The files inside the "utils" folder will enable both *.uc.js and *.as.css files inside your chrome folder."
        -> mv userChrome.css and userChrome.js and userMenus.css into .uc.js or .uc.css files

vim ~/.mozilla/firefox/ff-84-personal/chrome/MultiRowTab-scrollable.uc.js
#    Set --tab-growth to 1
#    Set --max-tab-rows: 2;

# Necessary to apply userChrome changes
rm -rf ~/.cache/mozilla/firefox/*/startupCache/

# /opt/firefox/firefox -P ff-profile
 #about:config -> browser.tabs.tabMinWidth -> Set to 100
