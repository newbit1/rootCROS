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
	  #echo "restore0=$restore"
	  #if [ ! -z $restore ]; then
	#		export restore
	 # fi
	  #export restore
	  sudo bash -c "exec bash $0 $@"
	  exit 0
	fi
}

ChangeLocation() {
	local WORKDIR=/usr/local
	#WORKDIR=$PORTAGE_CONFIGROOT
	BASEDIR=$WORKDIR/crosswork
	local CURDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

	if [ ! -e "$BASEDIR" ]; then
		mkdir -p $BASEDIR
	fi
	
	if [ "$CURDIR" != "$BASEDIR" ]; then
		echo "[-] Moving to the location $BASEDIR"
		#rm $BASEDIR/*
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
	
	if [ -z $restore ]; then
		restore=false
	fi
	#restore=true
	if [ -z $DEBUG ]; then
		DEBUG=false
	fi
	#DEBUG=true
	if [ -z $InstallADBKey ]; then
		InstallADBKey=false
	fi
	#InstallADBKey=true	
	
	# Overlay Directorys
	FIN=$BASEDIR/fin
	DRIVE=/
	
	TMPDIR=$BASEDIR/tmp
	
	ANDROIROOTDIR=/opt/google/containers/android/rootfs/root
	SYSRAWIMG=/opt/google/containers/android/system.raw.img
	VENRAWIMG=/opt/google/containers/android/vendor.raw.img
	POLICY=/etc/selinux/arc/policy/policy.30
	POLICYCONREF=/etc/selinux/arc/contexts/files/file_contexts
	
	#RECOVERYIMG=/home/$USER/Downloads/chromeos_13816.64.0_rammus_recovery_stable-channel_mp-v2.bin.img
	# ROOT-A contains the android container system and vendor
	#ROOTA=/dev/loop0p3
	#ROOTA=/media/newbit/ROOT-A
	
		
	ANDROIDATADIR=/opt/google/containers/android/rootfs/android-data
	ADBWORKDIR=/data/data/com.android.shell
	ADBBASEDIR=$ADBWORKDIR/Magisk
	HOCHUSAN=/home/chronos/user/.android
	ADBKEYPUB=adbkey.pub
	ADBKEYS=/data/misc/adb/adb_keys
	
	if [[ "$@" == *"CleanUpMounts"* ]]; then
		CleanUpMounts=true
	fi

	if [[ "$@" == *"RemountDrive"* ]]; then
		RemountDrive=true
	fi

	if [[ "$@" == *"restore"* ]]; then
		restore=true
	fi
	
	export FIN
	export DRIVE
	
	export TMPDIR
	
	export ANDROIROOTDIR
	export ANDROIDATADIR
	export SYSRAWIMG
	export VENRAWIMG
	export POLICY

	export ADBWORKDIR
	export ADBBASEDIR
	export ADBKEYPUB
	
	export RemountDrive
	export CleanUpMounts
	export restore
	export DEBUG
	export InstallADBKey
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
		#curl -# -L https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-i686 -o $TARGET && chmod +x $TARGET		
	else
		echo "[-] $TARGET already there"
	fi
	BB=$BASEDIR/$TARGET
	
	export ROOTAVD
	export MZ
	export BB	
}

InstallADBKey() {
	if [ -e "$HOCHUSAN/$ADBKEYPUB" ]; then
		#if [ ! -e "$ANDROIDATADIR$ADBKEYS" ]; then
			echo "[*] Installing ADB Key Public via android-sh"
			cp $HOCHUSAN/$ADBKEYPUB $ANDROIDATADIR$ADBWORKDIR
			echo "cp $ADBWORKDIR/$ADBKEYPUB $ADBKEYS" | android-sh
			echo "chown system:shell $ADBKEYS" | android-sh
			echo "chmod 0640 $ADBKEYS" | android-sh
			echo "chcon u:object_r:adb_keys_file:s0 $ADBKEYS" | android-sh
		#fi	
	fi
	exit 0
}

InitADB() {
	echo "[*] Init ADB"
	ADBDISABLED=false
	ADBWORKS=false
	CONNECTTRYS=2
	timeout -k 1 4 adb start-server
	
	while [ "$ADBWORKS" != "true" ];do
		if [[ "$ADBWORKS" == *"devices/emulators"* ]]; then
			ADBDISABLED=true
			echo "ADBWORKS=$ADBWORKS"
			echo "[!] Device has no ADB Service running"
			#adb kill-server
			break
		elif [[ "$ADBWORKS" == *"ADB_VENDOR_KEYS"* ]]; then
			adb kill-server
			if [ $CONNECTTRYS == "0" ]; then
				echo "ADBWORKS=$ADBWORKS"
				echo "[!] Cannot init ADB"
				ADBDISABLED=true
				adb kill-server
				break
			fi
			timeout -k 1 4 adb wait-for-device
			CONNECTTRYS=$(( CONNECTTRYS - 1 ))
		fi
		ADBWORKS=$(adb shell 'echo true' 2>&1)
	done

	export ADBDISABLED
}

