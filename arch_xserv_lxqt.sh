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

[ -z "${user}" ] && { echo 'no user' ; exit 1; }

# install libs
pacman -Sy --noconfirm xorg-server xorg-xauth xorg-xinit lxqt make

# create user
grep ${user} /etc/passwd > /dev/null 2>&1 \
    || useradd -m -p $(perl -e "print crypt('${user}', 'aa')") ${user}

# install tdm
if ! type tdm > /dev/null 2>&1
then
    curl -L ${tdm_repos} | tar -zx -C /tmp
    cd /tmp/console-tdm-*
    make install
    cd /tmp
    rm -rf /tmp/console-tdm-*
    ln -s ${lxqt_path} ${tdm_install_dir}/share/tdm/sessions/${lxqt_name}
fi

# x user settings
tdmctl_cmd=$(type -P tdmctl)
su -  ${user} -c "${tdmctl_cmd} init; ${tdmctl_cmd} default ${lxqt_name}"

udir=$(bash -c "echo ~${user}")
echo 'exec tdm --xstart' > ${udir}/.xinitrc
sed -i -e "/source \+.*tdm/d" ${udir}/.bash_profile
echo "source $(type -P tdm)" >> ${udir}/.bash_profile
chown ${user}. ${udir}/{.xinitrc,.bash_profile}
