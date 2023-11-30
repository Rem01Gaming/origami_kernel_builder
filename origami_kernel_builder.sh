#!/usr/bin/bash
# Origami Kernel Builder
# Version 1.1
# Copyright (c) 2023-2024 Rem01 Gaming <Rem01_Gaming@proton.me>
#
#			GNU GENERAL PUBLIC LICENSE
#			 Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

# Define some things
# Kernel common
export ARCH=arm64
export DEFCONFIG=even_defconfig
export localversion=-X1.6
export LINKER="ld.lld"
# Telegram API
export SEND_TO_TG=1
export chat_id=""
export token=""
# Telegram && Output
export kver="Beta"
export CODENAME="even"
export DEVICE="Realme C25 and Narzo50A (${CODENAME})"
export BUILDER="Rem01"
export BUILD_HOST="DigitalOcean"
export TIMESTAMP=$(date +"%Y%m%d")-$(date +"%H%M%S")
export KBUILD_COMPILER_STRING=$(./clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
export FW="RUI2"
export zipn="Liquid-${CODENAME}-${FW}-${TIMESTAMP}"
# Needed by script
export PATH="${PWD}/clang/bin:${PATH}"
PROCS=$(nproc --all)

# Text coloring
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

# Check permission
script_permissions=$(stat -c %a "$0")
if [ "$script_permissions" -lt 777 ]; then
    echo -e "${RED}error:${NOCOLOR} Don't have enough permission"
    echo "run 'chmod 0777 origami_kernel_builder.sh' and rerun"
    exit 126
fi

# Check requirements
if ! hash make curl bc 2>/dev/null; then
        echo -e "${RED}error:${NOCOLOR} Environment has missing dependencies"
        echo "Install make, curl, and bc !"
        exit 127
fi

if [ ! -d "${PWD}/clang" ]; then
    echo "/clang not found!"
    echo "have you clone the clang?"
    exit 2
fi


if [ ! -d "${PWD}/anykernel" ]; then
    echo "/anykernel not found!"
    echo "have you clone the anykernel?"
    exit 2
fi

help_msg() {
    echo "Usage: bash origami_kernel_builder.sh --choose=[Function]"
    echo ""
    echo "Some functions on Origami Kernel Builder:"
    echo "1. Build a whole Kernel"
    echo "2. Regenerate defconfig"
    echo "3. Open menuconfig"
    echo "4. Clean"
    echo ""
    echo "Place this script inside the Kernel Tree."
}

send_msg_telegram() {
    case "$1" in
    1) curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
                -d chat_id="$chat_id" \
                -d "disable_web_page_preview=true" \
                -d "parse_mode=html" \
                -d text="<b>~~~ ORIGAMI CI ~~~</b>
<b>Build Started on ${BUILD_HOST}</b>
<b>Build status</b>: <code>${kver}</code>
<b>Builder</b>: <code>${BUILDER}</code>
<b>Device</b>: <code>${DEVICE}</code>
<b>Kernel Version</b>: <code>$(make kernelversion 2>/dev/null)</code>
<b>Date</b>: <code>$(date)</code>
<b>Zip Name</b>: <code>${zipn}</code>
<b>Defconfig</b>: <code>${DEFCONFIG}</code>
<b>Compiler</b>: <code>${KBUILD_COMPILER_STRING}</code>
<b>Branch</b>: <code>$(git rev-parse --abbrev-ref HEAD)</code>
<b>Last Commit</b>: <code>$(git log --format="%s" -n 1): $(git log --format="%h" -n 1)</code>" \
                -o /dev/null
        ;;
    2) curl -s -F document=@./out/build.log "https://api.telegram.org/bot$token/sendDocument" \
                -F chat_id="$chat_id" \
                -F "disable_web_page_preview=true" \
                -F "parse_mode=html" \
                -F caption="Build failed after ${minutes} minutes and ${seconds} seconds." \
                -o /dev/null
        ;;
    3) curl -s -F document=@./out/target/"${zipn}".zip "https://api.telegram.org/bot$token/sendDocument" \
                -F chat_id="$chat_id" \
                -F "disable_web_page_preview=true" \
                -F "parse_mode=html" \
                -F caption="Build took ${minutes} minutes and ${seconds} seconds.
<b>SHA512</b>: <code>${checksum}</code>" \
                -o /dev/null

        curl -s -F document=@./out/build.log "https://api.telegram.org/bot$token/sendDocument" \
                -F chat_id="$chat_id" \
                -F "disable_web_page_preview=true" \
                -F "parse_mode=html" \
                -F caption="Build log" \
                -o /dev/null
        ;;
    esac
}

