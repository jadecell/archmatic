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
# Post-chroot

# Source the colors
. /colors

# Source the functions
. /functions

# Source the values
. /values

# Add encrypt and lvm2 to the hooks in /etc/mkinitcpio.conf
[ "$LVMLUKS" = "y" ] && sed -i -e 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ autodetect\ modconf\ block\ encrypt\ lvm2\ filesystems\ keyboard\ fsck)/g' /etc/mkinitcpio.conf && info "Generating the initramfs" && mkinitcpio -p $KERNEL >/dev/null 2>&1

# Sets timezone to Vancouvers timezone
info "Setting timezone"
ln -sf /usr/share/zoneinfo/America/Vancouver /etc/localtime >/dev/null 2>&1
info "Successfully set the timezone"

# Sets hardware clock
info "Setting hardware clock"
hwclock --systohc
info "Successfully set the hardware clock"

# Generate locales
info "Generating locales"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen

locale-gen >/dev/null 2>&1

# Create locale.conf
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
info "Successfully generated locales"

# Sets hostname
info "Setting hostname"
echo "$HOSTNAME" > /etc/hostname
info "Successfully set the hostname"

# Generates host file
info "Generating the hosts file"
echo "127.0.0.1		localhost" > /etc/hosts
echo "::1			localhost" >> /etc/hosts
echo "127.0.1.1		$HOSTNAME.localdomain       $HOSTNAME" >> /etc/hosts
info "Successfully generated the hosts file"

# Configures grub
info "Installing and configuring grub"
pacman --needed --noconfirm -S grub >/dev/null 2>&1

if [[ "$LVMLUKS" = "y" ]]; then

    sed -i -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\ quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\ cryptdevice=\/dev\/${DRIVELOCATION}${PARTENDING}3:volgroup0:allow-discards\ quiet\"/g" /etc/default/grub
    sed -i -e 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g' /etc/default/grub
    mkdir /boot/EFI
    mount /dev/${DRIVELOCATION}${PARTENDING}1 /boot/EFI

    grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck >/dev/null 2>&1
    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    mkdir /boot/grub/locale
    cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo

else

    grub-install --target=x86_64-efi --efi-directory=/boot/efi >/dev/null 2>&1
    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1

fi

info "Successfully installed configuring grub"

# Adding user to sudoers file
info "Adding $USERNAME to the sudoers file"
echo " " >> /etc/sudoers
echo "## Main users permissions" >> /etc/sudoers
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers
info "Successfully add $USERNAME to the sudoers file"

# Starting NetworkManager at boot
info "Setting NetworkManager to start at boot time"
systemctl enable NetworkManager >/dev/null 2>&1
info "Successfully set NetworkManager to run at boot time"

# Root password
echo -e "${YELLOW}---------------------SET ${RED}ROOT${YELLOW} PASSWORD---------------------${NC}"
passwd
info "Successfully set the root password"

# Add the normal user
useradd -mG wheel,audio,video,storage,optical -s /bin/bash $USERNAME

echo -e "${YELLOW}---------------------SET ${RED}$USERNAME${YELLOW}'s PASSWORD---------------------${NC}"
passwd $USERNAME
info "Successfully set $USERNAME's password"

# Finished
echo " "
echo -e "${GREEN}Successfully finished!${NC} ${RED}Reboot now.${NC}"
echo " "
