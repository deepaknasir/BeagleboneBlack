#!/bin/bash

#### Make Directory for BeagleboneBlack_Setup ####

BBB_SETUP_PATH=$(pwd)/BBB_Setup
TOOLCHAIN_PATH=${BBB_SETUP_PATH}/Toolchain
UBOOT_PATH=${BBB_SETUP_PATH}/Uboot
KERNEL_PATH=${BBB_SETUP_PATH}/Kernel
RFS_PATH=${BBB_SETUP_PATH}/RFS

#### Variable used in script ####

SERVER_IP_ADDR=192.168.7.1

VAR_UB_BUILD_MODE=0
VAR_KR_BUILD_MODE=0
VAR_RFS_BUILD_MODE=0
VAR_BOOT_MODE="TFTP"
VAR_MAIN_MENU_EXIT=false
VAR_BOOT_FILE=uImage

TOOLCHAIN_DIR_NAME=gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf
UBOOT_DIR_NAME=u-boot
KERNEL_DIR_NAME=linux
RFS_DIR_NAME=busybox
RFS_OUT_DIR_NAME=RFS_OUT

CPU_CORE=$(cat /proc/cpuinfo | grep cores | wc -l)
let JOB_CORE=$CPU_CORE*2
JOBS=-j${JOB_CORE}

if [ ! -d "${BBB_SETUP_PATH}/" ]; then
	#### Update the system.####

	sudo apt-get update
	sudo apt-get upgrade
	sudo apt-get install build-essential libncurses-dev bison flex libssl-dev libelf-dev lzop u-boot-tools -y
	sudo apt-get install figlet toilet boxes lolcat -y
	sudo apt-get install xinetd tftp tftpd -y
	sudo apt-get install nfs-kernel-server -y 
	#### Make directories ####
	mkdir ${BBB_SETUP_PATH}
	mkdir ${TOOLCHAIN_PATH}
	mkdir ${UBOOT_PATH}
	mkdir ${KERNEL_PATH}
	mkdir ${RFS_PATH}
	mkdir ${RFS_PATH}/${RFS_OUT_DIR_NAME}
	cd ${BBB_SETUP_PATH}
else
	cd ${BBB_SETUP_PATH}
fi

#### Setup TFTP BOOT ####
function setup_tftp()
{
	echo "service tftp" > tftp
	echo "{" >> tftp	
	echo "protocol=udp" >> tftp	
	echo "port=69" >> tftp	
	echo "socket_type=dgram" >> tftp	
	echo "wait=yes" >> tftp	
	echo "user=nobody" >> tftp	
	echo "server=/usr/sbin/in.tftpd" >> tftp	
	echo "server_args=/var/lib/tftpboot -s" >> tftp	
	echo "disable=no" >> tftp	
	echo "}" >> tftp	
	echo "" >> tftp	

	sudo mv tftp /etc/xinetd.d/tftp
	sudo mkdir /var/lib/tftpboot
	sudo chmod -R 777 /var/lib/tftpboot
	sudo chown -R nobody /var/lib/tftpboot
	sudo /etc/init.d/xinetd restart
	
	# setup NFS
	sudo mkdir -p /srv/nfs/bbb
	sudo cp /etc/exports .
	sudo chmod 666 exports
	test_str="/srv/nfs/bbb 192.168.7.2(rw,sync,no_root_squash,no_subtree_check)"
	if [ "`grep -Fx "${test_str}" exports`" != "${test_str}" ]; then 
		sudo echo "/srv/nfs/bbb 192.168.7.2(rw,sync,no_root_squash,no_subtree_check)" >> exports	
	fi
	sudo chmod 644 exports
	sudo mv exports /etc/exports
	sudo exportfs -a
	sudo exportfs -rv
	sudo service nfs-kernel-server restart
	sudo service nfs-kernel-server status

	echo "-------------- TFTP SETUP ---------------- "
	echo ""
	echo " TFTP setup completd !"
	echo ""
	echo " Instructions:-"
	echo "    - To use TFTP booting mode. You have to put below files"
	echo "	    into the /var/lib/tftpboot directory."
	echo "		- am335x_boneblack.dtb"
	echo "		- initramfs"
	echo "		- uImage"
	echo "	  - Copy Below files into SD-Card"
	echo "		- SPL/MLO"
	echo "		- u-boot.img"
	echo "		- uEnv.txt"
}

