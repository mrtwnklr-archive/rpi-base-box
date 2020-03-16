#!/bin/bash

# PiBox config
readonly RASPBIAN_IMAGE=${1}
readonly SSH_PORT=${2:-5122}

readonly PIBOX_IMAGES_CACHE_DIR=~/.cache/pibox

function download_images() {
    mkdir --parents "${PIBOX_IMAGES_CACHE_DIR}"
    
    pushd "${PIBOX_IMAGES_CACHE_DIR}" 1>/dev/null

    if [[ ! -d "qemu-rpi-kernel" ]]
    then
        git clone --depth=1 --branch=master --single-branch https://github.com/dhruvvyas90/qemu-rpi-kernel.git
    else
        pushd qemu-rpi-kernel 1>/dev/null

        git pull --all --tags --prune

        popd 1>/dev/null
    fi

    popd 1>/dev/null
}

function emulate_rpi1_4_4() {
    qemu-system-arm -M versatilepb -cpu arm1176 -m 256 \
                    -net nic \
                    -net user,hostfwd=tcp::${SSH_PORT}-:22 \
                    -kernel "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/kernel-qemu-4.4.34-jessie" \
                    -drive format=raw,file=${RASPBIAN_IMAGE} \
                    -append 'root=/dev/sda2 panic=1' &
}

function emulate_rpi1_4_14() {
    qemu-system-arm -M versatilepb -cpu arm1176 -m 256 \
                    -net nic \
                    -net user,hostfwd=tcp::${SSH_PORT}-:22 \
                    -dtb "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/versatile-pb.dtb" \
                    -kernel "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/kernel-qemu-4.14.79-stretch" \
                    -drive format=raw,file=${RASPBIAN_IMAGE} \
                    -append 'root=/dev/sda2 panic=1 console=ttyS0' \
                    -no-reboot -nographic &
}

function emulate_rpi1_4_19() {
    qemu-system-arm -M versatilepb -cpu arm1176 -m 256 \
                    -net nic \
                    -net user,hostfwd=tcp::${SSH_PORT}-:22 \
                    -dtb "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/versatile-pb.dtb" \
                    -kernel "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/kernel-qemu-4.19.50-buster" \
                    -drive format=raw,file=${RASPBIAN_IMAGE} \
                    -append 'root=/dev/sda2 panic=1 console=ttyS0' \
                    -no-reboot -nographic &
}

echo ${PIBOX_IMAGES_CACHE_DIR}
download_images
emulate_rpi1_4_19
