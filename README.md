### Notes
```
cd $PORTAGE_CONFIGROOT 
sudo su
curl -LO https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh
chmod +x ./rootCROS.sh
[OPTIONS]
bash ./rootCROS.sh
reboot

[OPTIONS]:
export restore=true
unset restore
export DEBUG=true
unset DEBUG
```
cd $HOME && sudo cp /media/fuse/crostini_6dbef25a0b67e29ada32b2b515c7e2335015d18e_termina_penguin/rootCROS/rootCROS.sh $HOME && bash ./rootCROS.sh && cd - \
cd $HOME && sudo curl -LO https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh && sudo chmod +x ./rootCROS.sh && bash ./rootCROS.sh && cd - \
cd $HOME/rootCROS && git add . && git commit -m "updates" && git push \

### Links
* [ChromeOS R90 Stable Rammus](https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13816.64.0_rammus_recovery_stable-channel_mp-v2.bin.zip)

### Credits
* [topjohnwu Magisk](https://github.com/topjohnwu/Magisk/releases)
* [osm0sis - Busybox for Android NDK](https://github.com/Magisk-Modules-Repo/busybox-ndk)
* [nolirium - aroc](https://github.com/nolirium/aroc)
* [sebanc - Brunch framework](https://github.com/sebanc/brunch)

