# This Repo will be archived at the 24th of Oct 2023
# Due to the forced 2FA Mumbo Jumbo from GitHub,
# this Repo has moved to GitLab
# [rootCROS](https://gitlab.com/newbit/rootCROS)
### [newbit @ xda-developers](https://forum.xda-developers.com/m/newbit.1350876)
A Script to...
* root your Google Chrome OS Rammus, Samus and Atlas installed on a non Chromebook Device

### Preconditions
* Device is installed via [sebanc - Brunch framework](https://github.com/sebanc/brunch)
* User is logged in
* Chrome OS developer shell is opened via **ctrl+alt+t** -> `crosh> shell`
* `sudo mount -o remount,rw /` works
* adb is up -> `adb start-server`

### Usage
```
cd $PORTAGE_CONFIGROOT && sudo su
curl -LO https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh

[OPTIONS]
bash ./rootCROS.sh
reboot

[OPTIONS]:
export restore=true
unset restore
export DEBUG=true
unset DEBUG
```
### Limitations
* Only Magisk / su is installed and available
* Magiskinit does **NOT** replace stock init -> doesn't work (yet)
  * Hence, Modules are not working as well
  * and everything else that is Magisk Mirror Mount related

### Change Logs
#### [November 2021]
* [rootCROS.sh] - Added Samus R91 (x86-only) and Atlas R93 support
#### [October 2021]
* [rootCROS.sh] - Added squashfs-tools v4.4 from Brunch r90 stable 20210523

<details>
<summary>Internal Notes</summary>
cd $HOME && sudo cp /media/fuse/crostini_6dbef25a0b67e29ada32b2b515c7e2335015d18e_termina_penguin/rootCROS/rootCROS.sh $HOME && bash ./rootCROS.sh && cd - \
cd $HOME && sudo curl -LO https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh && sudo chmod +x ./rootCROS.sh && bash ./rootCROS.sh && cd - \
cd $HOME/rootCROS && git add . && git commit -m "updates" && git push \
curl -v -H "Cache-Control: no-cache" https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh

</details>

### Tested on
* ChromeOS R91 Stable Samus + Brunch r93 stable 20211002
* ChromeOS R93 Stable Atlas + Brunch r93 stable 20211002
* ChromeOS R93 Stable Rammus + Brunch r93 stable 20211002
* ChromeOS R90 Stable Rammus + Brunch r90 stable 20210523

### Links
* [ChromeOS R91 Stable Samus](https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13904.77.0_samus_recovery_stable-channel_mp-v3.bin.zip)
* [ChromeOS R93 Stable Atlas](https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_14092.77.0_atlas_recovery_stable-channel_mp.bin.zip)
* [ChromeOS R93 Stable Rammus](https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_14092.77.0_rammus_recovery_stable-channel_mp-v2.bin.zip)
* [Brunch r93 stable 20211002](https://github.com/sebanc/brunch/releases/tag/r93-stable-20211002)
* [ChromeOS R90 Stable Rammus](https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_13816.64.0_rammus_recovery_stable-channel_mp-v2.bin.zip)
* [Brunch r90 stable 20210523](https://github.com/sebanc/brunch/releases/tag/r90-stable-20210523)

### Credits
* [topjohnwu Magisk](https://github.com/topjohnwu/Magisk/releases)
* [osm0sis - Busybox for Android NDK](https://github.com/Magisk-Modules-Repo/busybox-ndk)
* [nolirium - aroc](https://github.com/nolirium/aroc)
* [sebanc - Brunch framework](https://github.com/sebanc/brunch)

<img src="https://user-images.githubusercontent.com/37043777/120075201-99a59c80-c0a0-11eb-876e-4c4ebea03844.png" width="200" height="200" />
