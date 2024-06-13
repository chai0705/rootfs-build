#!/bin/bash

# 错误处理函数
err_handler()
{
        ret=${1:-$?} # 获取错误码，如果未提供参数，则使用上一个命令的退出状态码
        [ "$ret" -eq 0 ] && return # 如果错误码为零，表示没有错误，直接返回

        echo "ERROR: Running $BASH_SOURCE - ${2:-${FUNCNAME[1]}} failed!" # 输出错误信息，包括脚本文件>路径和失败的函数或命令名称
        echo "ERROR: exit code $ret from line ${BASH_LINENO[0]}:" # 输出错误码和导致错误的行号
        echo "    ${3:-$BASH_COMMAND}" # 输出导致错误的命令或函数调用

        echo "ERROR: call stack:" # 输出调用堆栈信息，即函数调用的层次关系
        for i in $(seq 1 $((${#FUNCNAME[@]} - 1))); do # 遍历函数调用堆栈
                SOURCE="${BASH_SOURCE[$i]}" # 获取调用的脚本文件路径
                LINE=${BASH_LINENO[$(( $i - 1 ))]} # 获取调用发生的行号
                echo "    $(basename "$SOURCE"): ${FUNCNAME[$i]}($LINE)" # 输出调用的脚本文件名、函数名称和行号
        done

        exit $ret # 退出脚本，并返回错误码
}

#  高亮打印
display_alert()
{
	case $3 in
		err)
		echo -e "[\e[0;31m error \x1B[0m] $1"
		;;

		wrn)
		echo -e "[\e[0;35m warn \x1B[0m] $1"
		;;

		ext)
		echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m$1\x1B[0m"
		;;

		info)
		echo -e "[\e[0;32m o.k. \x1B[0m] $1"
		;;

		*)
		echo -e "[\e[0;32m .... \x1B[0m] $1"
		;;
	esac
}


# 安装编译需要的软件包
install_package() {
        HOSTRELEASE=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d"=" -f2)
        echo -e "\e[33m当前运行的系统为$HOSTRELEASE.\e[0m"
        if [ "$HOSTRELEASE" == "focal" ] || [ "$HOSTRELEASE" == "jammy" ]; then
                echo -e "\e[33m安装ubuntu20和ubuntu22编译所需要的依赖包.\e[0m"
                sudo apt-get install -y --no-install-recommends \
				whiptail dialog psmisc acl uuid uuid-runtime curl \
				gpg gnupg gawk git acl aptly aria2 bc binfmt-support bison btrfs-progs \
				build-essential ca-certificates ccache cpio cryptsetup curl \
				debian-archive-keyring debian-keyring debootstrap device-tree-compiler \
				dialog dirmngr dosfstools dwarves f2fs-tools fakeroot flex gawk \
				gcc-arm-linux-gnueabihf gdisk gpg imagemagick jq kmod libbison-dev \
				libc6-dev-armhf-cross libelf-dev libfdt-dev libfile-fcntllock-perl \
				libfl-dev liblz4-tool libncurses-dev libpython2.7-dev libssl-dev \
				libusb-1.0-0-dev linux-base locales lzop ncurses-base ncurses-term \
				nfs-kernel-server ntpdate p7zip-full parted patchutils pigz pixz \
				pkg-config pv python3-dev python3-distutils qemu-user-static rsync swig \
				systemd-container u-boot-tools udev unzip uuid-dev wget whiptail zip \
				zlib1g-dev distcc lib32ncurses-dev lib32stdc++6 libc6-i386 python2 python3 \
				expect expect-dev cmake vim openssh-server net-tools
                echo -e "\e[32mInstall OK.\e[0m"
        elif [ "$HOSTRELEASE" == "noble" ]; then
                echo -e "\e[33m安装ubuntu24编译所需要的依赖包.\e[0m"
                sudo apt-get install -y --no-install-recommends whiptail dialog psmisc acl \
                uuid uuid-runtime curl gpg gnupg gawk git acl aptly aria2 bc binfmt-support \
                bison btrfs-progs build-essential ca-certificates ccache cpio cryptsetup curl \
                debian-archive-keyring debian-keyring debootstrap device-tree-compiler dialog \
                dirmngr dosfstools dwarves f2fs-tools fakeroot flex gawk gcc-arm-linux-gnueabihf \
                gdisk gpg imagemagick jq kmod libbison-dev libc6-dev-armhf-cross libelf-dev libfdt-dev \
                libfile-fcntllock-perl libfl-dev liblz4-tool libncurses-dev  libssl-dev libusb-1.0-0-dev \
                linux-base locales lzop ncurses-base ncurses-term nfs-kernel-server ntpdate p7zip-full parted \
                patchutils pigz pixz pkg-config pv python3-dev  qemu-user-static rsync swig systemd-container \
                u-boot-tools udev unzip uuid-dev wget whiptail zip zlib1g-dev distcc lib32ncurses-dev lib32stdc++6 \
                libc6-i386 python3 expect expect-dev cmake vim openssh-server net-tools
                echo -e "\e[32mInstall OK.\e[0m"
        else
                echo -e "\e[33m您的系统不是ubuntu20 ubuntu22 ubuntu24,请自行安装依赖包.\e[0m"
        fi
}

