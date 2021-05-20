#!/usr/bin/env bash
#############################################################
# Magisk ChromeBook Chrome OS Rammus Recovery Image Patcher #
# modded by NewBit XDA                                      #
#############################################################


GainRoot() {
	if [ $(id -u) != 0 ]; then
	  #echo "run:"
	  #echo "cd \$HOME && sudo curl -LO https://raw.githubusercontent.com/newbit1/rootCROS/master/rootCROS.sh && sudo chmod +x && bash ./rootCROS.sh"
	  #echo "sudo bash ./rootCROS.sh"
	  sudo bash -c "exec bash $0 $@"
	  exit 0
	fi
}

ChangeLocation() {
	local WORKDIR=/usr/local
	BASEDIR=$WORKDIR/crosswork
	local CURDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

	if [ ! -e "$BASEDIR" ]; then
		mkdir -p $BASEDIR
	fi
	
	if [ "$CURDIR" != "$BASEDIR" ]; then
		echo "[-] Moving to the location $BASEDIR"
		cp "$0" $BASEDIR
		cd $BASEDIR
		echo "[*] Re-Execute the script proper"
		bash -c "exec ./$0 $@"
		exit 0
	fi
		
	export BASEDIR
}

ProcessArguments() {

	RemountDrive=false
	CleanUpMounts=false
	
	# Overlay Directorys
	FM=$BASEDIR/FM
	TO=$BASEDIR/to
	TEMP=$BASEDIR/temp
	FIN=$BASEDIR/fin
	DRIVE=/
	
	TMPDIR=$BASEDIR/tmp
	
	ANDROIROOTDIR=/opt/google/containers/android/rootfs/root
	SYSRAWIMG=/opt/google/containers/android/system.raw.img
	
	#RECOVERYIMG=/home/$USER/Downloads/chromeos_13816.64.0_rammus_recovery_stable-channel_mp-v2.bin.img
	# ROOT-A contains the android container system and vendor
	#ROOTA=/dev/loop0p3
	#ROOTA=/media/newbit/ROOT-A
	
		
	#ANDROIDATADIR=/opt/google/containers/android/rootfs/android-data
	ADBWORKDIR=/data/data/com.android.shell
	ADBBASEDIR=$ADBWORKDIR/Magisk
	
	if [[ "$@" == *"CleanUpMounts"* ]]; then
		CleanUpMounts=true
	fi

	if [[ "$@" == *"RemountDrive"* ]]; then
		RemountDrive=true
	fi

	export FM
	export TO
	export TEMP
	export FIN
	export DRIVE
	
	export TMPDIR
	
	export ANDROIROOTDIR
	export SYSRAWIMG

	export ADBWORKDIR
	export ADBBASEDIR
	
	export RemountDrive
	export CleanUpMounts
}

DownloadAssets() {
	echo "PWD=$PWD"
	TARGET=rootAVD.sh
	if [ ! -e "$TARGET" ]; then
		echo "[-] Downloading $TARGET"
		curl -# -LO https://github.com/newbit1/rootAVD/raw/master/$TARGET && chmod +x $TARGET
	else
		echo "[-] $TARGET already there"
	fi
	ROOTAVD=$BASEDIR/$TARGET
	
	TARGET=Magisk.zip
	if [ ! -e "$TARGET" ]; then
		echo "[*] Downloading $TARGET"
		curl -# -LO https://github.com/newbit1/rootAVD/raw/master/$TARGET
	else
		echo "[*] $TARGET already there"
	fi
	MZ=$BASEDIR/$TARGET

	TARGET=busybox
	if [ ! -e "$TARGET" ]; then
		echo "[-] Downloading $TARGET"
		curl -# -L https://github.com/Magisk-Modules-Repo/busybox-ndk/raw/master/$TARGET-x86_64 -o $TARGET && chmod +x $TARGET
	else
		echo "[-] $TARGET already there"
	fi
	BB=$BASEDIR/$TARGET
	
	export ROOTAVD
	export MZ
	export BB	
}

