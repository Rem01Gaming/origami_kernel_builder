#!/usr/bin/bash
# Origami Kernel Builder
# Version 1.0
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
ARCH=arm64
DEFCONFIG=even_defconfig
localversion=-X1.6
LINKER="ld.lld"
USE_LLVM=0
# Telegram API
SEND_TO_TG=1
export chat_id=""
export token=""
# Telegram && Output
export kver="Beta"
export CODENAME="even"
export DEVICE="Realme C25 and Narzo50A (${CODENAME})"
export BUILDER="Rem01"
export BUILD_HOST="DigitalOcean"
TIMESTAMP=$(date +"%Y%m%d")
export TIMESTAMP
KBUILD_COMPILER_STRING=$(./clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
export KBUILD_COMPILER_STRING
export FW="RUI2"
export random_num=${RANDOM}
export zipn="Liquid-${CODENAME}-${FW}-${TIMESTAMP}-${random_num}"
# Needed by script
PROCS=$(nproc --all)

# Check permission
script_permissions=$(stat -c %a "$0")

if [ "$script_permissions" -lt 777 ]; then
    echo "error: don't have enough permission!"
    echo "run 'chmod 0777 origami_kernel_builder.sh' and rerun"
    exit 126
fi

# Check requirements
if ! hash make curl bc 2>/dev/null; then
        echo "Install make, curl, and bc !"
        exit 127
    fi

# Check the compiller and anykernel
if [ ! -d "${PWD}/clang" ]; then
       echo "/clang not found!"
       echo "have you clone the clang?"
       exit 2
    fi

if [ ! -d "${PWD}/arm-gcc" ]; then
       echo "/arm-gcc not found!"
       echo "have you clone the arm-gcc?"
       exit 2
    fi

if [ ! -d "${PWD}/aarch64-gcc" ]; then
       echo "/aarch64-gcc not found!"
       echo "have you clone the aarch64-gcc?"
       exit 2
    fi

if [ ! -d "${PWD}/anykernel3" ]; then
       echo "/anykernel3 not found!"
       echo "have you clone the anykernel3?"
       exit 2
    fi

# A function to exit on SIGINT and INT TERM.
exit_on_signal_INTR() {
    echo "Got interrupt signal, Aborting..."
    make clean && make mrproper
    if [ "$SEND_TO_TG" -eq 1 ]; then
            curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
            -d chat_id="$chat_id" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="Got interrupt signal, exited with error status 130."
        fi
    exit 130
}
trap exit_on_signal_INTR SIGINT INT TERM

#### Main script ####
execute_operation() {
    case "$1" in
        1)
            clear
            echo "Building kernel..."
            
            if [ "$SEND_TO_TG" -eq 1 ]; then
            curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
            -d chat_id="$chat_id" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="
<b>~~~ ORIGAMI CI ~~~</b>
<b>Build Started on ${BUILD_HOST}</b>
<b>Build status</b>: <code>${kver}</code>
<b>Builder</b>: <code>${BUILDER}</code>
<b>Device</b>: <code>${DEVICE}</code>
<b>Kernel Version</b>: <code>$(make kernelversion 2>/dev/null)</code>
<b>Date</b>: <code>$(date)</code>
<b>Zip Name</b>: <code>${zipn}</code>
<b>Defconfig</b>: <code>${DEFCONFIG}</code>
<b>Compiler</b>: ${KBUILD_COMPILER_STRING}
<b>Branch</b>: $(git rev-parse --abbrev-ref HEAD)
<b>Last Commit</b>: $(git log --pretty=format:'"%h : %s"' -1)
"
        fi

            rm ./out/arch/${ARCH}/boot/Image.gz
            rm ./out/arch/${ARCH}/boot/Image.gz-dtb
            
            if [ ! -f "./arch/${ARCH}/configs/${DEFCONFIG}" ]; then
               echo "${DEFCONFIG} not found, exited with error status 2."
                if [ "$SEND_TO_TG" -eq 1 ]; then
                   curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
                   -d chat_id="$chat_id" \
                   -d "disable_web_page_preview=true" \
                   -d "parse_mode=html" \
                   -d text="<code>${DEFCONFIG}</code> not found, exited with error status 2."
           fi
        exit 2
     fi
            
            export KBUILD_BUILD_USER=${BUILDER}
            export KBUILD_BUILD_HOST=${BUILD_HOST}
            export LOCALVERSION=${localversion}
            
            make O=out ARCH=${ARCH} ${DEFCONFIG}
            
            START=$(date +"%s")

if [ "$USE_LLVM" -eq 1 ]; then
    PATH="${PWD}/clang/bin:${PATH}:${PWD}/arm-gcc/bin:${PATH}:${PWD}/aarch64-gcc/bin:${PATH}" \
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
    CROSS_COMPILE="${PWD}/aarch64-gcc/bin/aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="${PWD}/arm-gcc/bin/arm-linux-gnueabihf-" \
    CONFIG_NO_ERROR_ON_MISMATCH=y \
    CONFIG_DEBUG_SECTION_MISMATCH=y \
    V=0 2>&1 | tee out/build.log
else
    PATH="${PWD}/clang/bin:${PATH}:${PWD}/arm-gcc/bin:${PATH}:${PWD}/aarch64-gcc/bin:${PATH}" \
    make -j"$PROCS" O=out \
    ARCH=${ARCH} \
    CC="clang" \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE="${PWD}/aarch64-gcc/bin/aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="${PWD}/arm-gcc/bin/arm-linux-gnueabihf-" \
    CONFIG_NO_ERROR_ON_MISMATCH=y \
    CONFIG_DEBUG_SECTION_MISMATCH=y \
    V=0 2>&1 | tee out/build.log
fi

END=$(date +"%s")
DIFF=$((END - START))
minutes=$((DIFF / 60))
seconds=$((DIFF % 60))


if [ ! -f "./out/arch/${ARCH}/boot/Image.gz-dtb" ]; then
  echo "build failed after ${minutes} minute(s) and ${seconds} second(s)."
  if [ "$SEND_TO_TG" -eq 1 ]; then
                         curl -F document=@./out/build.log "https://api.telegram.org/bot$token/sendDocument" \
                         -F chat_id="$chat_id" \
                         -F "disable_web_page_preview=true" \
                         -F "parse_mode=html" \
                         -F caption="
Build failed after ${minutes} minute(s) and ${seconds} second(s)."
fi
exit 1
fi

cp ./out/arch/${ARCH}/boot/Image.gz-dtb ./anykernel3
cd anykernel3
zip -r9 "${zipn}".zip *
checksum=$(sha512sum "${zipn}".zip | cut -f1 -d ' ')
echo "Build took ${minutes} minute(s) and ${seconds} second(s)."
echo "Kernel zip: ${PWD}/../out/target/${zipn}.zip"
echo "SHA512: ${checksum}"
echo ""

if [ "$SEND_TO_TG" -eq 1 ]; then
    curl -F document=@"${zipn}".zip "https://api.telegram.org/bot$token/sendDocument" \
                         -F chat_id="$chat_id" \
                         -F "disable_web_page_preview=true" \
                         -F "parse_mode=html" \
                         -F caption="
Build took ${minutes} minute(s) and ${seconds} second(s).
<b>SHA512</b>: <code>${checksum}</code>"
      curl -F document=@../out/build.log "https://api.telegram.org/bot$token/sendDocument" \
                         -F chat_id="$chat_id" \
                         -F "disable_web_page_preview=true" \
                         -F "parse_mode=html" \
                         -F caption="Build log"
fi
if [ ! -d "../out/target" ]; then
mkdir ../out/target
fi
mv "${zipn}".zip ../out/target
rm Image.gz-dtb
cd ..
echo "press enter to continue or type 0 for Quit"
read -r a1
if [ "$a1" == "0" ]; then
    exit 0
else
    clear
    bash origami_kernel_builder.sh
fi
;;
        2)
            echo "Generating DTBs..."
            time make -j"$PROCS" O=out dtbs dtbo.img dtb.img
            echo "done!"
            echo "press enter to continue or type 0 for Quit"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            bash origami_kernel_builder.sh
        fi
            ;;
        3)
            clear
            echo "Regenerating defconfig..."
            make O=out ARCH=${ARCH} ${DEFCONFIG}
            cp -rf "${PWD}"/out/.config "${PWD}"/arch/${ARCH}/configs/"$CONFIG"
            echo "done!"
            echo "press enter to continue or type 0 for Quit"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            bash origami_kernel_builder.sh
        fi
            ;;
        4)
            clear
            make O=out ARCH=${ARCH} ${DEFCONFIG}
            make O=out menuconfig
            echo "Exited menuconfig."
            echo "press enter to continue or type 0 for Quit"
            read -r a1
            if [ "$a1" == "0" ]; then
                exit 0
           else
            clear
            bash origami_kernel_builder.sh
         fi
            ;;
        5)
            clear
            make clean && make mrproper
            echo "done!"
            echo "press enter to continue or type 0 for Quit"
        read -r a1
        if [ "$a1" == "0" ]; then
            exit 0
        else
            clear
            bash origami_kernel_builder.sh
        fi
            ;;
        6)
            exit 0
            ;;
        7)
            echo "Usage: bash origami_kernel_builder.sh --choose=[Function]"
            echo ""
            echo "Some functions on Origami Kernel Builder:"
            echo "1. Build a whole Kernel"
            echo "2. Build DTBs"
            echo "3. Regenerate defconfig"
            echo "4. Open menuconfig"
            echo "5. Clean"
            echo ""
            echo "Place this script inside the Kernel Tree"
            ;;
        *)
            echo "error: Not a valid choices"
            exit 1
            ;;
    esac
}

if [ $# -eq 0 ]; then
    clear
    echo "What do you want to do today?"
    echo ""
    echo "1. Build a whole Kernel"
    echo "2. Build DTBs"
    echo "3. Regenerate defconfig"
    echo "4. Open menuconfig"
    echo "5. Clean"
    echo "6. Quit"
    read -r choice
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
        --choose=5)
            choice=5
            ;;
        --help)
            choice=7
            ;;
        *)
            echo "error: Not a valid argument"
            echo "Try 'bash origami_kernel_builder.sh --help' for more information."
            exit 1
            ;;
    esac
fi

execute_operation "$choice"
