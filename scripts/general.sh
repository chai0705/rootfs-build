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

set_option()
{
	if [[ $BUILD_OPT == "ubuntu20" ]]; then
			release="focal"
			mirror=https://repo.huaweicloud.com/ubuntu-ports/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils,perl-openssl-defaults"
			components='main,universe,multiverse'
	elif [[ $BUILD_OPT == "ubuntu22" ]]; then
			release="jammy"
			mirror=https://repo.huaweicloud.com/ubuntu-ports/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils,perl-openssl-defaults"
			components='main,universe,multiverse'
	elif [[ $BUILD_OPT == "ubuntu24" ]]; then
			release="noble"
			mirror=https://repo.huaweicloud.com/ubuntu-ports/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils,perl-openssl-defaults"
			components='main,universe,multiverse'
	elif [[ $BUILD_OPT == "debian11" ]]; then
			release="bullseye"
			mirror=https://repo.huaweicloud.com/debian/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils,perl-openssl-defaults"
			components='main,contrib'
	elif [[ $BUILD_OPT == "debian12" ]]; then
			release="bookworm"
			mirror=https://repo.huaweicloud.com/debian/
			includes="ccache,locales,git,ca-certificates,devscripts,libfile-fcntllock-perl,debhelper,rsync,python3,apt-utils,perl-openssl-defaults"
			components='main,contrib'
	fi

	# 设置文件系统架构为arm64
	arch=arm64 

	# 设置chroot的目录为binary
	chroot_dir=binary

	# 设置deb包路径
	ROOT=$PWD
	packages=$PWD/packages

	# 创建目标目录
	cd build
	mkdir -p "${chroot_dir}"
}

