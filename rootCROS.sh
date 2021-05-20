#!/usr/bin/env bash
#############################################################
# Magisk ChromeBook Chrome OS Rammus Recovery Image Patcher #
# modded by NewBit XDA                                      #
#############################################################


checksudo() {
	if [ $(id -u) != 0 ]; then
	  echo "run sudo bash ./rootCROS.sh"
	  sudo bash "$0"
	  exit 1
	fi
}

ProcessArguments() {
	# cleanup
	RemountDEVICE=false
	
	
	ADBWORKDIR=/opt/google/containers/android/rootfs/android-data/data/data/com.android.shell
	ADBBASEDIR=$ADBWORKDIR/crosswork
	
	WORKDIR=/usr/local
	BASEDIR=$WORKDIR/crosswork
	
	CURDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
	
	echo "[-] Switch to the location $BASEDIR"
	echo "[-] CURDIR=$CURDIR"
	set -x
	if [ "$CURDIR" != "$BASEDIR" ]; then
		if [ ! -e "$BASEDIR" ]; then
			mkdir -p $BASEDIR
		fi
		cp "$0" $BASEDIR
		echo "00=$0"
		echo "cd $BASEDIR" > $BASEDIR/curdir.sh
		source $BASEDIR/curdir.sh
		bash -c "exec $BASEDIR/curdir.sh"
		bash -c "exec -l $0 $@"
		
		echo "[!] to far"
		exit 0
	fi
	echo "[*] worked"
	
	exit 0
	RECOVERYIMG=/home/$USER/Downloads/chromeos_13816.64.0_rammus_recovery_stable-channel_mp-v2.bin.img
	# ROOT-A contains the android container system and vendor
	#ROOTA=/dev/loop0p3
	ROOTA=/media/newbit/ROOT-A
	DEVICE=$ROOTA
	SYSRAWIMG=$ROOTA/opt/google/containers/android/system.raw.img
	
	if [[ "$@" == *"CleanUpMounts"* ]]; then
		PrepBusyBoxAndMagisk
		CleanUpMounts
		exit 1
	fi

	if [[ "$@" == *"RemountDEVICE"* ]]; then
		RemountDEVICE=true
	fi

	export BASEDIR
	export RECOVERYIMG
	export ROOTA
	export DEVICE
	export SYSRAWIMG
	export RemountDEVICE
}

