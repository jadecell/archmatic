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
# Post-chroot

# Source the colors
. /colors

# Source the functions
. /functions

# Source the values
. /values

# Sets timezone to Vancouvers timezone
info "Setting timezone"
ln -sf /usr/share/zoneinfo/America/Vancouver /etc/localtime > /dev/null 2>&1
info "Successfully set the timezone"

# Sets hardware clock
info "Setting hardware clock"
hwclock --systohc
info "Successfully set the hardware clock"

# Generate locales
info "Generating locales"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen

locale-gen > /dev/null 2>&1

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
pacman --needed --noconfirm -S grub > /dev/null 2>&1

grub-install --target=x86_64-efi --efi-directory=/boot > /dev/null 2>&1
grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1

info "Successfully installed configuring grub"

# Adding user to sudoers file
info "Adding $USERNAMEOFUSER to the sudoers file"
echo " " >> /etc/sudoers
echo "## Main users permissions" >> /etc/sudoers
echo "$USERNAMEOFUSER ALL=(ALL) ALL" >> /etc/sudoers
info "Successfully add $USERNAMEOFUSER to the sudoers file"

info "Adding persistant sudo across ttys/terminals"
echo " " >> /etc/sudoers
echo "## Disable tty tickets so you don't have to re-type your sudo pasword for every new process/terminal" >> /etc/sudoers
echo "Defaults !tty_tickets" >> /etc/sudoers
info "Added persistant sudo across ttys/terminals"

# Starting NetworkManager at boot
info "Setting NetworkManager to start at boot time"
systemctl enable NetworkManager > /dev/null 2>&1
info "Successfully set NetworkManager to run at boot time"

chown -R $USERNAMEOFUSER:$USERNAMEOFUSER /home/$USERNAMEOFUSER

# Root password
clear
echo -e "${YELLOW}---------------------SET ${RED}ROOT${YELLOW} PASSWORD---------------------${NC}"
passwd
info "Successfully set the root password"

# Add the normal user
useradd -mG wheel,audio,video,storage,optical -s /bin/bash $USERNAMEOFUSER

clear
echo -e "${YELLOW}---------------------SET ${RED}$USERNAMEOFUSER${YELLOW}'s PASSWORD---------------------${NC}"
passwd $USERNAMEOFUSER
info "Successfully set $USERNAMEOFUSER's password"

# Finished
echo " "
echo -e "${GREEN}Successfully installed ${LIGHTCYAN}Arch${NC}! ${RED}Reboot now.${NC}"
echo " "
