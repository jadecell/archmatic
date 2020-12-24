#!/bin/sh

#                    -@
#                   .##@
#                  .####@
#                  @#####@
#                . *######@
#               .##@o@#####@
#              /############@
#             /##############@
#            @######@**%######@
#           @######`     %#####o
#          @######@       ######%
#        -@#######h       ######@.`
#       /#####h**``       `**%@####@
#      @H@*`                    `*%#@
#     *`                            `*

# Arch install script made by Jackson
# Pre-chroot

# Source the colors
. /root/archmatic/colors

# Source the functions
. /root/archmatic/functions

# Checks for UEFI
[ ! -d /sys/firmware/efi/efivars ] && "Non UEFI system detected. Please use an UEFI system and re run." && exit 1

# Sets ntp on the system clock

choice "Enter hostname" "" HOSTNAME
choice "Enter normal user's name" "" USERNAME

# Asks the user what kernel to install
clear
KERNELCHOICE=" "
echo -e "${CYAN}[CHOICE] Which kernel would you like to install?${NC}"
echo -e "1) ${RED}Linux${NC}"
echo -e "2) ${GREEN}Linux LTS${NC}"
echo -e "3) ${MAGENTA}Linux Zen${NC}"
echo -e "4) ${YELLOW}Linux Hardened${NC}"

read -P "${CYAN}Choice: " KERNELCHOICE

info "Setting ntp"
timedatectl set-ntp true
info "Successfully set ntp"

# Sets the kernel
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
choice "What is your drive name" "" DRIVELOCATION

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
NVMETEXT=$(echo $DRIVEPATH | cut -d'/' -f3 | cut -c 1-4)
[ "$NVMETEXT" = "nvme" ] && PARTENDING="p" || PARTENDING=""


info "Setting the filesystem"
mkfs.fat -F 32 /dev/${DRIVELOCATION}${PARTENDING}1 >/dev/null 2>&1
mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}2 >/dev/null 2>&1
info "Successfully made all filesystems"

# Mount partitions

info "Mounting all partitions"
mount -t ext4 /dev/${DRIVELOCATION}${PARTENDING}2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/${DRIVELOCATION}${PARTENDING}1 /mnt/boot/efi
info "Successfully mounted all partitions"

# Moves to root's home

cd /root

# Installs software

info "Installing all needed packages for a base system"
pacstrap /mnt base base-devel $KERNEL linux-firmware efibootmgr vim vi zsh nano curl wget sudo man-db man-pages networkmanager git >/dev/null 2>&1
info "Installed all packages"

# Generate the FileSystem Table
info "Generating the FileSystem table"
genfstab -U /mnt >> /mnt/etc/fstab
info "Successfully generated the FileSystem table"

# Copy the new script to the new root directory

cp -f archmatic/mainline/standard/chrooted.sh /mnt
cp -f archmatic/colors /mnt
cp -f archmatic/functions /mnt

touch /mnt/values
echo "HOSTNAME=\"$HOSTNAME\"" > /mnt/values
echo "USERNAME=\"$USERNAME\"" >> /mnt/values

# Change root and exec the part 2 script

arch-chroot /mnt ./chrooted.sh
