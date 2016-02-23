#!/bin/bash

set -eu

### url settings
rbenv_url=https://github.com/rbenv/rbenv.git
plugin_urls=(
    https://github.com/rbenv/ruby-build.git
    https://github.com/tpope/rbenv-aliases.git
)

### default install path
default_root='${HOME}/.rbenv'


### functions
update_git_repos()
{
    local url=${1}
    local path=${2}

    if [ -d "${path}/.git" ]
    then
        local git_cmd="git --git-dir=${path}/.git --work-tree=${path}"
        local branch=$( ${git_cmd} branch --contains=HEAD )
        ${git_cmd} remote update
        ${git_cmd} merge ${branch#* }
    else
        git clone "${url}" "${path}"
    fi
}

usage_exit(){
    echo "Usage: ${0} [-t <install target path>][-f : force install when git is existed][-g : only install with git]"
    exit 1
}

# params variables
force_install_without_git=false
git_only=false
rbenv_root_str=""

### params
while getopts t:fg opt
do
    case $opt in
        t)
            rbenv_root_str=$OPTARG
            ;;
        f)
            force_install_without_git=true
            ;;
        g)
            git_only=false
            ;;
        \?|h)
            usage_exit
            ;;
    esac
done
shift $((OPTIND - 1))


### install path
if [ -z "${rbenv_root_str}" ]
then
    echo -n "install rbenv to [${default_root}]: "
    read -r rbenv_root_str
    [ -z "${rbenv_root_str}" ] && rbenv_root_str=${default_root}
fi
rbenv_root_str=${rbenv_root_str%/}
rbenv_root=$(eval "echo ${rbenv_root_str}")


### install plenv and plugins
if type git 1>/dev/null 2>&1
then
    update_git_repos ${rbenv_url} ${rbenv_root}
    for url in "${plugin_urls[@]}"
    do
        name=$(basename ${url})
        update_git_repos "${url}" "${rbenv_root}/plugins/${name%.git}"
    done
else

    # not use git
    echo "   !!! Git is not installed. !!!"
    ${git_only} && exit

    u_input=y
    no_git_force=1
    ${force_install_without_git} || {
        echo -n "Do you want to install rbenv environment without git? [Y|n]: "
        read -r u_input
    }

    case ${u_input} in
        n*|N*)
            echo "rbenv was not installed."
            exit 1;
            ;;
        *)
            rbenv_dir=/tmp/$( buf=$(curl -L "${rbenv_url%.git}/archive/master.tar.gz" | tar -zxv -C /tmp/); echo "${buf}" | head -n1)
            ( [ -z "${rbenv_dir}" ] || [ ! -d "${rbenv_dir}" ] ) && exit 1;
            cp -aT ${rbenv_dir} ${rbenv_root}
            rm -rf ${rbenv_dir}

            mkdir -p ${rbenv_root}/plugins
            for url in "${plugin_urls[@]}"
            do
                curl -L "${url%.git}/archive/master.tar.gz" | tar -zx -C ${rbenv_root}/plugins
            done
            ;;
    esac
fi

### public rbenv environment
sh_path=/tmp/rbenv.sh
cat << RB_ENV  > ${sh_path}
RBENV_ROOT=${rbenv_root_str}
[ -d "\${RBENV_ROOT}" ] \\
    && export RBENV_ROOT \\
    && export PATH=\${RBENV_ROOT}/bin:\${PATH} \\
    && eval "\$(rbenv init -)"
RB_ENV

type yum 1>/dev/null 2>&1 \
    && yum install -y gcc make openssl-devel readline-devel zlib-devel \
    || echo 'Warning: Please install "gcc, make, openssl library, readline library, zlib library" for build ruby'

cat <<MSG
1. Please set rbenv environment.
    to system:
        mv ${sh_path} /etc/profile.d/rbenv.sh

    user enviroment:
        cat ${sh_path} >> ~/.bashrc

2. Please execute following command for using rbenv on this terminal after complete all your process.
        exec -l \$SHELL
MSG