#### Download Toolchain ####

function download_toolchain()
{

	pushd ${TOOLCHAIN_PATH} > /dev/null

	wget http://releases.linaro.org/components/toolchain/binaries/7.5-2019.12/arm-linux-gnueabihf/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz
	tar -xvf gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz

	popd > /dev/null
}

#### Download U-Boot ####

function download_uboot()
{

	pushd ${UBOOT_PATH} > /dev/null

	wget ftp://ftp.denx.de/pub/u-boot/u-boot-2018.11.tar.bz2
	tar -xvf u-boot-2018.11.tar.bz2	
	mv u-boot-2018.11 u-boot

	popd > /dev/null
}


#### Download Kernel ####

function download_kernel()
{
	pushd ${KERNEL_PATH} > /dev/null

	git clone https://github.com/beagleboard/linux.git

	popd > /dev/null
}

function download_rfs()
{
	if [ -d ${RFS_PATH} ]; then 
		pushd ${RFS_PATH} > /dev/null
	else
		mkdir ${RFS_PATH}
		pushd ${RFS_PATH} > /dev/null
	fi

	wget https://busybox.net/downloads/busybox-1.32.0.tar.bz2
	tar -xvf busybox-1.32.0.tar.bz2
	mv busybox-1.32.0 busybox
	
	popd > /dev/null
	
}


#### Build u-boot bootloader
function build_uboot()
{
	build_mode_chk
	pushd ${UBOOT_PATH}/${UBOOT_DIR_NAME} > /dev/null
	echo "$0, $1"	
	case $1 in 
		1c|1b|2c|2b) 
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- clean
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- distclean
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- am335x_boneblack_defconfig
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- 
			VAR_UB_BUILD_MODE=1 
			;;
		*)
			if [ "$VAR_UB_BUILD_MODE" == "1" ]; then 
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- 
			else
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- clean
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- distclean
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- am335x_boneblack_defconfig
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- 
				VAR_UB_BUILD_MODE=1 
			fi			
			;;
	esac

	popd > /dev/null
	gen_mode_chk	
}

#### Build Busy Box rfs ####
function build_rfs()
{
	build_mode_chk
	pushd ${RFS_PATH}/${RFS_DIR_NAME} > /dev/null
	case $1 in 
		1c|1b|4c|4b) 
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- clean
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- distclean
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- defconfig
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- CONFIG_PREFIX=${RFS_PATH}/${RFS_OUT_DIR_NAME} install
			VAR_RFS_BUILD_MODE=1 
			;;
		*)
			if [ "$VAR_RFS_BUILD_MODE" == "1" ]; then 
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- CONFIG_PREFIX=${RFS_PATH}/${RFS_OUT_DIR_NAME} install
				VAR_RFS_BUILD_MODE=1 
			else
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- clean
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- distclean
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- defconfig
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- CONFIG_PREFIX=${RFS_PATH}/${RFS_OUT_DIR_NAME} install
				VAR_RFS_BUILD_MODE=1 
			fi			
			;;
	esac

	popd > /dev/null
	gen_mode_chk	
}

