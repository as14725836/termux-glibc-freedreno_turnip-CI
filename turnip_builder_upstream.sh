#!/bin/bash -e

#Define variables
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'
deps="git meson ninja patchelf unzip curl pip flex bison zip glslang glslangValidator"
workdir="$(pwd)/turnip_workdir"
mesasrc="https://gitlab.freedesktop.org/mesa/mesa"
srcfolder="mesa"

clear

run_all(){
	echo "====== Begin building TU V$BUILD_VERSION! ======"
	check_deps
	prepare_workdir
	build_lib_for_linux main tu8_kgsl.patch   # 改为 turnip/gen8
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
	# 注意：改为克隆所有分支，以便切换到 turnip/gen8
	git clone $mesasrc --depth=1 --no-single-branch $srcfolder
	cd $srcfolder
}

build_lib_for_linux(){
	echo "==== Building Mesa on $1 branch ===="
	
	# 切换到指定分支
	echo "Switching to branch: mian/$1"
	git checkout --force mian/$1 || {
		echo -e "$red Failed to checkout branch $1 $nocolor"
		exit 1
	}
	
	echo "Applying patches... ($2)"
	wget https://github.com/whitebelyash/mesa-tu8/releases/download/patchset-head-v2/$2
	if ! git apply --check $2; then
		echo "Failed to apply $2!"
		exit 1
	fi
	git apply $2
	GITHASH=$(git rev-parse --short HEAD)

	echo "Generating build files for Linux ..." $'\n'
	meson setup build-linux \
		--prefix /tmp/turnip-$1 \
		--libdir=lib \
		-Dbuildtype=release \
		-Dstrip=true \
		-Dplatforms=x11,wayland \
		-Dgallium-drivers= \
		-Dvulkan-drivers=freedreno \
		-Dvulkan-beta=true \
		-Dfreedreno-kmds=kgsl \
		-Degl=disabled \
		--reconfigure

	echo "Compiling build files ..." $'\n'
	ninja -C build-linux install

	if ! [ -a /tmp/turnip-$1/lib/libvulkan_freedreno.so ]; then
		echo -e "$red Build failed! $nocolor" && exit 1
	fi

	echo "Making the archive"
	cd /tmp/turnip-$1/lib
	zip /tmp/mesa-turnip-$1-V$BUILD_VERSION.zip libvulkan_freedreno.so
	cd -

	if ! [ -a /tmp/mesa-turnip-$1-V$BUILD_VERSION.zip ]; then
		echo -e "$red Failed to pack the archive! $nocolor"
	else
		echo -e "$green Archive created successfully: /tmp/mesa-turnip-$1-V$BUILD_VERSION.zip $nocolor"
	fi
}

run_all
