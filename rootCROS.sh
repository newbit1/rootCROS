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
	restore=true
	if [ -z $DEBUG ]; then
		DEBUG=false
	fi
	#DEBUG=true
	
	# Overlay Directorys
	FM=$BASEDIR/FM
	TO=$BASEDIR/to
	TEMP=$BASEDIR/temp
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
	
	if [[ "$@" == *"CleanUpMounts"* ]]; then
		CleanUpMounts=true
	fi

	if [[ "$@" == *"RemountDrive"* ]]; then
		RemountDrive=true
	fi

	if [[ "$@" == *"restore"* ]]; then
		restore=true
	fi
	
	export FM
	export TO
	export TEMP
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
	
	export RemountDrive
	export CleanUpMounts
	export restore
	export DEBUG
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

InitADB() {
	echo "[*] Init ADB"
	ADBWORKS=$(adb shell 'echo true' 2>/dev/null)&
	pids=" $!"
	wait $pids

	if [[ "$ADBWORKS" == *"ADB_VENDOR_KEYS"* ]]; then
		adb kill-server &
		pids=" $!"
		wait $pids
		adb shell &
		pids=" $!"
		wait $pids
	fi
}

PatchFakeRamdisk() {
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
	chmod +x $BASEDIR/busybox
	echo "[*] Trying to install Magisk.apk"
	#adb install -r -d Magisk.apk
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
	#CleanUp $FM
	#CleanUp $TO
	#CleanUp $TEMP
	CleanUp $FIN
}

