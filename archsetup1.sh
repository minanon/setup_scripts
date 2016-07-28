parted -s -a optimal /dev/sda mklabel gpt
parted -s -a optimal /dev/sda mkpart ESP fat32 1MiB 513MiB
parted -s -a optimal /dev/sda mkpart primary ext3 513MiB 713MiB
parted -s -a optimal /dev/sda mkpart primary linux-swap 713MiB 2761MiB
parted -s -a optimal /dev/sda mkpart primary ext4 2761MiB 100%
parted -s -a optimal /dev/sda set 1 boot on
mkfs.vfat -F32 /dev/sda1
mkfs.ext3 /dev/sda2
mkswap /dev/sda3
mkfs.ext4 /dev/sda4
mount /dev/sda4 /mnt
mkdir /mnt/boot
mount /dev/sda2 /mnt/boot
mkdir /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
sed -i -e 's/^/#/' /etc/pacman.d/mirrorlist
sed -i -e '/\.jp/s/^#//' /etc/pacman.d/mirrorlist
pacstrap /mnt base vim grub dosfstools efibootmgr openssh
genfstab -U /mnt >> /mnt/etc/fstab
echo '/dev/sda3 swap swap defaults 0 0' >> /mnt/etc/fstab
arch-chroot /mnt

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --boot-directory=/boot/efi/EFI --recheck --debug
sed -i -e 's/GRUB_TIMEOUT.*/GRUB_TIMEOUT=0/' /etc/default/grub
grub-mkconfig -o /boot/efi/EFI/grub/grub.cfg

umount /dev/sda1
umount /dev/sda2
umount /dev/sda4