compile_kernel() {
    rm ./out/arch/${ARCH}/boot/Image.gz-dtb 2>/dev/null

    export KBUILD_BUILD_USER=${BUILDER}
    export KBUILD_BUILD_HOST=${BUILD_HOST}
    export LOCALVERSION=${localversion}

    make O=out ARCH=${ARCH} ${DEFCONFIG}

    START=$(date +"%s")

    make -j"$PROCS" O=out \
        ARCH=${ARCH} \
        LD="${LINKER}" \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CC="clang" \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabihf- \
        CONFIG_NO_ERROR_ON_MISMATCH=y \
        CONFIG_DEBUG_SECTION_MISMATCH=y \
        V=0 2>&1 | tee out/build.log

    END=$(date +"%s")
    DIFF=$((END - START))
    export minutes=$((DIFF / 60))
    export seconds=$((DIFF % 60))
}

zip_kernel() {
    # Move kernel image to anykernel zip
    cp ./out/arch/${ARCH}/boot/Image.gz-dtb ./anykernel

    # Zip the kernel
    zip -r9 ./anykernel/"${zipn}".zip ./anykernel/* -x .git README.md *placeholder

    # Generate checksum of kernel zip
    export checksum=$(sha512sum ./anykernel/"${zipn}".zip | cut -f1 -d ' ')

    # Move the kernel zip to ./out/target
    if [ ! -d "./out/target" ]; then
        mkdir ../out/target
    fi
    rm -f ./anykernel/Image.gz-dtb
    mv ./anykernel/${zipn}.zip ./out/target
}

build_kernel() {
    echo "================================="
    echo "Build Started on ${BUILD_HOST}"
    echo "Build status: ${kver}"
    echo "Builder: ${BUILDER}"
    echo "Device: ${DEVICE}"
    echo "Kernel Version: $(make kernelversion 2>/dev/null)"
    echo "Date: $(date)"
    echo "Zip Name: ${zipn}"
    echo "Defconfig: ${DEFCONFIG}"
    echo "Compiler: ${KBUILD_COMPILER_STRING}"
    echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
    echo "Last Commit: $(git log --format="%s" -n 1): $(git log --format="%h" -n 1)"
    echo "================================="

    if [ "$SEND_TO_TG" -eq 1 ]; then
        send_msg_telegram 1
    fi

    compile_kernel

    if [ ! -f "./out/arch/${ARCH}/boot/Image.gz-dtb" ]; then
        if [ "$SEND_TO_TG" -eq 1 ]; then
            send_msg_telegram 2
        fi
        echo "================================="
        echo -e "${RED}Build failed${NOCOLOR} after ${minutes} minutes and ${seconds} seconds"
        echo "See build log for troubleshooting."
        echo "================================="
        exit 1
    fi

    zip_kernel

    echo "================================="
    echo "Build took ${minutes} minutes and ${seconds} seconds."
    echo "SHA512: ${checksum}"
    echo "================================="

    if [ "$SEND_TO_TG" -eq 1 ]; then
        send_msg_telegram 3
    fi
}

regen_defconfig() {
make O=out ARCH=${ARCH} ${DEFCONFIG}
cp -rf ./out/.config ./arch/${ARCH}/config/${DEFCONFIG}
}

open_menuconfig() {
make O=out ARCH=${ARCH} ${DEFCONFIG}
echo -e "Note: Make sure you save the config with name '.config'"
echo -e "      else the defconfig will not saved automatically."
local count=8
while [ $count -gt 0 ]; do
    echo -ne -e "${LIGHTCYAN}menuconfig will be opened in $count seconds... \r${NOCOLOR}"
    sleep 1
    ((count--))
done
make O=out menuconfig
cp -rf ./out/.config ./arch/${ARCH}/config/${DEFCONFIG}
}

execute_operation() {

   loop_helper() {
      read -p "Press enter to continue or type 0 for Quit: " a1

      if [[ "$a1" == "0" ]]; then
          exit 0
      else
          clear
          bash "$0"
      fi
   }

   case "$1" in
        1) clear
            build_kernel
            loop_helper
            ;;
        2) clear
            regen_defconfig
            loop_helper
             ;;
        3) clear
             open_menuconfig
             loop_helper
             ;;
        4) clear
            make clean && make mrproper
            loop_helper
            ;;
        5) exit 0 ;;
        6) help_msg ;;
        *) echo -e "${RED}error:${NOCOLOR} Invalid selection." && exit 1 ;;
    esac
}

if [ $# -eq 0 ]; then
    clear
    echo "What do you want to do today?"
    echo ""
    echo "1. Build a whole Kernel"
    echo "2. Regenerate defconfig"
    echo "3. Open menuconfig"
    echo "4. Clean"
    echo "5. Quit"
    echo ""
    read -p "Choice the number: " choice
else
    case "$1" in
        --choose=1)
            choice=1
            ;;
        --choose=2)
            choice=2
            ;;
        --choose=3)
            choice=3
            ;;
        --choose=4)
            choice=4
            ;;
        --help)
            choice=6
            ;;
        *)
            echo -e "${RED}error:${NOCOLOR} Not a valid argument"
            echo "Try 'bash origami_kernel_builder.sh --help' for more information."
            exit 1
            ;;
    esac
fi

# Main script logic
execute_operation "$choice"
