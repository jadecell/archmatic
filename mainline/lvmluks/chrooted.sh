#!/bin/bash

. /values

# Declaring Variables

HOSTNAME=
USERNAME=

# add encrypt and lvm2 to the hooks in /etc/mkinitcpio.conf
sed -i -e 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ autodetect\ modconf\ block\ encrypt\ lvm2\ filesystems\ keyboard\ fsck)/g' /etc/mkinitcpio.conf
mkinitcpio -p $KERNEL

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

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "[INFO] Successfully generated locales!"

# Sets hostname

echo "[INFO] Setting hostname..."
echo "$HOSTNAME" >> /etc/hostname
echo "[INFO] Successfully set the hostname!"

# Generates host file

echo "[INFO] Generating the hosts file..."
echo "127.0.0.1		localhost" > /etc/hosts
echo "::1			localhost" >> /etc/hosts
echo "127.0.1.1		$HOSTNAME.localdomain       $HOSTNAME" >> /etc/hosts
echo "[INFO] Successfully generated the hosts file!"

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
echo "[INFO] Installing and configuring grub..."

pacman --needed --noconfirm -S grub

sed -i -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\ quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\ cryptdevice=\/dev\/${DRIVELOCATION}${PARTENDING}3:volgroup0:allow-discards\ quiet\"/g" /etc/default/grub
sed -i -e 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g' /etc/default/grub
mkdir /boot/EFI
mount /dev/${DRIVELOCATION}${PARTENDING}1 /boot/EFI

grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
mkdir /boot/grub/locale
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo

grub-mkconfig -o /boot/grub/grub.cfg

echo "[INFO] Successfully installed configured grub!"

# Adding user to sudoers file

echo "[INFO] Adding $USERNAME to the sudoers file..."

echo " " >> /etc/sudoers
echo "## Main users permissions" >> /etc/sudoers
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers

echo "[INFO] Successfully added $USERNAME to the sudoers file!"

# Starting NetworkManager at boot

echo "[INFO] Setting NetworkManager to start at boot time..."
systemctl enable NetworkManager 1>/dev/null
echo "[INFO] Successfully set NetworkManager to run at boot time!"

# Copies all install scripts to the new system
echo "[INFO] Copying all install scripts to new system..."
git clone https://gitlab.com/jadecell/installscripts.git
cp -rf installscripts/ /home/$USERNAME/installscripts
chown $USERNAME:$USERNAME /home/$USERNAME/installscripts
chown $USERNAME:$USERNAME /home/$USERNAME/installscripts/*
chmod 744 /home/$USERNAME/installscripts/*

# Finished
echo " "
echo "----------------------------------------------------------------------"
echo "Successfully finished! Reboot now."
echo "----------------------------------------------------------------------"
echo " "
