#!/bin/bash

echo "[multilib]
Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Syy
pacman -Sy --noconfirm lib32-glibc lib32-zlib gcc-multilib \
    lib32-libx11 lib32-libsm lib32-libxext lib32-libxinerama lib32-libxrender lib32-libdbus lib32-fontconfig lib32-libxdamage lib32-libxtst ecasound

pacman -Sy --noconfirm chromium terminator noto-fonts-cjk

cd /tmp
curl -L 'http://downloads.sourceforge.net/project/libpng/libpng12/1.2.56/libpng-1.2.56.tar.xz?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Flibpng%2Ffiles%2Flibpng12%2F1.2.56%2Flibpng-1.2.56.tar.xz%2Fdownload&ts=1471482765&use_mirror=jaist' | tar -Jx
curl -L 'http://downloads.sourceforge.net/project/libpng/libpng12/1.2.56/libpng-1.2.56.tar.xz?use_mirror=jaist' | tar -Jx
cd libpng-1.2.56
./configure --prefix=/usr --libdir=/usr/lib32 CFLAGS='-m32'
make -j$(nproc)
make install

curl -L 'http://www.ijg.org/files/jpegsrc.v6b.tar.gz' | tar -zx
cd jpeg-6b
./configure --prefix=/usr --libdir=/usr/lib32 --mandir=/usr/share/man --enable-shared CC='gcc -m32'
sed -i -e 's/^LIBTOOL.*/LIBTOOL = libtool/' Makefile
make -j$(nproc)
make install

ldconfig

curl -L 'https://download.teamviewer.com/download/teamviewer_i386.tar.xz' | tar -Jx -C /opt
chmod a+w /opt/teamviewer -R
