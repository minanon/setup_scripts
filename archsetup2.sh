grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --boot-directory=/boot/efi/EFI --recheck --debug
sed -i -e 's/GRUB_TIMEOUT.*/GRUB_TIMEOUT=0/' /etc/default/grub
grub-mkconfig -o /boot/efi/EFI/grub/grub.cfg