#### Build Linux kernel #####
function build_kernel()
{
	build_mode_chk
	pwd
	pushd ${KERNEL_PATH}/${KERNEL_DIR_NAME} > /dev/null

	case $1 in 
		1c|1b|3c|3b) 
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- clean
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- distclean
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- bb.org_defconfig
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- ${VAR_BOOT_FILE} dtbs LOADADDR=0x80008000
			make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- modules
			if [ "$VAR_RFS_BUILD_MODE" == "1" ]; then 
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- INSTALL_MOD_PATH=${RFS_PATH}/${RFS_OUT_DIR_NAME} modules_install
			else
				echo "Modules Not installed to Root file system..! Please build RFS first."
			fi
			VAR_KR_BUILD_MODE=1 
			;;
		*)
			if [ "$VAR_KR_BUILD_MODE" == "1" ]; then 
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- ${VAR_BOOT_FILE} dtbs LOADADDR=0x80008000
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- modules
				if [ "$VAR_RFS_BUILD_MODE" == "1" ]; then 
					make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- INSTALL_MOD_PATH=${RFS_PATH}/${RFS_OUT_DIR_NAME} modules_install
				else
					echo "Modules Not installed to Root file system..! Please build RFS first."
				fi
				VAR_KR_BUILD_MODE=1 
			else
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- clean
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- distclean
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- bb.org_defconfig
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- ${VAR_BOOT_FILE} dtbs LOADADDR=0x80008000
				make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- modules
				
				if [ "$VAR_RFS_BUILD_MODE" == "1" ]; then
					make ${JOBS} ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- INSTALL_MOD_PATH=${RFS_PATH}/${RFS_OUT_DIR_NAME} modules_install
				else
					echo "Modules Not installed to Root file system..! Please build RFS first."
				fi	
				VAR_KR_BUILD_MODE=1 
			fi			
			;;
	esac
	
	if [ "${VAR_BOOT_MODE}" == "TFTP" ] || [  "${VAR_BOOT_MODE}" == "NFS" ]; then
	        pushd /var/lib/tftpboot > /dev/null 	
		sudo ln -fs ${KERNEL_PATH}/${KERNEL_DIR_NAME}/arch/arm/boot/${VAR_BOOT_FILE} .
		sudo ln -fs ${KERNEL_PATH}/${KERNEL_DIR_NAME}/arch/arm/boot/dts/am335x-boneblack.dtb .
		popd > /dev/null
		sudo cp -r ${RFS_PATH}/${RFS_OUT_DIR_NAME}/*  /srv/nfs/bbb/.
	fi


	popd > /dev/null
	gen_mode_chk
}

function gen_mode_chk()
{
	pwd
	echo "VAR_UB_BUILD_MODE : ${VAR_UB_BUILD_MODE}" > BUILD_CONFIG.txt
	echo "VAR_KR_BUILD_MODE : ${VAR_KR_BUILD_MODE}" >> BUILD_CONFIG.txt
	echo "VAR_RFS_BUILD_MODE : ${VAR_RFS_BUILD_MODE}" >> BUILD_CONFIG.txt
	echo "VAR_BOOT_MODE : ${VAR_BOOT_MODE}" >> BUILD_CONFIG.txt
	echo "" >> BUILD_CONFIG.txt
	cat BUILD_CONFIG.txt
}
function build_mode_chk()
{
	pwd
	if [ -f BUILD_CONFIG.txt ] ; then
		VAR_UB_BUILD_MODE=$(cat BUILD_CONFIG.txt | sed -n "/^VAR_UB_BUILD_MODE : [a-z0-9_]*/s/VAR_UB_BUILD_MODE :[[:space:]]*//p")
		VAR_KR_BUILD_MODE=$(cat BUILD_CONFIG.txt | sed -n "/^VAR_KR_BUILD_MODE : [a-z0-9_]*/s/VAR_KR_BUILD_MODE :[[:space:]]*//p")
		VAR_RFS_BUILD_MODE=$(cat BUILD_CONFIG.txt | sed -n "/^VAR_RFS_BUILD_MODE : [a-z0-9_]*/s/VAR_RFS_BUILD_MODE :[[:space:]]*//p")
		VAR_BOOT_MODE=$(cat BUILD_CONFIG.txt | sed -n "/^VAR_BOOT_MODE : [a-z0-9_]*/s/VAR_BOOT_MODE :[[:space:]]*//p")
	else
		VAR_UB_BUILD_MODE=0
		VAR_KR_BUILD_MODE=0
		VAR_RFS_BUILD_MODE=0
		VAR_BOOT_MODE="TFTP"
		gen_mode_chk
	fi
}
function func_boot_mode()
{
	local result="SDCARD"

	case $VAR_BOOT_MODE in
		"SDCARD") VAR_BOOT_MODE=TFTP;;
		"TFTP") VAR_BOOT_MODE=NFS;;
		"NFS") VAR_BOOT_MODE=SDCARD;;
		*);;
	esac
	gen_mode_chk
	VAR_MAIN_MENU_EXIT=false
}

