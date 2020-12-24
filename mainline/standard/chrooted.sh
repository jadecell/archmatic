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
echo "[INFO] Successfully generated locales!"

# Sets hostname

info "Setting hostname"
echo "$HOSTNAME" >> /etc/hostname
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
grub-install --target=x86_64-efi --efi-directory=/boot/efi >/dev/null 2>&1
grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
info "Successfully installed configuring grub"

# Adding user to sudoers file

info "Adding $USERNAME to the sudoers file"
echo " " >> /etc/sudoers
echo "## Main users permissions" >> /etc/sudoers
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers
info "Successfully add $USERNAME to the sudoers file"

# Starting NetworkManager at boot

info "Setting NetworkManager to start at boot time"
systemctl enable NetworkManager 1>/dev/null
info "Successfully set NetworkManager to run at boot time"

# Copies all install scripts to the new system
info "Copying all install scripts to new system"
cd /home/$USERNAME
git clone https://gitlab.com/jadecell/installscripts.git
chown -R $USERNAME:$USERNAME installscripts/

# Root password

echo "---------------------SET ROOT PASSWORD---------------------"
passwd
info "Successfully set the root password"

# Add the normal user

useradd -mG wheel,audio,video,storage,optical -s /bin/bash $USERNAME

echo "---------------------SET $USERNAME's PASSWORD---------------------"
passwd $USERNAME
info "Successfully set $USERNAME's password"

# Finished
echo " "
echo "${GREEN}Successfully finished!${NC} ${RED}Reboot now.${NC}"
echo " "