arch_detect() {
	echo "[-] Arch Detect"
	ARCH=arm
	ARCH32=arm
	IS64BIT=false
	# Detect architecture
	# To select the right files for the patching
	
	BASHARCH=$(which bash)
	BASHARCH=$(file $BASHARCH)

	if [[ "$BASHARCH" == *"x86-64"* ]]; then ARCH=x64; ARCH32=x86; IS64BIT=true; fi;
	[ -d $FIN/system/lib64 ] && IS64BIT=true || IS64BIT=false
	
	echo "[*] ARCH32 $ARCH32"
	echo "[-] ARCH $ARCH"
	echo "[*] IS64BIT $IS64BIT"
	
	# There is only a x86 or arm DIR with binaries
	BINDIR=$MAGISKDIR/lib/$ARCH32

	[ ! -d "$BINDIR" ] && BINDIR=$MAGISKDIR/lib/armeabi-v7a
	cd $BINDIR
	for file in lib*.so; do mv "$file" "${file:3:${#file}-6}"; done
	cd $BASEDIR

	echo "[*] copy all files from $BINDIR to $BASEDIR"
	chmod -R 755 $BINDIR
	cp $BINDIR/* $BASEDIR
}

PrepBusyBoxAndMagisk() {

	# Overlay Directorys
	FM=$BASEDIR/FM
	TO=$BASEDIR/to
	TEMP=$BASEDIR/temp
	FIN=$BASEDIR/fin
	
	TMPDIR=$BASEDIR/tmp
	MAGISKDIR=$BASEDIR/Magisk
	BB=$BASEDIR/busybox
	MZ=$BASEDIR/Magisk.zip
	cd $BASEDIR
	echo "[*] Extracting busybox and Magisk.zip ..."
	unzip -oq $MZ -d $MAGISKDIR
	#chmod -R 755 $MAGISKDIR/lib
	mv -f $MAGISKDIR/lib/x86/libbusybox.so $BB
	$BB >/dev/null 2>&1 || mv -f $MAGISKDIR/lib/armeabi-v7a/libbusybox.so $BB
	#chmod -R 755 $BASEDIR

	export FM
	export TO
	export TEMP
	export FIN
	export ROOTA
	export TMPDIR
	export BB
	export MZ

	#CheckAvailableMagisks
}

RemountDEVICE() {
	mount -o remount,rw $DEVICE
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
	CleanUp $MAGISKDIR
	CleanUp $BB
	for file in magisk*; do
		CleanUp $file
	done
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
	chown $(sudo stat -c %u $1):$(sudo stat -c %g $1) $2
	chmod $(sudo stat -c %#a $1) $2
	chcon --reference=$1 $2	
}

PatchOverlayWithMagisk() {
	echo "[*] Patching Overlay with Magisk"
	#"add 0750 init magiskinit"
	#"$SKIPOVERLAYD mkdir 0750 overlay.d"
	#"mkdir 0750 overlay.d/sbin"
	#"add 0644 overlay.d/sbin/magisk32.xz magisk32.xz"
	#"$SKIP64 add 0644 overlay.d/sbin/magisk64.xz magisk64.xz"
	echo "[*] Copy Magiskinit to init"
	sudo mkdir $FIN/.backup	
	cp magiskinit $FIN
	SetPerm $FIN/init $FIN/magiskinit
	mv $FIN/init $FIN/.backup
	mv -f $FIN/magiskinit $FIN/init
	SetPerm $FIN/sbin $FIN/.backup
	chmod 000 -R $FIN/.backup	
	stat -c %C%u%g%#a $FIN/init

	echo "[*] Create overlay.d for Magisk"
	mkdir -p $FIN/overlay.d/sbin
	SetPerm $FIN/sbin $FIN/overlay.d
	SetPerm $FIN/sbin $FIN/overlay.d/sbin
	cp magisk32 $FIN/overlay.d/sbin
	SetPerm $FIN/sbin $FIN/overlay.d/sbin/magisk32
	cp magisk64 $FIN/overlay.d/sbin
	SetPerm $FIN/sbin $FIN/overlay.d/sbin/magisk64	
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
	mv $SYSRAWIMG.magisk $SYSRAWIMG
}

DownloadTools() {
	curl -LO https://github.com/Magisk-Modules-Repo/busybox-ndk/raw/master/busybox-x86_64 busybox && chmod +x busybox
}

checksudo
ProcessArguments $@
exit 1
#####
$RemountDEVICE && RemountDEVICE && exit 1


DownloadTools

CleanUpMounts
PrepBusyBoxAndMagisk
arch_detect
RemountDEVICE
CreateOverlayMounts
read -p "Make your changes and Enter when finshed to continue" </dev/tty
#ReadContextPerm
#PatchOverlayWithMagisk
makeSQUASHFS
create_backup $SYSRAWIMG
setMagiskSQUASHFStoSYSTEM
CleanUpMounts
exit 1

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
#export -p
### for ADB
## find setprop sys.usb.configfs 1
## add setprop sys.usb.config adb
## in init.usb.rc
## or prop conf with magisk
## default.prop
persist.sys.usb.config=adb
fstab.cheets
chcon --reference=fstab.cheets default.prop
-rw-------. 1 655360 655360 u:object_r:rootfs:s0 1202 May 10 08:27 default.prop

sudo umount fin && sudo rm -rf fin
sudo chcon --reference=build.prop default.prop

sudo chcon --reference=init.usb.configfs.rc init.usb.rc

/media/newbit/ROOT-A/usr/share/arc/properties/default.prop

find . -type f -exec grep -l "houdini" {} \;
find . -type f -exec grep -l "persist.sys.usb.config" {} \;
/init.environ.rc
on init
    export SYSTEMSERVERCLASSPATH /system/framework/services.jar:/system/framework/ethernet-service.jar:/system/framework/wifi-service.jar:/system/framework/com.android.location.provider.jar:/system/framework/org.chromium.arc.jar:/system/framework/org.chromium.arc.bridge.jar:/system/framework/org.chromium.arc.mojom.jar:/system/framework/arc-clipboard.jar:/system/framework/arc-services.jar:/system/framework/arcvold-binder.jar

arc-services.vdex
/system/framework/oat/x86_64/arc-services.odex
/system/framework/oat/x86_64/arc-services.vdex
