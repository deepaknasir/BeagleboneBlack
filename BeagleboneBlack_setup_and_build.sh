#!/bin/bash

#### Make Directory for BeagleboneBlack_Setup ####

BBB_SETUP_PATH=$(pwd)/BBB_Setup
TOOLCHAIN_PATH=${BBB_SETUP_PATH}/Toolchain
UBOOT_PATH=${BBB_SETUP_PATH}/Uboot
KERNEL_PATH=${BBB_SETUP_PATH}/Kernel


TOOLCHAIN_DIR_NAME=gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf
UBOOT_DIR_NAME=u-boot
KERNEL_DIR_NAME=linux

if [ ! -d "${BBB_SETUP_PATH}/" ]; then
	mkdir ${BBB_SETUP_PATH}
	mkdir ${TOOLCHAIN_PATH}
	mkdir ${UBOOT_PATH}
	mkdir ${KERNEL_PATH}
	cd ${BBB_SETUP_PATH}
else
	cd ${BBB_SETUP_PATH}
fi

#### Update the system.####

#sudo apt-get update
#sudo apt-get upgrade
#sudo apt-get install bison flex lzop u-boot-tools


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

#	git clone https://github.com/beagleboard/linux.git

	popd > /dev/null
}

#### Build u-boot bootloader
function build_uboot()
{
	pushd ${UBOOT_PATH}/${UBOOT_DIR_NAME} > /dev/null
	echo "$0, $1"	
	case $1 in 
	1c|1b|2c|2b) 
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- distclean
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- am335x_boneblack_defconfig
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- 
		;;
	*)
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- 
		;;
	esac

	popd > /dev/null
}

function build_kernel()
{
	pushd ${UBOOT_PATH}/${UBOOT_DIR_NAME} > /dev/null
	
	case $1 in 
	1c|1b|3c|3b) 
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- distclean
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- bb.org_defconfig
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- uImage dtbs LOADADDR=0x80008000
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- modules
		;;
	*)
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- uImage dtbs LOADADDR=0x80008000
		make ARCH=arm CROSS_COMPILE=${TOOLCHAIN_PATH}/${TOOLCHAIN_DIR_NAME}/bin/arm-linux-gnueabihf- modules
		;;
	esac
	popd > /dev/null
}



function main_menu()
{
	clear
	echo "============================================================================================================="
	echo "||						MENU						          ||"
	echo "============================================================================================================="
	echo "	1)  All (Build) 		1b) All	   ( Download & Build-SetupAll) 	1c) All    (Clean Build)"
	echo "	2)  U-boot (Build)		2b) U-boot ( Download & Build )			2c) U-boot (Clean Build)"
	echo "	3)  Kernel (Build)		3b) Kernle ( Download & Build )			3c) Kernel (clean Build)"
	echo "	4)  All (Only Download All ) "
	echo "============================================================================================================="

	echo -ne "\e[1;42m Choose option :\e[0m"
	read SELECTED_OPTION

	case $SELECTED_OPTION in 
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
			download_toolchain
			download_uboot
			download_kernel
			;;
		*)
			echo -e "\e[1;31m ERROR: Invalid Option !!! \e[0m"
	esac
}
main_menu
