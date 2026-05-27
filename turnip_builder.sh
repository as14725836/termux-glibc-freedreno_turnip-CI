#!/bin/bash -e

#Define variables
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'
deps="git meson ninja patchelf unzip curl pip flex bison zip glslang glslangValidator"
workdir="$(pwd)/turnip_workdir"
mesasrc="https://github.com/whitebelyash/mesa-unified"
srcfolder="mesa"

clear

run_all(){
	echo "====== Begin building TU V$BUILD_VERSION! ======"
	check_deps
	prepare_workdir
	build_lib_for_linux turnip/gen8 turnip-gen8
}

check_deps(){
	echo "Checking system for required Dependencies ..."
		for deps_chk in $deps;
			do
				sleep 0.25
				if command -v "$deps_chk" >/dev/null 2>&1 ; then
					echo -e "$green - $deps_chk found $nocolor"
				else
					echo -e "$red - $deps_chk not found, can't countinue. $nocolor"
					deps_missing=1
				fi;
			done

		if [ "$deps_missing" == "1" ]
			then echo "Please install missing dependencies" && exit 1
		fi

	echo "Installing python Mako dependency (if missing) ..." $'\n'
	pip install mako &> /dev/null
}

prepare_workdir(){
	echo "Preparing work directory ..." $'\n'
	mkdir -p "$workdir" && cd "$_"

	echo "Downloading mesa source ..." $'\n'
	git clone $mesasrc --depth=1 --no-single-branch $srcfolder
	cd $srcfolder
}

build_lib_for_linux(){
	echo "==== Building Mesa on $1 branch ===="
	
	# 切换分支逻辑（从原脚本搬过来）
	echo "Switching to branch: origin/$1"
	git checkout --force origin/$1
	
	# 获取当前 commit hash 用于版本信息
	GITHASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
	echo "Current commit: $GITHASH"
	
	echo "Pushing TU_VERSION..."
	echo "#define TUGEN8_DRV_VERSION \"v$BUILD_VERSION\"" > ./src/freedreno/vulkan/tu_version.h

	echo "Generating build files for Linux ..." $'\n'
	meson setup build-linux \
		--prefix=/tmp/turnip-$2 \
		--libdir=lib \
		-Dbuildtype=release \
		-Dplatforms=x11 \
		-Dstrip=true \
		-Dgallium-drivers= \
		-Dvulkan-drivers=freedreno \
		-Dvulkan-beta=true \
		-Dfreedreno-kmds=kgsl \
		-Degl=disabled \
		--reconfigure

	echo "Compiling build files ..." $'\n'
	ninja -C build-linux install

	if ! [ -a /tmp/turnip-$2/lib/libvulkan_freedreno.so ]; then
		echo -e "$red Build failed! $nocolor" && exit 1
	fi

	echo "Making the archive"
	cd /tmp/turnip-$2/lib
	zip /tmp/a8xx-$2-V$BUILD_VERSION.zip libvulkan_freedreno.so
	cd -
	
	if ! [ -a /tmp/a8xx-$2-V$BUILD_VERSION.zip ]; then
		echo -e "$red Failed to pack the archive! $nocolor"
	else
		echo -e "$green Archive created: /tmp/a8xx-$2-V$BUILD_VERSION.zip $nocolor"
	fi
}

run_all