CreateOverlayMounts() {
	#mkdir $FM
	#mkdir $TO
	#mkdir $TEMP
	mkdir $FIN
	#-o context=system_u:object_r:public_content_t:s0 /dev/sdb1
	#drwxr-xr-x. 17 android-root android-root u:object_r:rootfs:s0 909 May 17 09:21 /opt/google/containers/android/rootfs/root/
	#mount $SYSRAWIMG $FM -t squashfs -o loop
	#mount -o remount,nosuid,nodev,noexec $FM
	#mount -t overlay -o lowerdir=$FM,upperdir=$TO,workdir=$TEMP overlay $FIN
	#overlay on /usr/local/crosswork/fin type overlay (rw,relatime,lowerdir=/usr/local/crosswork/FM,upperdir=/usr/local/crosswork/to,workdir=/usr/local/crosswork/temp)
	unsquashfs -f -d $FIN $SYSRAWIMG
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

CreateMagiskDaemonSCR() {

ADBTMP=/data/local/tmp
adb shell cp $ADBBASEDIR/busybox $ADBTMP/
adb shell cp $ADBBASEDIR/magiskinit $ADBTMP/
adb shell cp $ADBBASEDIR/magisk64 $ADBTMP/magisk

echo "#!/usr/bin/env bash

mount_sbin() {
  mount -t tmpfs -o 'mode=0755' tmpfs /sbin
  \$SELINUX && chcon u:object_r:rootfs:s0 /sbin
}

cd /sbin
chmod 777 busybox
chmod 777 magiskinit
chmod 777 magisk

if [ -z \"\$FIRST_STAGE\" ]; then
  export FIRST_STAGE=1
  export ASH_STANDALONE=1
  if [ `./busybox id -u` -ne 0 ]; then
    # Re-exec script with root
    exec /sbin/su 0 ./busybox sh \$0
  else
    # Re-exec script with busybox
    exec ./busybox sh \$0
  fi
fi

# SELinux stuffs
#SELINUX=false
[ -e /sys/fs/selinux ] && SELINUX=true
if \$SELINUX; then
  ln -sf ./magiskinit magiskpolicy
  ./magiskpolicy --live --magisk
fi

# Setup bin overlay
# Android Q+ without sbin, use overlayfs
BINDIR=/system/bin
rm -rf /dev/magisk
mkdir -p /dev/magisk/upper
mkdir /dev/magisk/work
./magisk --clone-attr /system/bin /dev/magisk/upper
mount -t overlay overlay -o lowerdir=/system/bin,upperdir=/dev/magisk/upper,workdir=/dev/magisk/work /system/bin

# Magisk stuffs
cp -af ./magisk $BINDIR/magisk
chmod 755 \$BINDIR/magisk
ln -s ./magisk \$BINDIR/su
ln -s ./magisk \$BINDIR/resetprop
ln -s ./magisk \$BINDIR/magiskhide
mkdir -p /data/adb/modules 2>/dev/null
mkdir /data/adb/post-fs-data.d 2>/dev/null
mkdir /data/adb/services.d 2>/dev/null
\$BINDIR/magisk --daemon

echo \"came so far\"

" >  $BASEDIR/magiskdaemon.sh
chmod +x magiskdaemon.sh
adb push magiskdaemon.sh $ADBBASEDIR
adb push magiskdaemon.sh $ADBTMP/
}
	
PatchOverlayWithFakeRamdisk() {
	echo "[*] Patching Overlay with fake ramdisk.img"
	ANDROIDROOT=$(stat -c %u $FIN/system)
	mv $BASEDIR/ramdisk.img $BASEDIR/ramdisk.cpio.gz
	$BB gzip -fd $BASEDIR/ramdisk.cpio.gz
	mkdir -p $RAMDISKDIR
	echo "[-] Extracting ramdisk.cpio"
	#cd $FIN > /dev/null
	cd $RAMDISKDIR > /dev/null
		#rm ./init
		#cat $BASEDIR/ramdisk.cpio | $BB cpio -i > /dev/null 2>&1
		#cp ./overlay.d/sbin/magisk* ./sbin
		#rm $BASEDIR/ramdisk.cpio > /dev/null 2>&1
	cd - > /dev/null
	#cp $RAMDISKDIR/init $RAMDISKDIR/overlay.d/sbin/magiskinit
	#cp $BASEDIR/busybox $RAMDISKDIR/overlay.d/sbin/
	
	
	echo "[*] Copy Ramdisk Files"
	#cp -r $RAMDISKDIR/overlay.d/sbin/* $FIN/sbin/
	#cp -r $RAMDISKDIR/overlay.d/* $FIN/
	#cp -r $RAMDISKDIR/overlay.d $FIN/
	#cp -r $RAMDISKDIR/* $FIN
	
	cd $FIN > /dev/null
		#rm ./init
		cat $BASEDIR/ramdisk.cpio | $BB cpio -i > /dev/null 2>&1
		cp ./init ./overlay.d/sbin/magiskinit
		cp $BASEDIR/busybox ./overlay.d/sbin/
		cp -r ./overlay.d/sbin $FIN
	cd - > /dev/null
	
	cd $FIN/sbin > /dev/null
		$BB unxz -f magisk64.xz
		$BB unxz -f magisk32.xz
		#ln -s ./magisk32 ./magisk
		ln -sf ./magisk64 ./magisk
		ln -sf ./magisk ./su
		ln -sf ./magisk ./resetprop
		ln -sf ./magisk ./magiskhide
		ln -sf ./magiskinit ./magiskpolicy
		
		#$BB magisk64 magisk
		set_perm_recursive $FIN/sbin $ANDROIDROOT $ANDROIDROOT 0755 0777
		set_perm_recursive $FIN/overlay.d $ANDROIDROOT $ANDROIDROOT 0755 0777
		
		set_perm ./magisk64 $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:magisk_exec:s0
		set_perm ./magisk32 $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:magisk_exec:s0		
		
		set_perm ./magisk $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		set_perm ./su $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		set_perm ./resetprop $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		set_perm ./magiskhide $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		set_perm ./magiskinit $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:system_file:s0
		
		set_perm ./busybox $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:magisk_file:s0
		#set_perm ./magiskdaemon.sh $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:magisk_exec:s0
		
	cd - > /dev/null
	
	set_perm $FIN/init $ANDROIDROOT $ANDROIDROOT 0755 u:object_r:init_exec:s0
	set_perm_recursive $FIN/.backup $ANDROIDROOT $ANDROIDROOT 0755 0777
	
	#if [ ! -e "$ANDROIDATADIR/data/adb/magisk" ]; then
		#mkdir -p $ANDROIDATADIR/data/adb/magisk
		#mkdir -p $ANDROIDATADIR/data/adb/modules
		#mkdir -p $ANDROIDATADIR/data/adb/post-fs-data.d
		#mkdir -p $ANDROIDATADIR/data/adb/services.d
	
		#cd $ANDROIDATADIR/data/adb > /dev/null
			#chcon u:object_r:system_file:s0 ./magisk
			#chcon u:object_r:system_file:s0 ./modules
			#chcon u:object_r:adb_data_file:s0 ./post-fs-data.d
			#chcon u:object_r:adb_data_file:s0 ./services.d

			#SetOwner $ANDROIDATADIR/data/adb ./magisk
			#SetOwner $ANDROIDATADIR/data/adb ./modules
			#SetOwner $ANDROIDATADIR/data/adb ./post-fs-data.d
			#SetOwner $ANDROIDATADIR/data/adb ./services.d

			#chmod 0755 ./magisk
			#chmod 0755 ./modules
			#chmod 0755 ./post-fs-data.d
			#chmod 0755 ./services.d				
		#cd - > /dev/null
	#fi
	patch_init
	#cat $FIN/init.rc
}

PatchSELinux() {
	#adb push $POLICY $ADBBASEDIR
	echo "[*] Inject SELinux with Magisk built-in rules"
	adb shell cp $ADBBASEDIR/magiskinit $ADBBASEDIR/magiskpolicy
	adb shell $ADBBASEDIR/magiskpolicy --save $ADBBASEDIR/policy.30.magisk --magisk
	create_backup $POLICY
	adb pull $ADBBASEDIR/policy.30.magisk $POLICY	
	SetPerm $POLICYCONREF $POLICY
	adb shell cp /sepolicy $ADBBASEDIR/
	adb shell $ADBBASEDIR/magiskpolicy --load $ADBBASEDIR/sepolicy --save $ADBBASEDIR/sepolicy.magisk --magisk
	adb pull $ADBBASEDIR/sepolicy.magisk $FIN
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
	CONTEXTREF="$1"
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
$restore && RemountDrive && restore_backup $SYSRAWIMG $VENRAWIMG && exit 0
#####

DownloadAssets

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
#CreateMagiskDaemonSCR
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