create_sources_list()
{
	local release=$1
	local chroot_dir=$2
	[[ -z $chroot_dir ]] && display_alert "No chroot_dir passed to create_sources_list" "" "err"

	case $release in
	stretch|buster)
	cat <<-EOF > "${chroot_dir}"/etc/apt/sources.list
	deb https://repo.huaweicloud.com/debian/ $release main contrib non-free
	#deb-src https://repo.huaweicloud.com/debian/ $release main contrib non-free

	deb https://repo.huaweicloud.com/debian/ ${release}-updates main contrib non-free
	#deb-src https://repo.huaweicloud.com/debian/ ${release}-updates main contrib non-free

	deb https://repo.huaweicloud.com/debian/ ${release}-backports main contrib non-free
	#deb-src https://repo.huaweicloud.com/debian/ ${release}-backports main contrib non-free

	deb http://${DEBIAN_SECURTY} ${release}/updates main contrib non-free
	#deb-src http://${DEBIAN_SECURTY} ${release}/updates main contrib non-free
	EOF
	;;

	bullseye)
	cat <<-EOF > "${chroot_dir}"/etc/apt/sources.list
	deb https://repo.huaweicloud.com/debian/ $release main contrib non-free
	#deb-src https://repo.huaweicloud.com/debian/ $release main contrib non-free

	deb https://repo.huaweicloud.com/debian/ ${release}-updates main contrib non-free
	#deb-src https://repo.huaweicloud.com/debian/ ${release}-updates main contrib non-free

	deb https://repo.huaweicloud.com/debian/ ${release}-backports main contrib non-free
	#deb-src https://repo.huaweicloud.com/debian/ ${release}-backports main contrib non-free

	deb https://security.debian.org/debian-security ${release}-security main contrib non-free
	#deb-src https://security.debian.org/debian-security ${release}-security main contrib non-free
	EOF
	;;

	bookworm)
	cat <<- EOF > "${chroot_dir}"/etc/apt/sources.list
	deb https://repo.huaweicloud.com/debian/ $release main contrib non-free non-free-firmware
	#deb-src https://repo.huaweicloud.com/debian/ $release main contrib non-free non-free-firmware

	deb https://repo.huaweicloud.com/debian/ ${release}-updates main contrib non-free non-free-firmware
	#deb-src https://repo.huaweicloud.com/debian/ ${release}-updates main contrib non-free non-free-firmware

	deb https://repo.huaweicloud.com/debian/ ${release}-backports main contrib non-free non-free-firmware
	#deb-src https://repo.huaweicloud.com/debian/ ${release}-backports main contrib non-free non-free-firmware

	deb https://security.debian.org/debian-security ${release}-security main contrib non-free non-free-firmware
	#deb-src https://security.debian.org/debian-security ${release}-security main contrib non-free non-free-firmware
	EOF
	;;

	focal|jammy|noble)
	cat <<-EOF > "${chroot_dir}"/etc/apt/sources.list
	deb https://repo.huaweicloud.com/ubuntu-ports/ $release main restricted universe multiverse
	#deb-src https://repo.huaweicloud.com/ubuntu-ports/ $release main restricted universe multiverse

	deb https://repo.huaweicloud.com/ubuntu-ports/ ${release}-security main restricted universe multiverse
	#deb-src https://repo.huaweicloud.com/ubuntu-ports/ ${release}-security main restricted universe multiverse

	deb https://repo.huaweicloud.com/ubuntu-ports/ ${release}-updates main restricted universe multiverse
	#deb-src https://repo.huaweicloud.com/ubuntu-ports/ ${release}-updates main restricted universe multiverse

	deb https://repo.huaweicloud.com/ubuntu-ports/ ${release}-backports main restricted universe multiverse
	#deb-src https://repo.huaweicloud.com/ubuntu-ports/ ${release}-backports main restricted universe multiverse
	EOF
	;;
	esac
}

