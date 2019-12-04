#!/bin/bash

PIBOX_CACHE_DIR=~/.cache/pibox
PIBOX_IMAGE_NAME=2018-11-13-raspbian-stretch-lite
PIBOX_IMAGE_PATH=../../../garden.ansible-playbook/.pibox/${PIBOX_IMAGE_NAME}.img

if [[ ! -f "${PIBOX_IMAGE_PATH}" ]]
then
    unzip "${PIBOX_CACHE_DIR}/${PIBOX_IMAGE_NAME}.zip"
fi

loopDevice=$(sudo losetup -f --show -P "${PIBOX_IMAGE_PATH}")

if [[ ! -f ~/.cache/pibox/bcm2709-rpi-2-b.dtb ]]
then
    sudo mkdir /mnt/rpi
    sudo mount ${loopDevice}p1 /mnt/rpi
    cp /mnt/rpi/kernel7.img /mnt/rpi/bcm2709-rpi-2-b.dtb "${PIBOX_CACHE_DIR}/"
    sudo umount /mnt/rpi
    sudo rmdir /mnt/rpi
    sudo losetup -d ${loopDevice}
fi

#qemu-system-arm \
#    -M raspi2 \
#    -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1" \
#    -cpu arm1176 \
#    -dtb "${PIBOX_CACHE_DIR}/bcm2709-rpi-2-b.dtb" \
#    -sd "${PIBOX_IMAGE_PATH}" \
#    -kernel "${PIBOX_CACHE_DIR}/kernel7.img" \
#    -m 1G \
#    -smp 4 \
#    -serial stdio \

qemu-system-arm \
    -M raspi2 \
    -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1" \
    -cpu cortex-a7 \
    -dtb "${PIBOX_CACHE_DIR}/bcm2709-rpi-2-b.dtb" \
    -sd "${PIBOX_IMAGE_PATH}" \
    -kernel "${PIBOX_CACHE_DIR}/kernel7.img" \
    -m 1G \
    -smp 4 \
    -serial stdio \

# qemu-system-arm \
#     -M versatilepb \
#     -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1" \
#     -cpu arm1176 \
#     -dtb "${PIBOX_CACHE_DIR}/bcm2709-rpi-2-b.dtb" \
#     -sd "${PIBOX_IMAGE_PATH}" \
#     -kernel "${PIBOX_CACHE_DIR}/kernel7.img" \
#     -net nic \
#     -net user,hostfwd=tcp::${SSH_PORT}-:22 \
#     -m 256M \
#     -smp 1 \
#     -serial stdio \