CreateFakeRamdisk() {
	echo "[*] Creating fake ramdisk.img"
	RAMDISKDIR=$TMPDIR/fakeramdisk
	CPIO=$BASEDIR/ramdisk.cpio
	rm -rf $RAMDISKDIR
	mkdir -p $RAMDISKDIR
	cp $ANDROIROOTDIR/init $RAMDISKDIR
	#cp $ANDROIROOTDIR/fstab.cheets $RAMDISKDIR
	cd $RAMDISKDIR > /dev/null
		`$BB find . | $BB cpio -H newc -o | $BB gzip > $BASEDIR/ramdisk.img`
	cd - > /dev/null
	rm -rf $RAMDISKDIR
	export RAMDISKDIR
}

PatchFakeRamdisk() {
	
	if ( ! "$ADBDISABLED" ); then
		echo "[*] Cleaning up the ADB working space"
		adb shell rm -rf $ADBBASEDIR
		echo "[*] Creating the ADB working space"
		adb shell mkdir $ADBBASEDIR
		adb push rootAVD.sh $ADBBASEDIR
		adb push ramdisk.img $ADBBASEDIR
		adb push Magisk.zip $ADBBASEDIR
		adb shell sh $ADBBASEDIR/rootAVD.sh $@
		adb pull $ADBBASEDIR/ramdiskpatched4AVD.img $BASEDIR/ramdisk.img
		adb pull $ADBBASEDIR/Magisk.apk
		adb pull $ADBBASEDIR/busybox
		echo "[*] Trying to install Magisk.apk"
		adb install -r -d Magisk.apk
	elif ( "$ADBDISABLED" ); then
		echo "[*] Cleaning up the android-sh working space"
		rm -rf $ANDROIDATADIR$ADBBASEDIR
		rm $ANDROIDATADIR$ADBWORKDIR/rootAVD.sh
		rm $ANDROIDATADIR$ADBWORKDIR/ramdisk.img
		rm $ANDROIDATADIR$ADBWORKDIR/Magisk.zip
		echo "rm -rf $ADBBASEDIR" | android-sh
		
		echo "[*] Creating the android-sh working space"
		echo "mkdir $ADBBASEDIR" | android-sh
		
		cp rootAVD.sh $ANDROIDATADIR$ADBWORKDIR
		cp ramdisk.img $ANDROIDATADIR$ADBWORKDIR
		cp Magisk.zip $ANDROIDATADIR$ADBWORKDIR
		
		echo "cp $ADBWORKDIR/rootAVD.sh $ADBBASEDIR" | android-sh
		echo "cp $ADBWORKDIR/ramdisk.img $ADBBASEDIR" | android-sh
		echo "cp $ADBWORKDIR/Magisk.zip $ADBBASEDIR" | android-sh
		
		echo "chown -R 2000:2000 $ADBBASEDIR" | android-sh
		echo "sh $ADBBASEDIR/rootAVD.sh $@" | android-sh
		
		cp $ANDROIDATADIR$ADBBASEDIR/ramdiskpatched4AVD.img $BASEDIR/ramdisk.img
		cp $ANDROIDATADIR$ADBBASEDIR/Magisk.apk $BASEDIR
		cp $ANDROIDATADIR$ADBBASEDIR/busybox $BASEDIR
		
		echo "[*] Trying to install Magisk.apk"
		echo "pm install -d $ADBBASEDIR/Magisk.apk" | android-sh		
	fi
	chmod +x $BASEDIR/busybox
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
	CleanUp $FIN
}

CreateOverlayMounts() {
	mkdir $FIN
	unsquashfs -f -d $FIN $SYSRAWIMG
}

set_perm() {
  $BB chown $2:$3 $1 || return 1
  $BB chmod $4 $1 || return 1
  CON=$5
  [ -z $CON ] && CON=u:object_r:system_file:s0
  $BB chcon $CON $1 || return 1
}

set_perm_recursive() {
  $BB find $1 -type d 2>/dev/null | while read dir; do
    set_perm $dir $2 $3 $4 $6
  done
  $BB find $1 -type f -o -type l 2>/dev/null | while read file; do
    set_perm $file $2 $3 $5 $6
  done
}

