#!/bin/bash

# Adding data from settings
source ../settings.sh

# Start of the script execution time count
start_time=$(date +%s)

# Deleting the "out" directory if it exists
rm -rf out

# Main directory
MAINPATH=/home/Andrian # Change if necessary

# Kernel directory
KERNEL_DIR=$MAINPATH/release
KERNEL_PATH=$KERNEL_DIR/kernel_xiaomi_sm8250

git log $LAST..HEAD > ../changelog.txt
BRANCH=$(git branch --show-current)

# Compilation tools directories
CLANG_DIR=$KERNEL_DIR/clang20
ANDROID_PREBUILTS_GCC_ARM_DIR=$KERNEL_DIR/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9
ANDROID_PREBUILTS_GCC_AARCH64_DIR=$KERNEL_DIR/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9

# Check and clone if necessary
check_and_clone() {
    local dir=$1
    local repo=$2

    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist. Cloning $repo."
        git clone $repo $dir
    fi
}

check_and_wget() {
    local dir=$1
    local repo=$2

    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist. Cloning $repo."
        mkdir $dir
        cd $dir
        wget $repo
        tar -zxvf Clang-20.0.0git-20241222.tar.gz
        rm -rf Clang-20.0.0git-20241222.tar.gz
        cd ../kernel_xiaomi_sm8250
    fi
}

# Clone the compilation tools if they don't exist
check_and_wget $CLANG_DIR https://github.com/ZyCromerZ/Clang/releases/download/20.0.0git-20241222-release/Clang-20.0.0git-20241222.tar.gz
check_and_clone $ANDROID_PREBUILTS_GCC_ARM_DIR https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9
check_and_clone $ANDROID_PREBUILTS_GCC_AARCH64_DIR https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9

# Setting PATH variables
PATH=$CLANG_DIR/bin:$ANDROID_PREBUILTS_GCC_AARCH64_DIR/bin:$ANDROID_PREBUILTS_GCC_ARM_DIR/bin:$PATH
export PATH
export ARCH=arm64

# MagicTime build directory
MAGIC_TIME_DIR="$KERNEL_DIR/MagicTime"

# Creating the MagicTime directory if it doesn't exist
if [ ! -d "$MAGIC_TIME_DIR" ]; then
    mkdir -p "$MAGIC_TIME_DIR"
    
    # Check and clone Anykernel if MagicTime doesn't exist
    if [ ! -d "$MAGIC_TIME_DIR/Anykernel" ]; then
        git clone https://github.com/TIMISONG-dev/Anykernel.git "$MAGIC_TIME_DIR/Anykernel"
        
        # Moving all files from Anykernel to MagicTime
        mv "$MAGIC_TIME_DIR/Anykernel/"* "$MAGIC_TIME_DIR/"
        
        # Deleting the Anykernel folder
        rm -rf "$MAGIC_TIME_DIR/Anykernel"
    fi
else
    # If MagicTime exists, check for the .git folder and remove it if it exists
    if [ -d "$MAGIC_TIME_DIR/.git" ]; then
        rm -rf "$MAGIC_TIME_DIR/.git"
    fi
fi

# Exporting environment variables
export IMGPATH="$MAGIC_TIME_DIR/Image"
export DTBPATH="$MAGIC_TIME_DIR/dtb"
export DTBOPATH="$MAGIC_TIME_DIR/dtbo.img"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"
export KBUILD_BUILD_USER="Andrian"
export KBUILD_BUILD_HOST="andrian-dev"
export MODEL="andrian"

# Recording the build time
MAGIC_BUILD_DATE=$(date '+%Y-%m-%d_%H-%M-%S')

# Output directory for build results
output_dir=out

# Kernel configuration
make O="$output_dir" \
            ${DEVICE}_defconfig \
            vendor/xiaomi/sm8250-common.config

# Kernel compilation
make -j $(nproc) \
                O="$output_dir" \
                CC="ccache clang" \
                HOSTCC=gcc \
                LD=ld.lld \
                AS=llvm-as \
                AR=llvm-ar \
                NM=llvm-nm \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip \
                LLVM=1 \
                LLVM_IAS=1 \
                V=$VERBOSE 2>&1 | tee build.log


# Assuming the DTS variable is set earlier in the script
find $DTS -name '*.dtb' -exec cat {} + > $DTBPATH
find $DTS -name 'Image' -exec cat {} + > $IMGPATH
find $DTS -name 'dtbo.img' -exec cat {} + > $DTBOPATH

# End of the script execution time count
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

cd "$KERNEL_PATH"

# Checking the success of the build
if grep -q -E "Ошибка 2|Error 2" build.log; then
    cd "$KERNEL_PATH"
    echo "Error: The build finished with an error"

else
    echo "Total execution time: $elapsed_time seconds"
    # Moving to the MagicTime directory and creating an archive
    cd "$MAGIC_TIME_DIR"
    7z a -mx9 MagicTime-$DEVICE-$MAGIC_BUILD_DATE.zip * -x!*.zip

    BUILD=$((BUILD + 1))

    cd "$KERNEL_PATH"
    LAST=$(git log -1 --format=%H)

    sed -i "s/LAST=.*/LAST=$LAST/" ../settings.sh
    sed -i "s/BUILD=.*/BUILD=$BUILD/" ../settings.sh
fi