CreateFakeRamdisk() {
	echo "[*] Creating Fake ramdisk.img"
	RAMDISKDIR=$TMPDIR/fakeramdisk
	CPIO=$BASEDIR/ramdisk.cpio
	rm -rf $RAMDISKDIR
	mkdir -p $RAMDISKDIR
	echo "[*] Copy files..."
	cp $ANDROIROOTDIR/init $RAMDISKDIR
	#cp $ANDROIROOTDIR/fstab.cheets $RAMDISKDIR
	echo "[*] Packing fake ramdisk.img..."
	cd $RAMDISKDIR > /dev/null
		`$BB find . | $BB cpio -H newc -o | $BB gzip > $BASEDIR/ramdisk.img`
	cd - > /dev/null
	rm -rf $RAMDISKDIR
	export RAMDISKDIR
}

PatchFakeRamdisk() {
	echo "[*] Cleaning up the ADB working space"
	adb shell rm -rf $ADBBASEDIR
	echo "[*] Creating the ADB working space"
	adb shell mkdir $ADBBASEDIR
	adb push * $ADBBASEDIR
	adb shell sh $ADBBASEDIR/rootAVD.sh $@	
	#$ROOTAVD $BASEDIR/ramdisk.img
	adb pull $ADBBASEDIR/ramdiskpatched4AVD.img $BASEDIR/ramdisk.img
	adb pull $ADBBASEDIR/Magisk.apk
	echo "[*] Trying to install Magisk.apk"
	adb install -r -d Magisk.apk
}

RemountDrive() {
	mount -o remount,rw $DRIVE
}

CleanUp() {
	echo "[*] cleaning up $1"
	fuser -k "$1" > /dev/null 2>&1 &
	pids=" $!"
	wait $pids
	umount "$1" > /dev/null 2>&1 &
	pids=" $!"
	wait $pids
	rm -r "$1" > /dev/null 2>&1 &
    pids=" $!"
	wait $pids
}

CleanUpMounts() {
	CleanUp $FM
	CleanUp $TO
	CleanUp $TEMP
	CleanUp $FIN
	#CleanUp $MAGISKDIR
	#CleanUp $BB
	#for file in magisk*; do
	#	CleanUp $file
	#done
}

CreateOverlayMounts() {
	mkdir $FM
	mkdir $TO
	mkdir $TEMP
	mkdir $FIN
	mount $SYSRAWIMG $FM -t squashfs -o loop
	mount -t overlay -o lowerdir=$FM,upperdir=$TO,workdir=$TEMP overlay $FIN
}

MountAndroidRaws() {
	mount /media/newbit/ROOT-A/opt/google/containers/android/system.raw.img /media/newbit/ROOT-A/opt/google/containers/android/rootfs -t squashfs -o loop
	mount /media/newbit/ROOT-A/opt/google/containers/android/vendor.raw.img /media/newbit/ROOT-A/opt/google/containers/android/rootfs/vendor -t squashfs -o loop
	umount /media/newbit/ROOT-A/opt/google/containers/android/vendor.raw.img
	umount /media/newbit/ROOT-A/opt/google/containers/android/system.raw.img
}

