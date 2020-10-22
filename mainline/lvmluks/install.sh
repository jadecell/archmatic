#!/bin/bash

### LVM + LUKS base archlinux install

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
parted $DRIVEPATH --script name 1 efi
parted $DRIVEPATH --script mkpart primary 513MiB 1025MiB
parted $DRIVEPATH --script name 2 boot
parted $DRIVEPATH --script -- mkpart primary 1025MiB -1
parted $DRIVEPATH --script name 3 lvmpart
parted $DRIVEPATH --script set 1 boot on
parted $DRIVEPATH --script set 3 lvm on

# Makes the filesystems
ISNVME=" "
read -p "[CHOICE] Is your install drive an nvme device [y/n]? " ISNVME

PARTENDING=" "
[ "$ISNVME" = "y" ] && PARTENDING="p" || PARTENDING=""

# echo "[INFO] Setting filesystems"
mkfs.fat -F 32 /dev/${DRIVELOCATION}${PARTENDING}1
mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}2
cryptsetup luksFormat /dev/${DRIVELOCATION}${PARTENDING}3
cryptsetup open --type luks /dev/${DRIVELOCATION}${PARTENDING}3 lvm
# echo "[INFO] Successfully made all filesystems!"

ROOTFSSIZE=
read -p "How many GB should the root partition be? " ROOTFSSIZE

# LVM/LUKS partitioning
pvcreate --dataalignment 1m /dev/mapper/lvm
vgcreate volgroup0 /dev/mapper/lvm
lvcreate -L $ROOTFSSIZE volgroup0 -n lv_root
lvcreate -l 95%FREE volgroup0 -n lv_home
mkfs.ext4 /dev/volgroup0/lv_root
mkfs.ext4 /dev/volgroup0/lv_home

# Mount partitions

# echo "[INFO] Mounting all partitions"
mount /dev/volgroup0/lv_root /mnt
mkdir /mnt/{home,boot,etc}
mount /dev/volgroup0/lv_home /mnt/home
mount /dev/${DRIVELOCATION}${PARTENDING}2 /mnt/boot
# echo "[INFO] Successfully mounted all partitions!"

# Moves to root's home

cd /root

# Installs software

echo "[INFO] Installing all needed packages for a base system..."
pacstrap /mnt base base-devel $KERNEL $KERNEL-headers linux-firmware dialog lvm2 dosfstools efibootmgr vim vi zsh nano curl wget sudo dhcpcd dhclient man-db man-pages networkmanager git
echo "[INFO] Installed all packages!"

# Generate the FileSystem Table
echo "[INFO] Generating the FileSystem table..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "[INFO] Successfully generated the FileSystem table!"

touch /root/archmatic/mainline/lvmluks/values
echo "KERNEL=$KERNEL" > /root/archmatic/mainline/lvmluks/values
echo "DRIVELOCATION=$DRIVELOCATION" >> /root/archmatic/mainline/lvmluks/values
echo "PARTENDING=$PARTENDING" >> /root/archmatic/mainline/lvmluks/values
cp -f /root/archmatic/mainline/lvmluks/values /mnt

# Copy the new script to the new root directory

cp -f /root/archmatic/mainline/lvmluks/chrooted.sh /mnt

# Change root and exec the part 2 script

arch-chroot /mnt ./chrooted.sh