create_chroot()
{
	if [[ $BUILD_OPT == "ubuntu20" ]]; then
			release="focal"
			mirror=https://repo.huaweicloud.com/ubuntu-ports/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils,perl-openssl-defaults"
	elif [[ $BUILD_OPT == "ubuntu22" ]]; then
			release="jammy"
			mirror=https://repo.huaweicloud.com/ubuntu-ports/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils"
	elif [[ $BUILD_OPT == "ubuntu24" ]]; then
			release="noble"
			mirror=https://repo.huaweicloud.com/ubuntu-ports/
			includes="locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils"

	elif [[ $BUILD_OPT == "debian11" ]]; then
			release="bullseye"
			mirror=https://repo.huaweicloud.com/debian/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils,perl-openssl-defaults"
	elif [[ $BUILD_OPT == "debian12" ]]; then
			release="bookworm"
			mirror=https://repo.huaweicloud.com/debian/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils,perl-openssl-defaults"
	fi


	# 设置文件系统架构为arm64
	arch=arm64 

	# 设置chroot的目录为binary
	chroot_dir=binary

	# 创建目标目录
	mkdir -p "${chroot_dir}"

	# 将系统设置为非交互模式，否则使用脚本构建文件系统的过程中遇到图形界面交互选择时会出错
	export DEBIAN_FRONTEND=noninteractive

	debootstrap --variant=buildd \
	--components=main,contrib \
	--arch="${arch}" $DEBOOTSTRAP_OPTION \
	--foreign \
	--include="${includes}" "${release}" "${chroot_dir}" "${mirror}"

	# 检查第一阶段 debootstrap 是否成功
	[[ $? -ne 0 || ! -f "${chroot_dir}"/debootstrap/debootstrap ]] && \
	exit_with_error "Create chroot first stage failed" "" "err"

	display_alert "The first stage of debootstrap." "" "info"

	# 复制 QEMU 静态二进制文件到 chroot 环境
	cp /usr/bin/qemu-aarch64-static "${chroot_dir}"/usr/bin/

	# 复制 Debian 密钥环到 chroot 环境
	[[ ! -f "${chroot_dir}"/usr/share/keyrings/debian-archive-keyring.gpg ]] && \
	mkdir -p  "${chroot_dir}"/usr/share/keyrings/ && \
	cp /usr/share/keyrings/debian-archive-keyring.gpg "${chroot_dir}"/usr/share/keyrings/

	# 运行 debootstrap 的第二阶段
	chroot "${chroot_dir}" /bin/bash -c "/debootstrap/debootstrap --second-stage"

	# 检查第二阶段 debootstrap 是否成功
	[[ $? -ne 0 || ! -f "${chroot_dir}"/bin/bash ]] && display_alert "Create chroot second stage failed" "" "err"
	display_alert "The second stage of debootstrap." "" "info"

	create_sources_list ${release} ${chroot_dir}

	# 禁用 APT 的推荐和建议包安装
	cat <<-EOF > "${chroot_dir}"/etc/apt/apt.conf.d/71-no-recommends
	APT::Install-Recommends "0";
	APT::Install-Suggests "0";
	EOF

	# 设置 locale 为 en_US.UTF-8
	[[ -f "${chroot_dir}"/etc/locale.gen ]] && \
	sed -i "s/^# en_US.UTF-8/en_US.UTF-8/" "${chroot_dir}"/etc/locale.gen
	chroot "${chroot_dir}" /bin/bash -c "locale-gen; update-locale LANG=en_US:en LC_ALL=en_US.UTF-8"

	# 禁用 policy-rc.d 脚本, 防止安装过程中服务自动启动
	printf '#!/bin/sh\nexit 101' > "${chroot_dir}"/usr/sbin/policy-rc.d
	chmod 755 "${chroot_dir}"/usr/sbin/policy-rc.d

	# 设置 resolv.conf 和 hosts 文件
	rm "${chroot_dir}"/etc/resolv.conf 2>/dev/null
	echo "nameserver 114.114.114.114" > "${chroot_dir}"/etc/resolv.conf
	echo "nameserver 8.8.8.8" > "${chroot_dir}"/etc/resolv.conf
	rm "${chroot_dir}"/etc/hosts 2>/dev/null
	echo "127.0.0.1 localhost" > "${chroot_dir}"/etc/hosts

	# 删掉锁
	if [[ -L "${chroot_dir}"/var/lock ]]; then
			rm -rf "${chroot_dir}"/var/lock 2>/dev/null
			mkdir -p "${chroot_dir}"/var/lock
	fi


	# 更新 ccache 符号链接
	chroot "${chroot_dir}" /bin/bash -c "/usr/sbin/update-ccache-symlinks"

	# 升级 chroot 环境中的软件包
	display_alert "Upgrading packages in" "${chroot_dir}" "info"
	chroot "${chroot_dir}" /bin/bash -c "apt-get -q update; apt-get -q -y upgrade; apt-get clean"
	date +%s >"$chroot_dir/root/.update-timestamp"

	# 针对某些发行版安装 python-is-python3 包
	case $release in
			bullseye|focal|bookworm)
			chroot "${chroot_dir}" /bin/bash -c "apt-get install python-is-python3"
	;;
	esac

}
