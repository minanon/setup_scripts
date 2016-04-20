#!/bin/sh

# Please install zlib and libncurse for development

app_root=${HOME}/.apps
tmp=${HOME}/.tmp

set -eu

# check cmd
chk_cmd()
{
    local cmd=${1}
    type ${cmd} >/dev/null 2>&1 || {
        local result=$?
        echo "${cmd} command is not found."
        return ${result}
    }
}
chk_cmd curl
chk_cmd make
chk_cmd gcc
chk_cmd tar
chk_cmd bzip2
chk_cmd tclsh
chk_cmd msgfmt
perl -M'ExtUtils::MakeMaker' -e '' > /dev/null 2>&1 || { echo 'perl ExtUtils::MakeMaker is not found.'  ; return 1 ; }

mkdir -p ${app_root} ${tmp}

base_conf="./configure --prefix=${app_root}"

# dl and return extracted dir name
dl_dir()
{
    local url="${1}"
    local args="-zxv"
    local ext=$(echo "${url}" | sed -e 's/.*\.//')
    case ${ext} in
        gz) args="-zxv" ;;
        bz2) args="-jxv" ;;
        xz) args="-Jxv" ;;
    esac
    echo "${tmp}/$( buf=$(curl -L "${url}" --insecure | tar ${args} -C ${tmp}); echo "${buf}" | head -n1)"
}

chk_installed()
{
    local cmd=${1}
    local lib=${2:-}
    [ -f "${app_root}/bin/${cmd}" ] || ( [ "${lib}" ] && grep "${lib}" "${app_root}/lib/" -R > /dev/null 2>&1 )
}

install_curl()
{
    chk_installed curl && return 0
    echo 'Install curl'
    local curl_share=${app_root}/share/curl/
    local ca_file=${curl_share}/ca-bundle.crt
    cd "$(dl_dir 'https://curl.haxx.se/download/curl-7.48.0.tar.gz')"
    ${base_conf} --with-ca-bundle=${ca_file}
    make && make install

    mkdir -p ${curl_share}
    curl 'http://curl.haxx.se/ca/cacert.pem' --insecure -Lo ${ca_file}
}


install_git()
{
    chk_installed git && return 0
    echo 'Install git'
    cd "$(dl_dir 'https://www.kernel.org/pub/software/scm/git/git-2.8.1.tar.gz')"
    ${base_conf} --with-curl=${app_root}
    make && make install
}

install_zsh()
{
    chk_installed zsh && return 0
    echo 'Install zsh'
    cd "$(dl_dir 'http://iweb.dl.sourceforge.net/project/zsh/zsh/5.2/zsh-5.2.tar.gz')"
    ${base_conf}
    make && make install
}

install_libevent()
{
    chk_installed '' libevent && return 0
    echo 'Install libevent'
    cd "$(dl_dir 'https://github.com/libevent/libevent/releases/download/release-2.0.22-stable/libevent-2.0.22-stable.tar.gz')"
    ${base_conf}
    make && make install
}

install_tmux()
{
    chk_installed tmux && return 0
    cd "$(dl_dir 'https://github.com/tmux/tmux/releases/download/2.1/tmux-2.1.tar.gz')"
    echo 'Install tmux'
    LIBEVENT_LIBS="${app_root}/lib" LIBEVENT_CFLAGS="-I/home/ymaeda/.apps/include" ${base_conf}
    make && make install
}

install_vim()
{
    chk_installed vim && return 0
    cd "$(dl_dir 'ftp://ftp.ca.vim.org/pub/vim/unix/vim-7.4.tar.bz2')"
    echo 'Install vim'
    ${base_conf} --enable-multibyte  --with-features=huge
    make && make install
}

clear_tmp()
{
    rm -rf ${tmp}/*
}

install_curl
install_git
install_zsh
install_libevent
install_tmux
install_vim

clear_tmp