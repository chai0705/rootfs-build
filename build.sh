#!/bin/bash

# 在发生错误时调用名为 err_handler 的函数来处理错误，并启用错误处理机制
trap 'err_handler' ERR
set -eE

# 获取build.sh所在路径
SRC="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# 导入一些要用的函数
source $(dirname "$(realpath "$BASH_SOURCE")")/scripts/general.sh

# 判断是否拥有root权限
if [[ "${EUID}" == "0" ]]; then
	:
else
	display_alert "This script requires root privileges, trying to use sudo" "" "wrn"
	sudo "${SRC}/build.sh"
	exit $?
fi

# 检查是否第一次运行,如果是第一次运行将安装一些需要的依赖、设置python脚本和交换分区
if [ ! -f "/tmp/script_run_flag" ]; then
    # 如果是第一次运行,则获取 sudo 权限
    echo -e "\e[31m这是第一次运行脚本，请输入您的用户密码.\e[0m"
    install_package
    # 创建一个标志文件,表示脚本已经运行过一次
    touch "/tmp/script_run_flag"
fi

# 如果输入的参数为空，则进入图形界面，否则为命令行编译
titlestr="Choose an option"
backtitle="iTOP building script, http://www.topeet.com"
menustr="Compile image | uboot | kernel | rootfs | recovery | all | firmware |updateimg | cleanall"
TTY_X=$(($(stty size | awk '{print $2}')-6))                    # determine terminal width
TTY_Y=$(($(stty size | awk '{print $1}')-6))                    # determine terminal height

if [[ -z $BOARD ]]; then

        options+=("rk3562" "iTOP-RK3562")
        options+=("rk3568" "iTOP-RK3568")
        options+=("rk3588" "iTOP-RK3588")
        options+=("rk3588" "iTOP-RK3588S")

        BOARD=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
                                                        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
                                                        --cancel-button Exit --ok-button Select "${options[@]}" \
                                                        3>&1 1>&2 2>&3)
        unset options
fi

if [[ -z $BUILD_OPT ]]; then

        options+=("ubuntu20" "ubuntu20")
        options+=("ubuntu22" "ubuntu22")
        options+=("ubuntu24" "ubuntu24")
        options+=("debian11" "debian11")
        options+=("debian12" "debian12")

        BUILD_OPT=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
                                                        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
                                                        --cancel-button Exit --ok-button Select "${options[@]}" \
                                                        3>&1 1>&2 2>&3)
        unset options
fi

if [[ -z $BUILD_DESKTOP ]]; then

        options+=("xserver" "xserver")
        options+=("desktop" "desktop")

        BUILD_DESKTOP=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
                                                        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
                                                        --cancel-button Exit --ok-button Select "${options[@]}" \
                                                        3>&1 1>&2 2>&3)
        unset options
fi

if [[ $BUILD_DESKTOP == "desktop" ]] && [[ -z $DESKTOP_OPTION ]]; then

        options+=("xfce" "xfce")
        options+=("gnome" "gnome")

        DESKTOP_OPTION=$(whiptail --title "${titlestr}" --backtitle "${backtitle}" --notags \
                                                        --menu "${menustr}" "${TTY_Y}" "${TTY_X}" $((TTY_Y - 8))  \
                                                        --cancel-button Exit --ok-button Select "${options[@]}" \
                                                        3>&1 1>&2 2>&3)
        unset options
fi

# 将系统设置为非交互模式，否则使用脚本构建文件系统的过程中遇到图形界面交互选择时会出错
export DEBIAN_FRONTEND=noninteractive

# 设置基本变量
set_option

# 创建基础镜像
# create_chroot

# 安装基本软件
install_server_deb

# 设置基础用户信息
set_user
if [[ $BUILD_DESKTOP == "desktop" ]]; then
        install_desktop_deb
fi

# 安装deb包
# dpkg_install_debs_chroot 