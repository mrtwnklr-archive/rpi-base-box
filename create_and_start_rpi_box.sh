#!/bin/bash

# PiBox config
readonly SSH_PORT=${1:-5022}
readonly HOSTNAME=${2:-}
readonly PI_GPU_MEMORY=${3:-16}
readonly RASPBIAN_RELEASE_DATE=${4:-2019-09-30}
readonly RASPBIAN_IMAGE=${5:-2019-09-26-raspbian-buster-lite}
readonly RASPBIAN_IMAGE_URL=https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-${RASPBIAN_RELEASE_DATE}/${RASPBIAN_IMAGE}.zip

readonly PROVISIONER_PRIVATE_KEY_FILE=private_key
readonly PROVISIONER_PUBLIC_KEY_FILE=public_key
readonly PIBOX_IMAGES_CACHE_DIR=~/.cache/pibox
readonly PIBOX_DIR=$(pwd)/.pibox/${HOSTNAME:-rpi}

function download_images() {
    mkdir --parents "${PIBOX_IMAGES_CACHE_DIR}"
    
    pushd "${PIBOX_IMAGES_CACHE_DIR}" 1>/dev/null

    if [[ ! -f ${RASPBIAN_IMAGE}.zip ]]
    then
        wget ${RASPBIAN_IMAGE_URL}
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

function mount_partition() {
    local partition_marker="${1}" ; shift
    local mount_point="${1}" ; shift

    SECTOR=$( fdisk --list "${PIBOX_DIR}/${RASPBIAN_IMAGE}.img" | grep ${partition_marker} | awk '{ print $2 }' )
    OFFSET=$(( SECTOR * 512 ))

    mkdir --parents "${mount_point}"

    sudo mount "${PIBOX_DIR}/${RASPBIAN_IMAGE}.img" --options offset=$OFFSET "${mount_point}"
}

function get_mount_point_boot() {
    echo "${PIBOX_DIR}/imageMountBoot"
}

function mount_boot_partition() {
    mount_partition "FAT32" "$(get_mount_point_boot)"
}

function unmount_boot_partition() {
    sudo umount "$(get_mount_point_boot)"

    sudo rm -rf "$(get_mount_point_boot)"
}

function get_mount_point_root() {
    echo "${PIBOX_DIR}/imageMountRoot"
}

function mount_root_partition() {
    mount_partition "Linux" "$(get_mount_point_root)"
}

function unmount_root_partition() {
    sudo umount "$(get_mount_point_root)"

    sudo rm -rf "$(get_mount_point_root)"
}

function configure_ssh() {
    mount_boot_partition

    sudo touch "$(get_mount_point_boot)/ssh"

    cat >> "${PIBOX_DIR}/next_run.ssh.sh" << EOF
#!/bin/bash
sudo chown --recursive $USER:$GROUP ~/.ssh
EOF

    sudo cp --force "${PIBOX_DIR}/next_run.ssh.sh" "$(get_mount_point_boot)/next_run.ssh.sh"
    sudo chmod +x "$(get_mount_point_boot)/next_run.ssh.sh"

    rm "${PIBOX_DIR}/next_run.ssh.sh"

    unmount_boot_partition

    mount_root_partition

    if [[ ! -f "${PIBOX_DIR}/${PROVISIONER_PRIVATE_KEY_FILE}" ]]
    then
        # create new public key
        local comment="rpi_provisioner_$(date +%F_%H-%M-%S)@wnklr.net"
        ssh-keygen -b 4096 -t rsa -C "${comment}" -f "${PIBOX_DIR}/${PROVISIONER_PRIVATE_KEY_FILE}" -P ''
        mv "${PIBOX_DIR}/${PROVISIONER_PRIVATE_KEY_FILE}.pub" "${PIBOX_DIR}/${PROVISIONER_PUBLIC_KEY_FILE}"
    fi

    sudo mkdir --parents "$(get_mount_point_root)/home/pi/.ssh"
    if [[ -z $(grep --file "${PIBOX_DIR}/${PROVISIONER_PUBLIC_KEY_FILE}" "$(get_mount_point_root)/home/pi/.ssh/authorized_keys" 2>/dev/null) ]]
    then
        # transfer new public key
        cat "${PIBOX_DIR}/${PROVISIONER_PUBLIC_KEY_FILE}" | sudo tee "$(get_mount_point_root)/home/pi/.ssh/authorized_keys"
    fi

    unmount_root_partition
}

function configure_memory_split() {

    mount_boot_partition

    echo "gpu_mem=${PI_GPU_MEMORY}" | sudo tee "$(get_mount_point_boot)/config.txt"

    unmount_boot_partition
}

function configure_hostname() {

    if [[ ! -z ${HOSTNAME} ]]
    then
        mount_boot_partition

        cat >> "${PIBOX_DIR}/next_run.sh" << EOF
#!/bin/bash
if [[ "${HOSTNAME}" != "\$(cat /etc/hostname)" ]]
then
    echo "${HOSTNAME}" | tee /etc/hostname
    sed -i -E 's/^127.0.1.1.*/127.0.1.1\t'"${HOSTNAME}"'/' /etc/hosts
    hostnamectl set-hostname "${HOSTNAME}"
    systemctl restart avahi-daemon
fi
EOF

        sudo cp --force "${PIBOX_DIR}/next_run.sh" "$(get_mount_point_boot)/next_run.sh"
        sudo chmod +x "$(get_mount_point_boot)/next_run.sh"

        rm "${PIBOX_DIR}/next_run.sh"

        unmount_boot_partition
    fi
}

function configure_wifi() {

    if [[ ! -z ${WIFI_PASSWORD} ]]
    then
        mount_root_partition

        cat >> "${PIBOX_DIR}/wpa_supplicant.conf" << EOF
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    scan_ssid=1
    ssid="${WIFI_SSID}"
    psk="${WIFI_PASSWORD}"
}
EOF

        sudo cp --force "${PIBOX_DIR}/wpa_supplicant.conf" "$(get_mount_point_root)/etc/wpa_supplicant/wpa_supplicant.conf"

        #rm "${PIBOX_DIR}/wpa_supplicant.conf"

        unmount_root_partition
    fi
}

