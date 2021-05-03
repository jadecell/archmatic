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

usage() {
    cat << EOF
    install.sh [OPTIONS]
Options:
    -h: prints this menu
    -n: hostname
    -d: drive location
    -u: username for non root user
    -l: toggles if the install is lvm/luks
EOF
    exit 1
}

LVMLUKS=n

# Collects all options

while getopts "n:d:u:l:h" o; do
    case "$o" in
        n) HOSTNAME="${OPTARG}" ;;
        d) DRIVELOCATION="${OPTARG}" ;;
        u) USERNAMEOFUSER="${OPTARG}" ;;
        l) LVMLUKS=y ;;
        h) usage ;;
        *) printf 'Invalid options: -%s\n' "$OPTARG" && usage ;;
    esac
done

# Checks to see if automode is enabled
[ -z "$HOSTNAME" ] && choice "Enter the hostname" "" HOSTNAME
[ -z "$USERNAMEOFUSER" ] && choice "Enter the username" "" USERNAMEOFUSER
# Asks the user what kernel to install
clear
echo -e "${CYAN}[CHOICE] Which kernel would you like to install?${NC}"
echo -e "1) ${RED}Linux${NC}"
echo -e "2) ${GREEN}Linux LTS${NC}"
echo -e "3) ${MAGENTA}Linux Zen${NC}"
echo -e "4) ${YELLOW}Linux Hardened${NC}"

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

# Asks for the drive location for Arch to be installed on
[ -z "$DRIVELOCATION" ] && lsblk && choice "What is your drive name" "" DRIVELOCATION

# Sets ntp on the system clock
info "Setting ntp"
timedatectl set-ntp true
info "Successfully set ntp"

# Runs the disk partioning program

if [[ "$LVMLUKS" = "y" ]]; then

    # Runs the disk partioning program

    DRIVEPATH="/dev/$DRIVELOCATION"
    wipefs -a $DRIVEPATH
    parted -a optimal $DRIVEPATH --script mklabel gpt
    parted $DRIVEPATH --script -- mkpart primary 1MiB 513MiB
    parted $DRIVEPATH --script name 1 efi
    parted $DRIVEPATH --script -- mkpart primary 513MiB 1025MiB
    parted $DRIVEPATH --script name 2 boot
    parted $DRIVEPATH --script -- mkpart primary 1025MiB -1
    parted $DRIVEPATH --script name 3 lvmpart
    parted $DRIVEPATH --script set 1 boot on
    parted $DRIVEPATH --script set 3 lvm on

    NVMETEXT=$(echo $DRIVEPATH | cut -d'/' -f3 | cut -c 1-4)
    [ "$NVMETEXT" = "nvme" ] && PARTENDING="p" || PARTENDING=""

    info "Setting filesystems"
    mkfs.fat -F 32 /dev/${DRIVELOCATION}${PARTENDING}1 > /dev/null 2>&1
    mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}2 > /dev/null 2>&1
    cryptsetup luksFormat /dev/${DRIVELOCATION}${PARTENDING}3
    cryptsetup open --type luks /dev/${DRIVELOCATION}${PARTENDING}3 lvm
    info "Successfully made all filesystems"

    choice "How many GB should the root partition be" "" ROOTFSSIZE

    # LVM/LUKS partitioning
    pvcreate --dataalignment 1m /dev/mapper/lvm > /dev/null 2>&1
    vgcreate volgroup0 /dev/mapper/lvm > /dev/null 2>&1
    lvcreate -L ${ROOTFSSIZE}GB volgroup0 -n lv_root > /dev/null 2>&1
    lvcreate -l 95%FREE volgroup0 -n lv_home > /dev/null 2>&1
    mkfs.ext4 /dev/volgroup0/lv_root > /dev/null 2>&1
    mkfs.ext4 /dev/volgroup0/lv_home > /dev/null 2>&1

    # Mount partitions
    info "Mounting all partitions"
    mount /dev/volgroup0/lv_root /mnt
    mkdir /mnt/{home,boot,etc}
    mount /dev/volgroup0/lv_home /mnt/home
    mount /dev/${DRIVELOCATION}${PARTENDING}2 /mnt/boot
    info "Successfully mounted all partitions"

else

    printf "How many GB should the root partition be: "
    read -r ROOTFSSIZE
    ROOTFSSIZEPLUSONE=$((ROOTFSSIZE + 1))

    DRIVEPATH="/dev/$DRIVELOCATION"
    wipefs -a "$DRIVEPATH"
    parted -a optimal "$DRIVEPATH" --script mklabel gpt
    parted "$DRIVEPATH" --script -- mkpart primary 1MiB 513MiB
    parted "$DRIVEPATH" --script name 1 boot
    parted "$DRIVEPATH" --script -- mkpart primary 513MiB ${ROOTFSSIZEPLUSONE}513MiB
    parted "$DRIVEPATH" --script name 2 rootfs
    parted "$DRIVEPATH" --script -- mkpart primary ${ROOTFSSIZEPLUSONE}513MiB -1
    parted "$DRIVEPATH" --script name 3 home
    parted "$DRIVEPATH" --script set 1 boot on

    # Makes the filesystems
    NVMETEXT=$(echo $DRIVEPATH | cut -d'/' -f3 | cut -c 1-4)
    [ "$NVMETEXT" = "nvme" ] && PARTENDING="p" || PARTENDING=""

    info "Setting the filesystem"
    mkfs.fat -F 32 /dev/${DRIVELOCATION}${PARTENDING}1 > /dev/null 2>&1
    mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}2 > /dev/null 2>&1
    mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}3 > /dev/null 2>&1
    info "Successfully made all filesystems"

    # Mount partitions

    info "Mounting all partitions"
    mount -t ext4 /dev/${DRIVELOCATION}${PARTENDING}2 /mnt
    mkdir -p /mnt/{boot,home}
    mount /dev/${DRIVELOCATION}${PARTENDING}1 /mnt/boot
    mount /dev/${DRIVELOCATION}${PARTENDING}3 /mnt/home
    info "Successfully mounted all partitions"

fi

# Moves to root's home

cd /root || exit 1

# Installs software

[ "$LVMLUKS" = "y" ] && PACKAGES="base base-devel $KERNEL $KERNEL-headers linux-firmware dialog lvm2 dosfstools efibootmgr vim vi zsh nano curl wget sudo man-db man-pages networkmanager git" || PACKAGES="base base-devel $KERNEL linux-firmware efibootmgr vim vi zsh nano curl wget sudo man-db man-pages networkmanager git"

info "Installing all needed packages for a base system"
pacstrap /mnt $PACKAGES > /dev/null 2>&1
info "Installed all packages"

# Generate the FileSystem Table
info "Generating the FileSystem table"
genfstab -U /mnt >> /mnt/etc/fstab
info "Successfully generated the FileSystem table"

# Copy the new script to the new root directory

cp -f archmatic/{mainline/chrooted.sh,colors,functions} /mnt

touch /mnt/values
cat << EOF > /mnt/values
HOSTNAME="$HOSTNAME"
USERNAMEOFUSER="$USERNAMEOFUSER"
DRIVELOCATION="$DRIVELOCATION"
PARTENDING=$PARTENDING"
KERNEL="$KERNEL"
LVMLUKS="$LVMLUKS"
EOF

# Change root and exec the part 2 script

arch-chroot /mnt ./chrooted.sh && rm -f /mnt/{values,chrooted.sh,functions,colors}
