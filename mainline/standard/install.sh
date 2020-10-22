#!/bin/bash

# Sets ntp on the system clock

echo "[INFO] Setting ntp..."
timedatectl set-ntp true
echo "[INFO] Successfully set ntp!"

# Asks the user what kernel to install
KERNELCHOICE=" "
echo "[CHOICE] Which kernel would you like to install?"
echo "1) Linux"
echo "2) Linux LTS"
echo "3) Linux Zen"
echo "4) Linux Hardened"

read -p "Choice: " KERNELCHOICE

KERNEL=" "
case $KERNELCHOICE in
    "1") KERNEL="linux" ;;
    "2") KERNEL="linux-lts" ;;
    "3") KERNEL="linux-zen" ;;
    "4") KERNEL="linux-hardened" ;;
    *) echo "[INFO] Default kernel was selected: Linux" && KERNEL="linux" ;;
esac

# Asks for the drive location for Arch to be installed on

lsblk
DRIVELOCATION=" "
read -p "[CHOICE] What is your drive name? " DRIVELOCATION

# Runs the disk partioning program

DRIVEPATH="/dev/$DRIVELOCATION"
wipefs -a $DRIVEPATH
parted -a optimal $DRIVEPATH --script mklabel gpt
parted $DRIVEPATH --script mkpart primary 1MiB 513MiB
parted $DRIVEPATH --script name 1 boot
parted $DRIVEPATH --script -- mkpart primary 513MiB -1
parted $DRIVEPATH --script name 2 rootfs
parted $DRIVEPATH --script set 1 boot on

# Makes the filesystems
ISNVME=" "
read -p "[CHOICE] Is your install drive an nvme device [y/n]? " ISNVME

PARTENDING=" "
[ "$ISNVME" = "y" ] && PARTENDING="p" || PARTENDING=""

echo "[INFO] Setting filesystems"
mkfs.fat -F 32 /dev/${DRIVELOCATION}${PARTENDING}1 1>/dev/null
mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}2 1>/dev/null
echo "[INFO] Successfully made all filesystems!"

# Mount partitions

echo "[INFO] Mounting all partitions"
mount -t ext4 /dev/${DRIVELOCATION}${PARTENDING}2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/${DRIVELOCATION}${PARTENDING}1 /mnt/boot/efi
echo "[INFO] Successfully mounted all partitions!"

# Moves to root's home

cd /root

# Installs software

echo "[INFO] Installing all needed packages for a base system..."
pacstrap /mnt base base-devel $KERNEL linux-firmware efibootmgr vim vi zsh nano curl wget sudo dhcpcd dhclient man-db man-pages networkmanager git 1>/dev/null 2>/dev/null
echo "[INFO] Installed all packages!"

# Generate the FileSystem Table
echo "[INFO] Generating the FileSystem table..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "[INFO] Successfully generated the FileSystem table!"

# Copy the new script to the new root directory

cp -f archmatic/mainline/standard/chrooted.sh /mnt

# Change root and exec the part 2 script

arch-chroot /mnt ./chrooted.sh