SetPerm() {
	# SET PERM from $1 to $2
	echo "[!] Set Permissions and Context from"
	echo "[-] $1 to $2"
	echo "[*] Change Owner:Group to $(stat -c %u $1):$(stat -c %g $1)"	
	chown $(stat -c %u $1):$(stat -c %g $1) $2
	echo "[-] Change Mod to $(stat -c %#a $1)"	
	chmod $(stat -c %#a $1) $2
	echo "[*] Change Context to $(stat -c %C $1)"
	chcon --reference=$1 $2	
}

SetOwner() {
	# SET OWNER from $1 to $2
	chown $(stat -c %u $1):$(stat -c %g $1) $2
}

patch_init() {

	echo "[*] Injecting Magisk into init.rc"

	echo "
on post-fs-data
    start logd
    rm /dev/.magisk_unblock
    start QOE79THp1LNiWLP
    wait /dev/.magisk_unblock 40
    rm /dev/.magisk_unblock

service QOE79THp1LNiWLP /sbin/magisk --post-fs-data
    user root
    seclabel u:r:magisk:s0
    oneshot

on property:init.svc.zygote=running
    chown root root /sbin/magisk32
    chown root root /sbin/magisk64
    chown root root /sbin/magiskinit
    chown root root /sbin/busybox
    chown root root /overlay.d
    chown root root /.backup
    write /sys/fs/selinux/enforce 0
    start magiskdaemon
    start q2RZ4jzDFsBXQT7    

service magiskdaemon /sbin/magisk --daemon
    user root
    seclabel u:r:magisk:s0
    oneshot

service magiskpolicy /sbin/magiskpolicy --live --magisk
    user root
    seclabel u:r:magisk:s0
    oneshot

service q2RZ4jzDFsBXQT7 /sbin/magisk --service
    class late_start
    user root
    seclabel u:r:magisk:s0
    oneshot

on property:sys.boot_completed=1
    start KILQmKFSZy

service KILQmKFSZy /sbin/magisk --boot-complete
    user root
    seclabel u:r:magisk:s0
    oneshot
" >>  $FIN/init.rc
}
	
PatchOverlayWithFakeRamdisk() {
	echo "[*] Patching Overlay with fake ramdisk.img"
	ANDROIDROOT=$(stat -c %u $FIN/system)
	mv $BASEDIR/ramdisk.img $BASEDIR/ramdisk.cpio.gz
	$BB gzip -fd $BASEDIR/ramdisk.cpio.gz
	echo "[-] Extracting ramdisk.cpio"
	REPLACEINIT=false
	REPLACEINIT=true
	cd $FIN > /dev/null
		$REPLACEINIT && rm ./init		
		$BB cpio -F $BASEDIR/ramdisk.cpio -i > /dev/null 2>&1
		cd ./overlay.d/sbin > /dev/null
			$BB cpio -F $BASEDIR/ramdisk.cpio -i init > /dev/null 2>&1
			mv init magiskinit
		cd - > /dev/null		
		#rm $BASEDIR/ramdisk.cpio
		cp $BASEDIR/busybox ./overlay.d/sbin/
		cp -r ./overlay.d/sbin $FIN
		set_perm ./init $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:init_exec:s0
		set_perm_recursive ./.backup $ANDROIDROOT $ANDROIDROOT 0755 0777
	cd $BASEDIR > /dev/null
	
	cd $FIN/sbin > /dev/null
		$BB unxz -f magisk64.xz
		$BB unxz -f magisk32.xz
		#$BB magisk64 magisk
		set_perm_recursive $FIN/sbin $ANDROIDROOT $ANDROIDROOT 0755 0777
		set_perm_recursive $FIN/overlay.d $ANDROIDROOT $ANDROIDROOT 0755 0777
		set_perm ./magisk64 $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:magisk_exec:s0
		set_perm ./magisk32 $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:magisk_exec:s0
		
		#ln -s ./magisk32 ./magisk		
		ln -sf ./magisk64 ./magisk
		set_perm ./magisk $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		
		ln -sf ./magisk ./su
		set_perm ./su $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		
		ln -sf ./magisk ./resetprop
		set_perm ./resetprop $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		
		ln -sf ./magisk ./magiskhide
		set_perm ./magiskhide $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		
		set_perm ./magiskinit $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		ln -sf ./magiskinit ./magiskpolicy
		set_perm ./magiskpolicy $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		
		set_perm ./busybox $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:magisk_file:s0
		#set_perm ./magiskdaemon.sh $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:magisk_exec:s0		
	cd - > /dev/null
	patch_init
}

PatchSELinux() {
	
	create_backup $POLICY
	if ( ! "$ADBDISABLED" ); then
		echo "[*] Inject SELinux with Magisk built-in rules via ADB"
		adb shell cp $ADBBASEDIR/magiskinit $ADBBASEDIR/magiskpolicy
		adb shell $ADBBASEDIR/magiskpolicy --save $ADBBASEDIR/policy.30.magisk --magisk
		adb pull $ADBBASEDIR/policy.30.magisk $POLICY	
		adb shell cp /sepolicy $ADBBASEDIR
		adb shell $ADBBASEDIR/magiskpolicy --load $ADBBASEDIR/sepolicy --save $ADBBASEDIR/sepolicy.magisk --magisk
		adb pull $ADBBASEDIR/sepolicy.magisk $FIN
	elif ( "$ADBDISABLED" ); then
		echo "[*] Inject SELinux with Magisk built-in rules via android-sh"
		echo "cp $ADBBASEDIR/magiskinit $ADBBASEDIR/magiskpolicy" | android-sh
		echo "$ADBBASEDIR/magiskpolicy --save $ADBBASEDIR/policy.30.magisk --magisk" | android-sh
		cp $ANDROIDATADIR$ADBBASEDIR/policy.30.magisk $POLICY
		echo "cp /sepolicy $ADBBASEDIR" | android-sh
		echo "$ADBBASEDIR/magiskpolicy --load $ADBBASEDIR/sepolicy --save $ADBBASEDIR/sepolicy.magisk --magisk" | android-sh
		cp $ANDROIDATADIR$ADBBASEDIR/sepolicy.magisk $FIN		
	fi
	SetPerm $POLICYCONREF $POLICY
	SetPerm $FIN/sepolicy $FIN/sepolicy.magisk
	mv $FIN/sepolicy.magisk $FIN/sepolicy
}

makeSQUASHFS() {
	echo "[-] Generating SquashFS with Magisk"
	rm $SYSRAWIMG
	mksquashfs $FIN $SYSRAWIMG
	echo "[*] Set Magisk SquashFS System"
	echo "[*] Change Context to $(stat -c %C $VENRAWIMG)"
	chcon --reference=$VENRAWIMG $SYSRAWIMG
}

create_backup() {
	local BACKUPFILE=""
	local FILE=""
	FILE="$1"
	BACKUPFILE="$FILE.backup"
	# If no backup file exist, create one

	if [ ! -e "$BACKUPFILE" ]; then
		echo "[*] create Backup File of $FILE"
		mv $1 $BACKUPFILE
	else
		echo "[-] $FILE Backup exists already"
	fi
}

restore_backup() {
	local BACKUPFILE=""
	local FILE=""
	FILE="$1"
	CONTEXTREF="$2"
	BACKUPFILE="$FILE.backup"

	if [ -e "$BACKUPFILE" ]; then
		echo "[*] Restore Backup File of $FILE"
		rm $1
		cp $BACKUPFILE $1
		if [[ ! "$CONTEXTREF" == "" ]]; then
			chcon --reference=$CONTEXTREF $1
		fi
		echo "[*] Backup remains"
	else
		echo "[!] No Backup to restore"
	fi
}


GainRoot
ChangeLocation
ProcessArguments $@

#####
$RemountDrive && RemountDrive && exit 0
$CleanUpMounts && CleanUpMounts && exit 0
$restore && RemountDrive && restore_backup $SYSRAWIMG $VENRAWIMG && restore_backup $POLICY $POLICYCONREF && exit 0
#####
DownloadAssets
$InstallADBKey && InstallADBKey
rm $BASEDIR/ramdisk.img
if [ ! -e "$BASEDIR/ramdisk.img" ]; then
	InitADB
	CreateFakeRamdisk
	PatchFakeRamdisk
fi

CleanUpMounts
RemountDrive

CreateOverlayMounts
read -p "Make your changes and Enter when finshed to continue" </dev/tty
PatchOverlayWithFakeRamdisk
PatchSELinux

echo "DEBUG=$DEBUG"
if ( ! "$DEBUG" ); then
	read -p "Make your changes and Enter when finshed to continue" </dev/tty
	create_backup $SYSRAWIMG
	makeSQUASHFS	
	CleanUpMounts
	rm -r $TMPDIR > /dev/null 2>&1 &	
fi
exit 0

#ReadContextPerm


