### Notes

curl -LO https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh && chmod +x rootCROS.sh \
curl -LO https://github.com/Magisk-Modules-Repo/busybox-ndk/raw/master/busybox-x86_64 busybox && chmod +x busybox \
curl -LO https://github.com/newbit1/rootCROS/raw/master/Magisk.zip \

sudo rm rootCROS.sh; sudo curl -LO https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh && sudo chmod +x rootCROS.sh

curl -Ls https://raw.githubusercontent.com/nolirium/aroc/master/01Root.sh | sudo sh
curl -LO https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh | sudo sh

git add . && git commit -m "updates" && git push

### Links
* [ChromeOS R90 Stable Rammus](https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13816.64.0_rammus_recovery_stable-channel_mp-v2.bin.zip)

### Credits
* [topjohnwu Magisk](https://github.com/topjohnwu/Magisk/releases)
* [osm0sis - Busybox for Android NDK](https://github.com/Magisk-Modules-Repo/busybox-ndk)
* [nolirium - aroc](https://github.com/nolirium/aroc)
* [sebanc - Brunch framework](https://github.com/sebanc/brunch)

