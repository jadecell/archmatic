#!/bin/bash

# Sources variables from install.sh

. /values

# Declaring Variables

HOSTNAME=
USERNAME=

# Asks the user for the hostname and username to use

read -p "Enter a hostname: " HOSTNAME
read -p "Enter a username: " USERNAME

# Sets timezone to Vancouvers timezone

echo "[INFO] Setting timezone..."
ln -sf /usr/share/zoneinfo/America/Vancouver /etc/localtime 1>/dev/null
echo "[INFO] Successfully set the timezone!"

# Sets hardware clock

echo "[INFO] Setting hardware clock..."
hwclock --systohc
echo "[INFO] Successfully set the hardware clock!"

# Generate locales

echo "[INFO] Generating locales..."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen

locale-gen 1>/dev/null

# Create locale.conf

echo 'export LANG="en_US.UTF-8"' >> /etc/locale.conf
echo 'export LC_COLLATE="C"' >> /etc/locale.conf
echo "[INFO] Successfully generated locales!"

# Sets hostname

echo "[INFO] Setting hostname..."
echo "$HOSTNAME" >> /etc/hostname
echo "[INFO] Successfully set the hostname!"

# Root password

echo "---------------------SET ROOT PASSWORD---------------------"
passwd
echo "[INFO] Successfully set the root password!"

# Add the normal user

useradd -mG wheel,audio,video,storage,optical -s /bin/bash $USERNAME

echo "---------------------SET $USERNAME's PASSWORD---------------------"
passwd $USERNAME
echo "[INFO] Successfully set $USERNAME's password!"

# Configures grub

echo "[INFO] Configuring grub..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub 1>/dev/null
grub-mkconfig -o /boot/grub/grub.cfg 1>/dev/null

echo "[INFO] Successfully installed configured grub!"

# Adding user to sudoers file

echo "[INFO] Adding $USERNAME to the sudoers file..."

echo " " >> /etc/sudoers
echo "## Main users permissions" >> /etc/sudoers
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers

echo "[INFO] Successfully added $USERNAME to the sudoers file!"

# Starting NetworkManager at boot

servicestart() {
    case $INITSYSTEMNAME in
        "openrc") rc-update add $1 ;;
        "runit") ln -s /etc/runit/sv/$1 /etc/runit/runsvdir/current ;;
        "s6") s6-rc-bundle -c /etc/s6/rc/compiled add default $1 ;;
    esac
}

echo "[INFO] Setting NetworkManager to start at boot time..."
servicestart NetworkManager
echo "[INFO] Successfully set NetworkManager to run at boot time!"

# Copies all install scripts to the new system
 
echo "[INFO] Copying all install scripts to new system..."
git clone https://gitlab.com/jadecell/installscripts.git 
cp -rf installscripts/ /home/$USERNAME/installscripts
chown $USERNAME:$USERNAME /home/$USERNAME/installscripts
chown $USERNAME:$USERNAME /home/$USERNAME/installscripts/*
chmod 744 /home/$USERNAME/installscripts/*
rm -f /values

# Finished

echo " "
echo "----------------------------------------------------------------------"
echo "Successfully finished! Reboot now."
echo "----------------------------------------------------------------------"
echo " "

