#!/usr/bin/env bash

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

choice "Enter the hostname" "" HOSTNAME
choice "Enter the username" "" USERNAMEOFUSER
lsblk && choice "What is your drive name" "" DRIVELOCATION
choice "Would you like ucode for the processor" "yn" UCODEBOOL

if [ "$UCODEBOOL" = "y" ]; then
    choice "Would you like [I]ntel or [A]MD" "" INTELORAMD
fi

case $INTELORAMD in
    i | I)
        PACKAGES_EXTRA="intel-ucode"
        ;;
    a | A)
        PACKAGES_EXTRA="amd-ucode"
        ;;
esac

# Asks the user what kernel to install
clear
printf "${CYAN}[CHOICE] Which kernel would you like to install?${NC}"
printf "1) ${RED}Linux${NC}"
printf "2) ${GREEN}Linux LTS${NC}"
printf "3) ${MAGENTA}Linux Zen${NC}"
printf "4) ${YELLOW}Linux Hardened${NC}"

printf "Choice: "
read -r KERNELCHOICE

case $KERNELCHOICE in
    1)
        KERNEL="linux"
        ;;
    2)
        KERNEL="linux-lts"
        ;;
    3)
        KERNEL="linux-zen"
        ;;
    4)
        KERNEL="linux-hardened"
        ;;
    "")
        KERNEL="linux"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

sed -i -e 's/#\ ParallelDownloads\ =\ 5/ParallelDownloads\ =\ 5' /etc/pacman.conf

# Sets ntp on the system clock

info "Setting ntp"
timedatectl set-ntp true
info "Successfully set ntp"

# Runs the disk partioning program

DRIVEPATH="/dev/$DRIVELOCATION"
wipefs -a "$DRIVEPATH"
parted -a optimal "$DRIVEPATH" --script mklabel gpt
parted "$DRIVEPATH" --script -- mkpart primary 1MiB 513MiB
parted "$DRIVEPATH" --script name 1 boot
parted "$DRIVEPATH" --script -- mkpart primary 513MiB -1
parted "$DRIVEPATH" --script name 2 rootfs
parted "$DRIVEPATH" --script set 1 boot on

# Makes the filesystems
NVMETEXT=$(echo $DRIVEPATH | cut -d'/' -f3 | cut -c 1-4)
[ "$NVMETEXT" = "nvme" ] && PARTENDING="p" || PARTENDING=""

info "Setting the filesystem"
mkfs.vfat /dev/${DRIVELOCATION}${PARTENDING}1 > /dev/null 2>&1
mkfs.btrfs /dev/${DRIVELOCATION}${PARTENDING}2 > /dev/null 2>&1
info "Successfully made all filesystems"

# Mount partitions

info "Mounting all partitions and making subvolumes"
mount /dev/${DRIVELOCATION}${PARTENDING}2 /mnt
cd /mnt
btrfs subvolume create @ > /dev/null 2>&1
btrfs subvolume create @home > /dev/null 2>&1
btrfs subvolume create @var > /dev/null 2>&1
cd /root
umount /mnt
mount -o noatime,compress=zstd,space_cache,discard=async,subvol=@ /dev/${DRIVELOCATION}${PARTENDING}2 /mnt
mkdir /mnt/boot
mkdir /mnt/home
mkdir /mnt/var
mount -o noatime,compress=zstd,space_cache,discard=async,subvol=@home /dev/${DRIVELOCATION}${PARTENDING}2 /mnt/home
mount -o noatime,compress=zstd,space_cache,discard=async,subvol=@var /dev/${DRIVELOCATION}${PARTENDING}2 /mnt/var
mount /dev/${DRIVELOCATION}${PARTENDING}1 /mnt/boot
info "Successfully mounted all partitions"

# Moves to root's home

cd /root || exit 1

# Installs software

PACKAGES="base base-devel $KERNEL linux-firmware efibootmgr vim vi zsh nano curl wget sudo man-db man-pages networkmanager git btrfs-progs"

info "Installing all needed packages for a base system"
pacstrap /mnt $PACKAGES $PACKAGES_EXTRA
info "Installed all packages"

# Generate the FileSystem Table
info "Generating the FileSystem table"
genfstab -U /mnt >> /mnt/etc/fstab
info "Successfully generated the FileSystem table"

# Copy the new script to the new root directory

cp -f archmatic/{chrooted.sh,colors,functions} /mnt

touch /mnt/values
cat << EOF > /mnt/values
HOSTNAME="$HOSTNAME"
USERNAMEOFUSER="$USERNAMEOFUSER"
DRIVELOCATION="$DRIVELOCATION"
PARTENDING=$PARTENDING"
KERNEL="$KERNEL"
EOF

# Change root and exec the part 2 script

arch-chroot /mnt ./chrooted.sh && rm -f /mnt/{values,chrooted.sh,functions,colors}