function create_uenv_file()
{
	ifconfig 
	echo ""
	IP_ADDR=
	while [ "${IP_ADDR}" == "" ]
	do
		echo -ne "Enter Ethernet IP-Addr : "
		read IP_ADDR
	done
	SERVER_IP_ADDR=${IP_ADDR}
	echo "CONSOLE=ttyUSB0,115200n8" > uEnv.txt

	echo "IP_ADDR=192.168.7.2" >> uEnv.txt
	echo "SERVER_IP=${SERVER_IP_ADDR}" >> uEnv.txt

	echo "BOOTFILE=${VAR_BOOT_FILE}" >> uEnv.txt
	echo "FDT_FILE=am335x-boneblack.dtb" >> uEnv.txt

	echo "LOAD_ADDR=0x82000000" >> uEnv.txt
	echo "FDT_ADDR=0x88000000" >> uEnv.txt
	echo "FS_ADDR=0x88080000" >> uEnv.txt

	echo "SD_BOOT_MODE=/dev/mmcblk0p2" >> uEnv.txt
	echo "TFTP_BOOT_MODE=/dev/ram0" >> uEnv.txt
	echo "NFS_BOOT_MODE=/dev/nfs" >> uEnv.txt
	echo "absolutepath=/var/lib/tftpboot/" >> uEnv.txt
	echo "rootpath=/srv/nfs/bbb,nolock,wsize=1024,rsize=1024 rootwait rootdelay=5" >> uEnv.txt


	if [ "$VAR_BOOT_MODE" == "SDCARD" ]; then 
		echo "netargs=setenv bootargs console=\${CONSOLE} root=\${SD_BOOT_MODE} rw rootfstype=ext4 rootwait debug earlyprintk mem=512M" >> uEnv.txt
		echo "netboot=echo [ DKN ] Booting from $VAR_BOOT_MODE ...; setenv autoload no ; load mmc 0:1 \${LOAD_ADDR} \${BOOTFILE} ; load mmc 0:1 \${FDT_ADDR} \${FDT_FILE} ; run netargs ; bootm \${LOAD_ADDR} - \${FDT_ADDR}" >> uEnv.txt

	elif [ "$VAR_BOOT_MODE" == "TFTP" ]; then 
		echo "netargs=setenv bootargs console=\${CONSOLE} root=\${TFTP_BOOT_MODE} rw initrd=\${FS_ADDR} rootwait debug earlyprintk mem=512M" >> uEnv.txt
		echo "netboot=echo [ DKN ] Booting from $VAR_BOOT_MODE ...; setenv autoload no; tftpboot \${LOAD_ADDR} \${absolutepath}\${BOOTFILE}; tftpboot \${FDT_ADDR} \${absolutepath}\${FDT_FILE} ; bootm \${LOAD_ADDR} - \${FDT_ADDR}" >> uEnv.txt


	elif [ "$VAR_BOOT_MODE" == "NFS" ]; then 
		echo "netargs=setenv bootargs console=\${CONSOLE} root=\${NFS_BOOT_MODE} rw nfsroot=\${SERVER_IP}:\${rootpath}" >> uEnv.txt
		echo "netboot=echo [ DKN ] Booting from $VAR_BOOT_MODE ...; setenv autoload no; tftpboot \${LOAD_ADDR} \${absolutepath}\${BOOTFILE}; tftpboot \${FDT_ADDR} \${absolutepath}\${FDT_FILE}; bootm \${LOAD_ADDR} - \${FDT_ADDR}" >> uEnv.txt
	fi
	echo "uenvcmd=run netboot" >> uEnv.txt

	echo -e "uEnv.txt Generated at :""\033[1;31;40m`pwd`\033[0m"

}  