create_chroot()
{
	debootstrap --variant=buildd \
	--components="${components}"\
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
	echo "nameserver 8.8.8.8" >> "${chroot_dir}"/etc/resolv.conf
	rm "${chroot_dir}"/etc/hosts 2>/dev/null
	echo "127.0.0.1 localhost" > "${chroot_dir}"/etc/hosts

	echo "topeet" > "${chroot_dir}"/etc/hostname

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

install_server_deb()
{
	chroot "${chroot_dir}" /bin/bash -c "apt-get -y install dmidecode mtd-utils i2c-tools u-boot-tools \
	bash-completion man-db manpages nano gnupg initramfs-tools sudo \
	dosfstools mtools parted ntfs-3g zip atop \
	p7zip-full htop iotop pciutils lshw lsof exfat-fuse hwinfo \
	net-tools wireless-tools openssh-client openssh-server wpasupplicant ifupdown \
	pigz wget curl lm-sensors bluez gdisk usb-modeswitch usb-modeswitch-data make \
	gcc libc6-dev bison libssl-dev flex  fake-hwclock rfkill wireless-regdb toilet cmake locales \
	openssh-server openssh-client network-manager fonts-wqy-zenhei xfonts-intl-chinese alsa-utils vim language-pack-zh-hans ntp busybox"
}

set_user()
{
cat << EOF | chroot ${chroot_dir} /bin/bash
	echo -e "\033[36m ......................add topeet and passwd root........................... \033[0m"    
	# 添加topeet用户
	adduser topeet --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password

	# 设置topeet用户的密码为topeet
	echo "topeet:topeet" |  chpasswd

	# 授予topeet用户管理员权限
	echo "topeet ALL=(ALL:ALL) ALL" >> /etc/sudoers
	sed -i -e '/\%sudo/ c \%sudo ALL=(ALL) NOPASSWD: ALL' /etc/sudoers

	# 设置root用户的密码为topeet
	echo "root:topeet" | chpasswd
EOF

cat << EOF | chroot ${chroot_dir} /bin/bash
	echo -e "\033[36m ...........................beautiful terminal........................... \033[0m"      
	echo " alias ls='ls --color' " >>/root/.bashrc
	echo " alias ls='ls --color' " >>/home/topeet/.bashrc
	echo " export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:'" >>/root/.bashrc            
	echo "export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:'" >>/home/topeet/.bashrc
EOF

display_alert "set default config." "" "info"
mkdir -p ${chroot_dir}/packages
cp $packages/common/topeet-config.deb ${chroot_dir}/packages
chroot "${chroot_dir}" /bin/bash -c "dpkg -x /packages/topeet-config.deb ."
rm -rf ${chroot_dir}/packages/topeet-config.deb
}

install_desktop()
{
	if [[ $BUILD_OPT == "ubuntu20" ]]; then
		echo -e "\033[36m install xfce \033[0m"
		chroot "${chroot_dir}" /bin/bash -c "apt-get install -fy xubuntu-core qt5-default blueman"
	elif [[ $BUILD_OPT == "ubuntu22" ]]; then
		echo -e "\033[36m install xfce \033[0m"
		chroot "${chroot_dir}" /bin/bash -c "apt-get install -fy xubuntu-core blueman"
	elif [[ $BUILD_OPT == "ubuntu24" ]]; then
		echo -e "\033[36m install xfce \033[0m"
		chroot "${chroot_dir}" /bin/bash -c "apt-get install -fy xubuntu-core blueman"
	elif [[ $BUILD_OPT == "debian11" ]]; then
		echo -e "\033[36m install xfce \033[0m"
		chroot "${chroot_dir}" /bin/bash -c "apt-get install -fy task-xfce-desktop blueman"
	elif [[ $BUILD_OPT == "debian12" ]]; then
		echo -e "\033[36m install xfce \033[0m"
		chroot "${chroot_dir}" /bin/bash -c "apt-get install -fy task-xfce-desktop blueman"
	fi
}

choose_debs()
{
	cp -rf $packages/common/libjpeg62-turbo_1.5.1-2_arm64.deb ${chroot_dir}/packages 
	chroot "${chroot_dir}" /bin/bash -c "dpkg -i /packages/libjpeg62-turbo_1.5.1-2_arm64.deb"
	if [[ $BOARD == "rk3562" ]]; then
		chroot "${chroot_dir}" /bin/bash -c "echo 'toilet -f standard -F metal iTOP-RK3562' >>  /etc/update-motd.d/10-topeet-logo"	
		cp -rf $packages/$BOARD/common/* ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/libdrm-cursor ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/mpp ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/libv4l ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/glmark2 ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/ffmpeg ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/xserver ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/mpv ${chroot_dir}/packages 
	elif [[ $BOARD == "rk3568" ]]; then
		chroot "${chroot_dir}" /bin/bash -c "echo 'toilet -f standard -F metal iTOP-RK3568' >>  /etc/update-motd.d/10-topeet-logo"	
		cp -rf $packages/$BOARD/common/* ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/libdrm-cursor ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/mpp ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/libv4l ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/glmark2 ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/ffmpeg ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/xserver ${chroot_dir}/packages 
		cp -rf $packages/$BOARD/$BUILD_OPT/mpv ${chroot_dir}/packages 
	elif [[ $BOARD == "rk3588" ]]; then
		chroot "${chroot_dir}" /bin/bash -c "echo 'toilet -f standard -F metal iTOP-RK3588' >>  /etc/update-motd.d/10-topeet-logo"	
		if [[ $DESKTOP_OPTION == "gnome" ]] ; then	
			cp -rf $packages/$BOARD/common/* ${chroot_dir}/packages 	
			cp -rf $packages/$BOARD/ubuntu22_gnome/mpp ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_gnome/libv4l ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_gnome/glmark2 ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_gnome/ffmpeg ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_gnome/mesa ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_gnome/mpv ${chroot_dir}/packages 
		elif [[ $DESKTOP_OPTION == "xfce" ]] && [[ $BUILD_OPT == "ubuntu22" ]] ; then
			cp -rf $packages/$BOARD/common/* ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_xfce/mpp ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_xfce/libv4l ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_xfce/glmark2 ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_xfce/ffmpeg ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_xfce/xserver ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/ubuntu22_xfce/mpv ${chroot_dir}/packages 
		else
			cp -rf $packages/$BOARD/common/* ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/$BUILD_OPT/mpp ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/$BUILD_OPT/libv4l ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/$BUILD_OPT/glmark2 ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/$BUILD_OPT/ffmpeg ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/$BUILD_OPT/xserver ${chroot_dir}/packages 
			cp -rf $packages/$BOARD/$BUILD_OPT/mpv ${chroot_dir}/packages 
		fi
	fi
}

dpkg_install_debs_chroot()
{
	mount -t proc /proc ${chroot_dir}/proc
	mount -t sysfs /sys ${chroot_dir}/sys
	mount -o bind /dev ${chroot_dir}/dev
	mount -o bind /dev/pts ${chroot_dir}/dev/pts

    # 参数: $1 - 软件包目录路径
    local deb_dir="binary/packages/"
    local unsatisfied_dependencies=()
    local package_names=()
    local package_dependencies=()
	
    # 如果目录不存在，返回
    [ ! -d "$deb_dir" ] && return

    # 获取目录中所有 .deb 软件包
    deb_packages=($(find "${deb_dir}/" -mindepth 1 -maxdepth 2 -type f -name "*.deb"))

    # 辅助函数，检查数组中是否包含指定元素
    find_in_array() {
        local target="$1"
        local element=""
        shift
        for element in "$@"; do
            [[ "$element" == "$target" ]] && return 0
        done
        return 1
    }

    # 遍历所有软件包
    for package in "${deb_packages[@]}"; do
        # 获取软件包名称
        package_names+=($(dpkg-deb -f "$package" Package))

        # 解析软件包依赖
        dep_str=$(dpkg-deb -I "${package}" | grep 'Depends' | sed 's/.*: //' | sed 's/ //g' | sed 's/([^)]*)//g')
        IFS=',' read -ra dep_array <<< "$dep_str"
        # 添加未满足的依赖到列表
        if [[ ! ${#dep_array[@]} -eq 0 ]]; then
            for element in "${dep_array[@]}"; do
                if [[ $element == *"|"* ]]; then
                    :
                else
                    if ! find_in_array "$element" "${package_dependencies[@]}"; then
                        package_dependencies+=("${element}")
                    fi
                fi
            done
        fi
    done
	 
    # 安装未满足的依赖
    for dependency in "${package_dependencies[@]}"; do
        if ! chroot "${chroot_dir}" /bin/bash -c "dpkg-query -W --showformat='\${Status}' ${dependency} \
            | grep -q 'ok installed'" &>/dev/null; then

            all=("${package_names[@]}" "${unsatisfied_dependencies[@]}")

            if ! find_in_array "$dependency" "${all[@]}"; then
                unsatisfied_dependencies+=("$dependency")
            fi
        fi
    done

    if [[ ! -z "${unsatisfied_dependencies[*]}" ]]; then
        display_alert "Installing Dependencies" "${unsatisfied_dependencies[*]}"
        chroot $chroot_dir /bin/bash -c "apt-get install -fy --allow-downgrades ${unsatisfied_dependencies[*]}" 
    fi
	local names=""
	for package in "${deb_packages[@]}"; do
		name="/"$(basename "${package}")
		names+=($name)
		[[ ! -f "${chroot_dir}${name}" ]] && cp "${package}" "${chroot_dir}${name}"
	done

	if [[ ! -z "${names[*]}" ]]; then
		display_alert "Installing" "$(basename $deb_dir)"

		# when building in bulk from remote, lets make sure we have up2date index
		chroot "${chroot_dir}" /bin/bash -c "dpkg -i ${names[*]} "
		chroot "${chroot_dir}" /bin/bash -c "apt-mark hold ${package_names[*]}"
		chroot "${chroot_dir}" /bin/bash -c "rm -rf /*deb"
	fi

	chroot "${chroot_dir}" /bin/bash -c "apt-get clean"

	# 解除临时文件系统的挂载
	umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
	umount -lf ${chroot_dir}/* 2> /dev/null || true
}

after_config()
{
	if [[ $BOARD == "rk3588" ]] && [[ $DESKTOP_OPTION != "gnome" ]] ; then
		cp -rf $packages/$BOARD/common/libmali/mali_csffw.bin ${chroot_dir}/usr/lib/firmware/
	fi

	display_alert "set default config." "" "info"
	cp $packages/common/topeet-config.deb ${chroot_dir}/
	chroot "${chroot_dir}" /bin/bash -c "dpkg -x /topeet-config.deb /"
	rm -rf ${chroot_dir}/topeet-config.deb

	display_alert "set desktop default config." "" "info"
	cp $packages/common/topeet-desktop-config.deb ${chroot_dir}/
	chroot "${chroot_dir}" /bin/bash -c "dpkg -x /topeet-desktop-config.deb /"
	rm -rf ${chroot_dir}/topeet-desktop-config.deb
}