#!/usr/bin/env bash
#
# [Release]: Blackbuntu 20.04.3 LTS amd64
# [Website]: https://blackbuntu.org/p/releases/?ver=20.04.3
# [License]: http://www.gnu.org/licenses/gpl-3.0.html
#
# Ascii Art : https://www.askapache.com/online-tools/figlet-ascii/

## ---------------- ##
## Define Variables ##
## ---------------- ##

## Colour output
## -------------
t_error="\033[01;31m"	# Error
t_valid="\033[01;32m"	# Valid
t_alert="\033[01;33m"	# Alert
t_title="\033[01;34m"	# Title
t_reset="\033[00m"		# Reset

## Path directory
## --------------
path_script="$(dirname "$(readlink -f "$0")")"

## Path settings file
## ------------------
path_config="$path_script/build.conf"

## Clear screen
## ------------
function clearscreen()
{
	clear
	sleep 2s
}

## Keep alive
## ----------
function keepalive()
{
	sudo -v
	while true;
	do
		sudo -n true;
		sleep 60s;
		kill -0 "$$" || exit;
	done 2>/dev/null &
}

## Load banner
## -----------
function showbanner()
{
	clear
	echo -e "${t_error}  _     _            _    _                 _          ${t_reset}"
	echo -e "${t_error} | |   | |          | |  | |               | |         ${t_reset}"
	echo -e "${t_error} | |__ | | __ _  ___| | _| |__  _   _ _ __ | |_ _   _  ${t_reset}"
	echo -e "${t_error} | '_ \| |/ _' |/ __| |/ / '_ \| | | | '_ \| __| | | | ${t_reset}"
	echo -e "${t_error} | |_) | | (_| | (__|   <| |_) | |_| | | | | |_| |_| | ${t_reset}"
	echo -e "${t_error} |_'__/|_|\__'_|\___|_|\_\_'__/ \__'_|_| |_|\__|\__'_| ${t_reset}"
	echo -e "${t_error}                                      v20.04 LTS amd64 ${t_reset}"
	echo
	echo -e "${t_valid}[i] [Package]: build.sh${t_reset}"
	echo -e "${t_valid}[i] [Website]: https://blackbuntu.org${t_reset}"
  	sleep 3s
}

## Check Internet status
## ---------------------
function checkinternet()
{
	for i in {1..10};
	do
		ping -c 1 -W ${i} www.google.com &>/dev/null && break;
	done

	if [[ "$?" -ne 0 ]];
	then
		echo
		echo -e "${t_error}Error ~ Possible DNS issues or no Internet connection${t_reset}"
		echo -e "${t_error}Quitting ...${t_reset}\n"
		exit 1
	fi
}

## Warning
## -------
function warning()
{
	echo
    echo -e "${t_error}*** Warning ***${t_reset}"
    echo -e "${t_error}You are about to generate a new ISO of Blackbuntu${t_reset}"
    echo -e "${t_error}We recommend to exit all other programs before to proceed${t_reset}"
    echo ""
    read -p "Do you want to continue? [y/N] " yn
    case $yn in
        [Yy]* )
            ;;
        [Nn]* )
            exit
            ;;
        * )
            exit
            ;;
    esac
}

## Go to script directory
## -------------------------
function goscript()
{
    cd "$path_script"
}

## Load configuration file
## -----------------------
function configload()
{
    source "$path_config"
}

## Verify the value configured
## ---------------------------
function configcheck()
{
    version=( bionic cosmic disco eoan focal groovy )
    if [[ ! " ${version[*]} " =~ " ${target_ubuntu_version} " ]];
    then
        echo
		echo -e "${t_error}Warning ~ The Ubuntu target version is not correct${t_reset}"
		echo -e "${t_error}Quitting ...${t_reset}\n"
		exit 1
    fi
}

## Check the host machine
## ----------------------
function checkhost()
{
    os_ver=`lsb_release -i | grep -E "(Ubuntu|Debian)"`
    if [[ -z "$os_ver" ]];
	then
		echo
		echo -e "${t_error}Warning ~ Your operating system is not Debian or Ubuntu${t_reset}"
		echo -e "${t_error}Quitting ...${t_reset}\n"
		exit 1
    fi
}

## Check current user
## ------------------
function checkroot()
{
    if [ $(id -u) -eq 0 ];
	then
		echo
		echo -e "${t_error}Error ~ This script cannot be executed by root${t_reset}"
		echo -e "${t_error}Quitting ...${t_reset}\n"
		exit 1
    fi
}

## Mount points
## ------------
function mountpoints()
{
    sudo mount --bind /dev diskbase/dev
    sudo mount --bind /run diskbase/run
    sudo chroot diskbase mount none -t proc /proc
    sudo chroot diskbase mount none -t sysfs /sys
    sudo chroot diskbase mount none -t devpts /dev/pts
}

## Umount points
## -------------
function unmountpoints()
{
    sudo chroot diskbase umount /proc
    sudo chroot diskbase umount /sys
    sudo chroot diskbase umount /dev/pts
    sudo umount diskbase/dev
    sudo umount diskbase/run
}

## Prepare host
## ------------
function prepare()
{
    sudo apt-get -y update
    sudo apt-get -y install binutils debootstrap grub-efi-amd64-bin grub-pc-bin mtools squashfs-tools xorriso
    sudo mkdir -p diskbase
}

## Sync Debootstrap
## ----------------
function syncstrap()
{
    sudo debootstrap --arch=amd64 --variant=minbase $target_ubuntu_version diskbase $target_ubuntu_mirror
}