function sdcard_setup()
{
	echo -ne " Enter SD-Card Block partition e.g: sda, sdb, mmcblk0 etc.:-  "
	read block_dev

	DEV=/dev/$block_dev
	if [ -b "$DEV" ]; then
		ls -lah $DEV
	else
		echo "Invalid Block device."
		exit 1
	fi
	mount | grep '^/' | grep -q $block_dev

	if [ $? -ne 1 ]; then
		echo "Looks like partitions on device /dev/${block_dev} are mounted"
		echo "Not going to work on a device that is currently in use"
		mount | grep '^/' | grep ${block_dev}
		exit 1
	fi


}


function main_menu()
{
	clear
	toilet -f ivrit -t "     CHOOSE OPTION " | boxes -d cat -a hc -p h8 | lolcat
	echo "============================================================================================================="
	echo "	1)  All (Build) 		1b) All	   ( Download & Build-SetupAll) 	1c) All    (Clean Build)"
	echo "	2)  U-boot (Build)		2b) U-boot ( Download & Build )			2c) U-boot (Clean Build)"
	echo "	3)  Kernel (Build)		3b) Kernle ( Download & Build )			3c) Kernel (clean Build)"
	echo "	4)  RFS_BusyBox (Build)		4b) RFS_BusyBox ( Download & Build )		4c) RFS_BusyBox (clean Build)"
	echo "	5)  Download All"
	echo "	6)  Full Setup ( Setup EveryThing )"
	echo "-------------------------------------------------------------------------------------------------------------"
	echo -e "	m)   BOOT-MODE   : ""\033[1;32;40m${VAR_BOOT_MODE}\033[0m"
	echo -e "	u)   Gen-uEnv    : ""\033[1;31;40mGenerate uEnv.txt \033[0m"
	echo -e "	s)   SD-Card     : ""\033[1;33;40mSetup SD-Card \033[0m"
	echo -e "	t)   Setup-TFTP  : ""\033[1;34;40mSetup TFTP MODE \033[0m"

	echo "============================================================================================================="

	echo -ne "\e[1;42m Choose option :\e[0m"
	read SELECTED_OPTION
	VAR_MAIN_MENU_EXIT=true
	case $SELECTED_OPTION in 
		m)	
			func_boot_mode
			;;
		s)	
			sdcard_setup
			;;
		t)	
			setup_tftp
			;;
		u)	
			create_uenv_file
			;;
		1)
			build_uboot $SELECTED_OPTION
			build_kernel $SELECTED_OPTION
			;;

		1b)
			download_toolchain
			download_uboot
			download_kernel
			build_uboot $SELECTED_OPTION
			build_kernel $SELECTED_OPTION
			;;

		1c)
			build_uboot $SELECTED_OPTION
			build_kernel $SELECTED_OPTION
			;;

		2)
			build_uboot $SELECTED_OPTION
			;;

		2b)
			download_toolchain
			download_uboot
			build_uboot $SELECTED_OPTION
			;;

		2c)
			build_uboot $SELECTED_OPTION
			;;

		3)
			build_kernel $SELECTED_OPTION
			;;

		3b)
			download_toolchain
			download_kernel
			build_kernel $SELECTED_OPTION
			;;

		3c)
			build_kernel $SELECTED_OPTION
			;;

		4)
			build_rfs $SELECTED_OPTION
			;;

		4b)
			download_rfs
			build_rfs $SELECTED_OPTION
			;;

		4c)
			build_rfs $SELECTED_OPTION
			;;

		5)	
			download_toolchain
			download_uboot
			download_kernel
			download_rfs
			;;
		6)	
			echo "Start Downloading Source Code ....!"
			download_toolchain
			download_uboot
			download_kernel
			download_rfs
			sudo echo ""
			echo -ne "Ready To setup Everything. Press Enter Key :"
			read ans

			create_uenv_file
			setup_tftp	
			build_uboot 1c
			build_rfs 1c
			build_kernel 1c
			;;
		*)
			echo -e "\e[1;31m ERROR: Invalid Option !!! \e[0m"
			VAR_MAIN_MENU_EXIT=false
	esac
}

while [ "$VAR_MAIN_MENU_EXIT" = "false" ]
do
	build_mode_chk
	main_menu
done
