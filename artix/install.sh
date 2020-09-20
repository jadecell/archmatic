#!/bin/bash

# Init system selection

INITCHOICE=" "
echo "[CHOICE] Which init system would you like to install?"
echo "1) OpenRC"
echo "2) Runit"
echo "3) S6"

read -p "Choice: " INITCHOICE

INITSYSTEMPACKAGES=" "
INITSYSTEMNAME=" "
case $INITCHOICE in
    "1") INITSYSTEMPACKAGES="openrc" && INITSYSTEMNAME="openrc" ;;
    "2") INITSYSTEMPACKAGES="runit elogind-runit" && INITSYSTEMNAME="runit" ;;
    "3") INITSYSTEMPACKAGES="s6 elogind-s6" && INITSYSTEMNAME="s6" ;;
esac

# Kernel selection

KERNELCHOICE=" "
echo "[CHOICE] Which kernel would you like to install?"
echo "1) Linux"
echo "2) Linux LTS"

read -p "Choice: " KERNELCHOICE

KERNEL=" "
case $KERNELCHOICE in
    "1") KERNEL="linux" ;;
    "2") KERNEL="linux-lts" ;;
    *) echo "[INFO] Default kernel was selected: Linux" && KERNEL="linux" ;;
esac

# Asks for the drive location for Arch to be installed on

lsblk
DRIVELOCATION=" "
read -p "[CHOICE] What is your drive path? " DRIVELOCATION

# Runs the disk partioning program

DRIVEPATH="/dev/$DRIVELOCATION"
wipefs -a $DRIVEPATH
parted -a optimal $DRIVEPATH --script mklabel gpt
parted $DRIVEPATH --script mkpart primary 1MiB 513MiB
parted $DRIVEPATH --script name 1 boot
parted $DRIVEPATH --script -- mkpart primary 513MiB -1
parted $DRIVEPATH --script name 2 rootfs
parted $DRIVEPATH --script set 1 boot on

# Asks if the user has a swap partition

SWAP="n"
read -p "[CHOICE] Do you have a swap partition [y/n]? " SWAP

# Makes the filesystems

ISNVME=" "
read -p "[CHOICE] Is your install drive an nvme device [y/n]? " ISNVME

PARTENDING=" "
[ "$ISNVME" = "y" ] && PARTENDING="p" || PARTENDING=""

echo "[INFO] Setting filesystems"
mkfs.fat -F32 /dev/${DRIVELOCATION}${PARTENDING}1 1>/dev/null
mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}2 1>/dev/null

# Optionally makes a swap filesystem if the user has a swap partition

[ "$SWAP" = "y" ] && mkswap /dev/${DRIVELOCATION}${PARTENDING}3 1>/dev/null && swapon /dev/${DRIVELOCATION}${PARTENDING}3 1>/dev/null

echo "[INFO] Successfully made all filesystems!"

# Mount partitions

echo "[INFO] Mounting all partitions"
mount -t ext4 /dev/${DRIVELOCATION}${PARTENDING}2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/${DRIVELOCATION}${PARTENDING}1 /mnt/boot/efi
echo "[INFO] Successfully mounted all partitions!"

# Installs all software 

echo "[INFO] Installing all needed packages for a base system."
basestrap /mnt base base-devel $INITSYSTEMPACKAGES $KERNEL linux-firmware efibootmgr vim vi zsh nano curl wget grub networkmanager networkmanager-$INITSYSTEMNAME sudo man-db man-pages git 2>&1 >/dev/null
echo "[INFO] Installed all software."

# Generate the FileSystem Table

echo "[INFO] Generating the FileSystem table..."
fstabgen -U /mnt >> /mnt/etc/fstab
echo "[INFO] Successfully generated the FileSystem table!"

# Copy the new script to the new root directory

echo "INITSYSTEMNAME=$INITSYSTEMNAME" >> /root/archmatic/artix/values

cp -f /root/archmatic/artix/chrooted.sh /mnt
cp -f /root/archmatic/artix/values /mnt

# Change root and exec the rest of the commands

artools-chroot /mnt ./chrooted.sh