function prepare_image() {
    if [[ ! -f "${PIBOX_DIR}/${RASPBIAN_IMAGE}.img" ]]
    then
        unzip "${PIBOX_IMAGES_CACHE_DIR}/${RASPBIAN_IMAGE}.zip" -d "${PIBOX_DIR}"
    fi

    configure_ssh
    configure_memory_split
    configure_hostname
    configure_wifi
}

function emulate_rpi1_4_4() {
    qemu-system-arm -M versatilepb -cpu arm1176 -m 256 \
                    -net nic \
                    -net user,hostfwd=tcp::${SSH_PORT}-:22 \
                    -kernel "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/kernel-qemu-4.4.34-jessie" \
                    -drive format=raw,file=${RASPBIAN_IMAGE}.img \
                    -append 'root=/dev/sda2 panic=1' &
}

function emulate_rpi1_4_14() {
    qemu-system-arm -M versatilepb -cpu arm1176 -m 256 \
                    -net nic \
                    -net user,hostfwd=tcp::${SSH_PORT}-:22 \
                    -dtb "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/versatile-pb.dtb" \
                    -kernel "${PIBOX_IMAGES_CACHE_DIR}/qemu-rpi-kernel/kernel-qemu-4.14.79-stretch" \
                    -drive format=raw,file=${PIBOX_DIR}/${RASPBIAN_IMAGE}.img \
                    -append 'root=/dev/sda2 panic=1 console=ttyS0' \
                    -no-reboot -nographic &
}

execute_command_over_ssh() {
    local command="${1}" ; shift

    ssh -o 'NoHostAuthenticationForLocalhost=yes' -i "${PIBOX_DIR}/${PROVISIONER_PRIVATE_KEY_FILE}" -p ${SSH_PORT} pi@127.0.0.1 "${command}"
}

function wait_for_ssh() {
    while :
    do
        sleep 5
        nc -z 127.0.0.1 ${SSH_PORT}
        if [[ $? -eq 0 ]]
        then
            execute_command_over_ssh 'echo $(hostname) successfully started: $(uname --all)'
            if [[ ! $? -eq 255 ]]
            then
                break
            fi
        else
            echo Waiting for SSH becoming available...
        fi
    done
}


if [[ ! -d "${PIBOX_DIR}" ]]
then
    mkdir --parents "${PIBOX_DIR}"
fi

pushd "${PIBOX_DIR}" 1>/dev/null

if [[ ! -f "${RASPBIAN_IMAGE}.img" ]]
then
    download_images
    prepare_image
fi

emulate_rpi1_4_14
wait_for_ssh
execute_command_over_ssh "sudo /boot/next_run.sh"
execute_command_over_ssh "sudo rm /boot/next_run.sh"
execute_command_over_ssh "sudo /boot/next_run.ssh.sh"
execute_command_over_ssh "sudo rm /boot/next_run.ssh.sh"
execute_command_over_ssh "sudo shutdown -P 0"

popd 1>/dev/null

# # echo “StrictHostKeyChecking=no” >> /etc/ssh/ssh_config
