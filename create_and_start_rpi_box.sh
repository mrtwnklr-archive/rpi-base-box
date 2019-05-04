#!/bin/bash

readonly RASPBIAN_IMAGE=2018-11-13-raspbian-stretch-lite
readonly SSH_PORT=${1:-5022}
readonly PROVISIONER_PRIVATE_KEY_FILE=private_key
readonly PROVISIONER_PUBLIC_KEY_FILE=public_key
readonly PIBOX_IMAGES_CACHE_DIR=~/.cache/pibox

function download_images() {
    mkdir --parents "${PIBOX_IMAGES_CACHE_DIR}"
    
    pushd "${PIBOX_IMAGES_CACHE_DIR}" 1>/dev/null

    if [[ ! -f ${RASPBIAN_IMAGE}.zip ]]
    then
        wget https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-11-15/${RASPBIAN_IMAGE}.zip
    fi

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

function enable_ssh() {
    local piBoxPath=$(pwd)

    SECTOR1=$( fdisk --list "${RASPBIAN_IMAGE}.img" | grep FAT32 | awk '{ print $2 }' )
    SECTOR2=$( fdisk --list "${RASPBIAN_IMAGE}.img" | grep Linux | awk '{ print $2 }' )
    OFFSET1=$(( SECTOR1 * 512 ))
    OFFSET2=$(( SECTOR2 * 512 ))

    # make 'boot' vfat partition available locally
    mkdir --parents tmpmnt

    # enable ssh
    sudo mount ${RASPBIAN_IMAGE}.img --options offset=$OFFSET1 tmpmnt
    sudo touch tmpmnt/ssh
    sudo umount tmpmnt

    # transfer new public key
    sudo mount ${RASPBIAN_IMAGE}.img --options offset=$OFFSET2 tmpmnt
    pushd tmpmnt 1>/dev/null

    if [[ ! -f "${piBoxPath}/${PROVISIONER_PRIVATE_KEY_FILE}" ]]
    then
        local comment="rpi_provisioner_$(date +%F_%H-%M-%S)@wnklr.net"
        ssh-keygen -b 4096 -t rsa -C "${comment}" -f "${piBoxPath}/${PROVISIONER_PRIVATE_KEY_FILE}" -P ''
        mv "${piBoxPath}/${PROVISIONER_PRIVATE_KEY_FILE}.pub" "${piBoxPath}/${PROVISIONER_PUBLIC_KEY_FILE}"
    fi

    sudo mkdir --parents home/pi/.ssh
    if [[ -z $(grep --file "${piBoxPath}/${PROVISIONER_PUBLIC_KEY_FILE}" home/pi/.ssh/authorized_keys) ]]
    then
        cat "${piBoxPath}/${PROVISIONER_PUBLIC_KEY_FILE}" | sudo tee home/pi/.ssh/authorized_keys
    fi

    popd 1>/dev/null

    sudo umount tmpmnt

    rm -rf tmpmnt
}

function prepare_image() {
    unzip "${PIBOX_IMAGES_CACHE_DIR}/${RASPBIAN_IMAGE}.zip"

    enable_ssh

    # disable ssh password login
    # set wifi access
}

function emulate_rpi() {
    qemu-system-arm -M versatilepb -cpu arm1176 -m 256 \
                    -net nic \
                    -net user,hostfwd=tcp::${SSH_PORT}-:22 \
                    -dtb "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/versatile-pb.dtb" \
                    -kernel "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/kernel-qemu-4.14.79-stretch" \
                    -hda "${RASPBIAN_IMAGE}.img" \
                    -append 'root=/dev/sda2 panic=1' &
}

function wait_for_ssh() {
    while :
    do
        sleep 5
        nc -z 127.0.0.1 ${SSH_PORT}
        if [[ $? -eq 0 ]]
        then
            ssh -o 'NoHostAuthenticationForLocalhost=yes' -i "${PROVISIONER_PRIVATE_KEY_FILE}" -p ${SSH_PORT} pi@127.0.0.1 echo Successfully started
            if [[ ! $? -eq 255 ]]
            then
                break
            fi
        else
            echo Waiting for SSH becoming available...
        fi
    done
}


if [[ ! -d ".pibox" ]]
then
    mkdir --parents ".pibox"
fi

pushd .pibox 1>/dev/null

if [[ ! -f "${RASPBIAN_IMAGE}.img" ]]
then
    download_images
    prepare_image
fi

emulate_rpi
wait_for_ssh

popd 1>/dev/null

# # apt-get update
# # echo “StrictHostKeyChecking=no” >> /etc/ssh/ssh_config