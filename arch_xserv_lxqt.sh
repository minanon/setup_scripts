#!/bin/bash

# user vars
tdm_repos='https://github.com/dopsi/console-tdm/archive/v1.1.1.tar.gz'

# system vars
lxqt_path='/usr/bin/startlxqt'
lxqt_name='LXQt'
tdm_install_dir='/usr/local'

# target user
echo -n 'target user: '
read -r user

[ -z "${user}" ] && ( echo 'no user' ; exit 1 )

# install libs
pacman --noconfirm xorg-server xorg-xauth xorg-xinit lxqt make

# create user
grep ${user} /etc/passwd > /dev/null 2>&1 \
    || useradd -m ${user}

# install tdm
curl -L ${tdm_repos} | tar -zx -C /tmp
cd /tmp/console-tdm-*
make install
cd /tmp
rm -rf /tmp/console-tdm-*
ls -s ${lxqt_path} ${tdm_install_dir}/share/tdm/sessions/${lxqt_name}

# x user settings
echo 'exec tdm --xstart' > ~${user}/.xinitrc
echo "source ${tdm_install_prefix}" >> ~${user}/.bash_profile