## Generate DEB packages
## ---------------------
function gendebpack()
{
	basetree="$path_script/packages"
	if [ ! -d "$basetree" ]
	then
	    git clone https://github.com/neoslab/packages
	fi

	for basedir in "$basetree"/*;
	do
		for deb in "$basedir"/*;
		do
			if test -d "$deb";
			then
		        dpkg-deb --build --root-owner-group $deb
		    fi
		done
	done
}

## Enter chroot environment
## ------------------------
function chrootenv()
{
	sudo ln -f $path_script/chroot.sh diskbase/root/chroot.sh
    sudo cp -r $path_script/system diskbase/tmp/
    sudo cp -r $path_script/packages diskbase/tmp/
    sudo chroot diskbase /root/chroot.sh -
    sudo rm -f diskbase/root/chroot.sh
}

## Build ISO image
## ---------------
function buildiso()
{
	# Create folders tree
    rm -rf image
    mkdir -p image/{casper,isolinux,install}

	# Copy initrd/vmlinuz
	sudo cp diskbase/boot/vmlinuz-**-**-generic image/casper/vmlinuz
	sudo cp diskbase/boot/initrd.img-**-**-generic image/casper/initrd

	# Import Memtest
    sudo cp diskbase/boot/memtest86+.bin image/install/memtest86+
    wget --progress=dot https://www.memtest86.com/downloads/memtest86-usb.zip -O image/install/memtest86-usb.zip
    unzip -p image/install/memtest86-usb.zip memtest86-usb.img > image/install/memtest86
    rm -f image/install/memtest86-usb.zip

	# Config Grub
	touch image/ubuntu
	echo "search --set=root --file /ubuntu
	insmod all_video
	set default="0"
	set timeout=30
	menuentry \"${grub_label_liveboot}\" {
	   linux /casper/vmlinuz boot=casper nopersistent toram quiet splash ---
	   initrd /casper/initrd
	}
	menuentry \"${grub_label_install}\" {
	   linux /casper/vmlinuz boot=casper only-ubiquity quiet splash ---
	   initrd /casper/initrd
	}
	menuentry \"Check disc for defects\" {
	   linux /casper/vmlinuz boot=casper integrity-check quiet splash ---
	   initrd /casper/initrd
	}
	menuentry \"Test memory Memtest86+ (BIOS)\" {
	   linux16 /install/memtest86+
	}
	menuentry \"Test memory Memtest86 (UEFI, long load time)\" {
	   insmod part_gpt
	   insmod search_fs_uuid
	   insmod chain
	   loopback loop /install/memtest86
	   chainloader (loop,gpt1)/efi/boot/BOOTX64.efi
	}" > image/isolinux/grub.cfg

	# Generate manifest
    sudo chroot diskbase dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
    sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
    for pkg in $target_package_remove;
	do
        sudo sed -i "/$pkg/d" image/casper/filesystem.manifest-desktop
    done

    # Compress rootfs
    sudo mksquashfs diskbase image/casper/filesystem.squashfs -noappend -no-duplicates -no-recovery -wildcards -e "var/cache/apt/archives/*" -e "root/*" -e "root/.*" -e "tmp/*" -e "tmp/.*" -e "swapfile"
    printf $(sudo du -sx --block-size=1 diskbase | cut -f1) > image/casper/filesystem.size

    # Create diskdefines
    echo "#define DISKNAME  ${target_disk_label}
	#define TYPE  binary
	#define TYPEbinary  1
	#define ARCH  amd64
	#define ARCHamd64  1
	#define DISKNUM  1
	#define DISKNUM1  1
	#define TOTALNUM  0
	#define TOTALNUM0  1" > image/README.diskdefines

	# Create iso image
    pushd $path_script/image
    grub-mkstandalone --format=x86_64-efi --output=isolinux/bootx64.efi --locales="" --fonts="" "boot/grub/grub.cfg=isolinux/grub.cfg"
    (cd isolinux && dd if=/dev/zero of=efiboot.img bs=1M count=10 && sudo mkfs.vfat efiboot.img && LC_CTYPE=C mmd -i efiboot.img efi efi/boot && LC_CTYPE=C mcopy -i efiboot.img ./bootx64.efi ::efi/boot/)
    grub-mkstandalone --format=i386-pc --output=isolinux/core.img --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls" --modules="linux16 linux normal iso9660 biosdisk search" --locales="" --fonts="" "boot/grub/grub.cfg=isolinux/grub.cfg"
    cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img
    sudo /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v -e 'md5sum.txt' -e 'bios.img' -e 'efiboot.img' > md5sum.txt)"
    sudo xorriso \
		-as mkisofs \
		-iso-level 3 \
		-full-iso9660-filenames \
		-volid "$target_disk_name" \
		-eltorito-boot boot/grub/bios.img \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		--eltorito-catalog boot/grub/boot.cat \
		--grub2-boot-info \
		--grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
		-eltorito-alt-boot \
		-e EFI/efiboot.img \
		-no-emul-boot \
		-append_partition 2 0xef isolinux/efiboot.img \
		-output "$path_script/$target_disk_name.iso" \
		-m "isolinux/efiboot.img" \
		-m "isolinux/bios.img" \
		-graft-points \
		"/EFI/efiboot.img=isolinux/efiboot.img" \
		"/boot/grub/bios.img=isolinux/bios.img" \
		"."
	popd
}

## Switch owner right
## ------------------
function switchowner()
{
	sudo chown -R $USER:$USER $path_script/diskbase
	sudo chown -R $USER:$USER $path_script/$target_disk_name.iso
}

## Launch
## ------
function launch()
{
    clearscreen
	keepalive
	showbanner
	checkinternet
	warning
	clearscreen
    goscript
    configload
    configcheck
	checkhost
	checkroot
	prepare
	syncstrap
	mountpoints
	gendebpack
	chrootenv
	unmountpoints
	buildiso
	switchowner
}

## -------- ##
## Callback ##
## -------- ##

launch