ReadContextPerm() {
	echo "[*] Reading Contexts and Permissions"
	FILEUID=$(sudo stat -c %u $FIN/init)
	FILEGID=$(sudo stat -c %g $FIN/init)
	echo "init UID=$FILEUID GID=$FILEGID"
	FILEPERM=$(sudo stat -c %#a $FIN/init)
	
	INITCONTEXT=$(ls -Z $FIN/init)
	for i in $INITCONTEXT; do
		INITCONTEXT=$i
		break
	done	
	echo "INITCONTEXT=$INITCONTEXT"

	DIRUID=$(sudo stat -c %u $FIN/sbin)
	DIRGID=$(sudo stat -c %g $FIN/sbin)
	echo "sbin UID=$DIRUID GID=$DIRGID"	
	SBINCONTEXT=$(ls -dZ $FIN/sbin)
	for i in $SBINCONTEXT; do
		SBINCONTEXT=$i
		break
	done	
	echo "SBINCONTEXT=$SBINCONTEXT"
	
	export FILEUID
	export FILEGID
	export INITCONTEXT
	export DIRUID
	export DIRGID
	export SBINCONTEXT
}

SetPerm() {
	# SET PERM from $1 to $2
	echo "[*] Set Permissions and Context from $1 to $2"
	chcon --reference=$1 $2	
	chown $(sudo stat -c %u $1):$(sudo stat -c %g $1) $2
	chmod $(sudo stat -c %#a $1) $2	
}

PatchOverlayWithFakeRamdisk() {
	echo "[*] Patching Overlay with fake ramdisk.img"
	mv $BASEDIR/ramdisk.img $BASEDIR/ramdisk.cpio.gz
	$BB gzip -d $BASEDIR/ramdisk.cpio.gz
	#mkdir -p $RAMDISKDIR
	echo "[-] Extracting ramdisk.cpio to overlay System"
	cd $FIN > /dev/null
		cat $BASEDIR/ramdisk.cpio | $BB cpio -i > /dev/null 2>&1
	cd - > /dev/null

	SetPerm $ANDROIROOTDIR/init $FIN/init
	
	#chcon --reference=/opt/google/containers/android/rootfs/root/init /usr/local/crosswork/fin/init

	#SetPerm $FIN/sbin $FIN/.backup
	#chmod 000 -R $FIN/.backup
	stat -c %C%u%g%#a $ANDROIROOTDIR/init
	stat -c %C%u%g%#a $FIN/init

	SetPerm $ANDROIROOTDIR/sbin $FIN/overlay.d
	SetPerm $ANDROIROOTDIR/sbin $FIN/overlay.d/sbin
	SetPerm $ANDROIROOTDIR/sbin $FIN/overlay.d/sbin/magisk32.xz
	SetPerm $ANDROIROOTDIR/sbin $FIN/overlay.d/sbin/magisk64.xz
}

makeSQUASHFS() {
	echo "[-] Generating SquashFS with Magisk"
	mksquashfs $FIN $SYSRAWIMG.magisk
}

create_backup() {
	local BACKUPFILE=""
	local FILE=""
	FILE="$1"
	BACKUPFILE="$FILE.backup"
	# If no backup file exist, create one

	if [ ! -e "$BACKUPFILE" ]; then
		echo "[*] create Backup File of $FILE"
		mv $SYSRAWIMG $BACKUPFILE
	else
		echo "[-] $FILE Backup exists already"
	fi
}

setMagiskSQUASHFStoSYSTEM() {
	echo "[*] Set Magisk SquashFS System"
	mv $SYSRAWIMG.magisk $SYSRAWIMG
}

GainRoot
ChangeLocation
ProcessArguments $@

#####
$RemountDrive && RemountDrive && exit 0
$CleanUpMounts && CleanUpMounts && exit 0
#####

DownloadAssets
CreateFakeRamdisk
PatchFakeRamdisk

CleanUpMounts
RemountDrive

CreateOverlayMounts
read -p "Make your changes and Enter when finshed to continue" </dev/tty
PatchOverlayWithFakeRamdisk
read -p "Make your changes and Enter when finshed to continue" </dev/tty
makeSQUASHFS
create_backup $SYSRAWIMG
setMagiskSQUASHFStoSYSTEM
CleanUpMounts

exit 0

#ReadContextPerm


exit 0

#cp --preserve=context
sudo mv /media/$USER/fin/init /media/$USER/fin/.backup/init
sudo chmod -R 000 /media/$USER/fin/.backup
sudo cp /home/$USER/rootCHROS/ramdisk.img/init /media/$USER/fin/
sudo stat sudo /media/$USER/fin/init
sudo chown -R $FILEUID.$FILEGID /media/$USER/fin/init
sudo apt install policycoreutils-python-utils

sudo cp --preserve=context /home/$USER/rootCHROS/ramdisk.img/init /media/$USER/fin/
sudo semanage fcontext -a -e /media/$USER/fin/init.rc /media/$USER/fin/init


sudo mv /media/$USER/ROOT-A1/opt/google/containers/android/system.raw.img /media/$USER/ROOT-A1/opt/google/containers/android/system.raw.img.bak
sudo mv /media/$USER/ROOT-A1/opt/google/containers/android/system.raw.img.magisk /media/$USER/ROOT-A1/opt/google/containers/android/system.raw.img

exit
