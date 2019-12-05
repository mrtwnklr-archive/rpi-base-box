#!/bin/bash

readonly RASPBIAN_LITE_VERSION=2019-09-30
readonly RASPB7IAN_IMAGE=2019-09-26-raspbian-buster-lite
readonly QEMU_KERNEL=kernel-qemu-4.19.50-buster

function download_image() {
    if [[ ! -f "${RASPBIAN_IMAGE}.zip" ]]
    then
        wget https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-${RASPBIAN_LITE_VERSION}/${RASPBIAN_IMAGE}.zip
    fi
}

function enable_ssh() {
    SECTOR1=$( fdisk --list ${RASPBIAN_IMAGE}.img | grep FAT32 | awk '{ print $2 }' )
    SECTOR2=$( fdisk --list ${RASPBIAN_IMAGE}.img | grep Linux | awk '{ print $2 }' )
    OFFSET1=$(( SECTOR1 * 512 ))
    OFFSET2=$(( SECTOR2 * 512 ))

    # make 'boot' vfat partition available locally
    mkdir --parents /tmp/tmpmnt
    sudo mount ${RASPBIAN_IMAGE}.img --options offset=$OFFSET1 /tmp/tmpmnt
    sudo touch /tmp/tmpmnt/ssh   # this enables ssh
    sudo umount /tmp/tmpmnt
}

function prepare_image() {
    unzip ${RASPBIAN_IMAGE}.zip

    enable_ssh

    # disable ssh password login
    # set wifi access
}

function emulate_rpi() {
    qemu-system-arm -M versatilepb -cpu arm1176 -m 256 \
                    -net nic \
                    -net user,hostfwd=tcp::5022-:22 \
                    -dtb qemu-rpi-kernel/versatile-pb.dtb \
                    -kernel qemu-rpi-kernel/${QEMU_KERNEL} \
                    -hda ${RASPBIAN_IMAGE}.img \
                    -append 'root=/dev/sda2 panic=1' &

    while :
    do
        sleep 5
        nc -z 127.0.0.1 5022
        if [[ $? -eq 0 ]]
        then
            ssh -p 5022 pi@127.0.0.1
            if [[ ! $? -eq 255 ]]
            then
                break
            fi
        else
            echo Waiting for SSH becoming available...
        fi
    done

    ssh-copy-id -p 5022 pi@127.0.0.1
}

function emulate_rpi_libvirt() {

    sudo apt-get install libvirt-bin virtinst virt-viewer

    # Fixes error on activating default network:
    # error: internal error: Failed to initialize a valid firewall backend
    sudo apt-get install ebtables dnsmasq
    
#    virt-install \
#    --name pi \
#    --arch armv7l \
#    --machine versatilepb \
#    --cpu arm1176 \
#    --vcpus 1 \
#    --memory 256 \
#    --import \
#    --disk ${RASPBIAN_IMAGE}.img,format=raw,bus=virtio \
#    --network user,model=virtio \
#    --video vga \
#    --graphics spice \
#    --rng device=/dev/urandom,model=virtio \
#    --boot 'dtb=qemu-rpi-kernel/versatile-pb.dtb,kernel=qemu-rpi-kernel/kernel-qemu-4.14.79-stretch,kernel_args=root=/dev/vda2 panic=1' \
#    --events on_reboot=destroy

    # sudo cp ${RASPBIAN_IMAGE}.img /var/lib/libvirt/images/

    sudo virt-install \
    --name pi3 \
    --arch armv7l \
    --machine virt \
    --vcpus 1 \
    --memory 256 \
    --import \
    --disk /var/lib/libvirt/images/${RASPBIAN_IMAGE}.img,format=raw,bus=virtio \
    --network user,model=virtio \
    --video vga \
    --graphics spice \
    --rng device=/dev/urandom,model=virtio \
    --boot 'dtb=/var/lib/libvirt/images/versatile-pb.dtb,kernel=/var/lib/libvirt/images/kernel-qemu-4.14.79-stretch,kernel_args=root=/dev/vda2 panic=1 console=ttyAMA0' \
    --events on_reboot=destroy,on_poweroff=destroy --check all=off

}

download_image
prepare_image
emulate_rpi

# # apt-get update
# # echo “StrictHostKeyChecking=no” >> /etc/ssh/ssh_config