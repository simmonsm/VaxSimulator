#!/bin/bash
echo "creates the simh vax  install environment under /opt, pulls and builds the vax simulator"
#
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

space=`df  . --output='avail' | tail -1`
echo "disk space available is $space"
if [ $space -lt 300000000 ]
then
	echo "Not enough space. This install needs around 2.5Gb."
	exit 1
fi
exit

ether=`ip -br l | awk '$1 !~ "lo|vir|wl" { print $1}'`
echo "using network interface named $ether"

echo "updating system repositories"
apt-get update -y
echo "installing all simulator dependencies..."
apt-get install make libsdl2-dev libpng-dev libpcap-dev libvdeplug-dev bridge-utils unzip wget git gcc build-essential libedit-dev curl -y
#2. Get SimH from GitHub:
if [ ! -d /opt ]
then
	mkdir /opt
fi
cd /opt
if [ ! -d simh ]
then
 git clone https://github.com/simh/simh.git
 #3. Build a VAX 8600 simulator
 cd simh
 make -j4 vax8600  
 #4. Create a new emulator directory and copy the emulator binary
 mkdir -p /opt/simulators/vax8600/iso
 mkdir -p /opt/simulators/vax8600/data
 mkdir -p /opt/simulators/vax8600/log
 mkdir -p /opt/simulators/vax8600/bin
 cp /opt/simh/BIN/vax8600 /opt/simulators/vax8600/bin/
fi

#5. Download the VAX/VMS 7.1 disk image using a web browser & install into the ISO directory
if [ ! -e /opt/simulators/vax8600/iso/VAXVMS071.iso ]
then
	if [ ! -e AG-QSBWB-BE.iso ]
	then
		if [ ! -e AG-QSBWB-BE.iso.zip ] 
		then
			echo "Retrieving VAX iso from vaxhaven.."
 			wget http://vaxhaven.com/cd-image/AG-QSBWB-BE.iso.zip
 			if [ ! -e AS-QSBWB-BE.iso.zip ]
			then
				echo "failed to download iso from vaxhaven"
				exit 1
			fi
		fi
		if [ ! -e AG-QSBWB-BE.ISO ]
		then
			unzip AG-QSBWB-BE.iso.zip
 			if [ -e AG-QSBWB-BE.ISO ] 
			then
	 			rm -f AG-QSBWB-BE.iso.zip
			else
				echo "failed to unzip vaxhaven iso!"
				exit 1
			fi
		fi
		
	fi
 	cp AG-QSBWB-BE.ISO /opt/simulators/vax8600/iso/VAXVMS071.iso
	if [ ! -e /opt/simulators/vax8600/iso/VAXVMS071.iso ]
	then
		echo "failed to copy vaxhaven iso!"
		exit 1
	fi
fi

echo "preparing ini script"
cat << EOF > /opt/simulators/vax8600/data/vax8600.ini
; Set the memory size to 512 megabytes
set cpu 512M
; Use a TCP socket for the console
;set console telnet=5724 
; Set the CPU idle detection method to VMS to improve performance when OpenVMS isn't doing anything
set cpu idle=vms
; Set the CPU to a model 8650
set cpu model=8650 
; Configure an 1.5 gigabyte RA92 disk on interface RQ0
set rq0 ra92 
; Attach a disk image to interface RQ0 - SimH will create this on boot
attach RQ0 /opt/simulators/vax8600/data/rq0-ra92.dsk 
; Configure a CD-ROM drive (RRD40) on disk interface RQ3
set rq3 cdrom 
; Attach the installation disk ISO image to interface RQ3
attach RQ3 -r /opt/simulators/vax8600/iso/VAXVMS071.iso
; Disable  the RP Massbus controller
set rp disable 
; Disable the RL11 cartridge disk controller
set rl disable 
; Disable the RK611 cartridge disk controller
set hk disable 
; Disable the RX211 floppy disk controller
set ry disable
; Disable the TS11 magnetic tape controller
set ts disable 
; Disable the TUK50 magnetic tape controller
set tq disable 
; Disable the DZ11 8-line terminal multiplexer
set dz disable
; Disable the LP11 line printer
set lpt disable
; Enable the Ethernet controller
set xu enable
; Set the MAC address to use for the Ethernet controller
set xu mac=08-00-2B-E5-40-03
; Attach the Ethernet controller to a TAP interface 'vaxa'
attach xu $ether
EOF
echo "creating symbolic link"
ln -s /opt/simulators/vax8600/data/vax8600.ini /opt/simulators/vax8600/bin/
cd /opt/simulators/vax8600/bin/
echo "starting vax8600 simulator"
echo "use: boot rq0"
./vax8600
echo "Note: post-install we can now boot using rq0". see startvms.sh"
#
