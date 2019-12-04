#!/bin/bash

if [[ ! -d qemu-rpi-kernel ]]
then
    git clone https://github.com/dhruvvyas90/qemu-rpi-kernel.git
else
    pushd qemu-rpi-kernel 1>/dev/null
    
    git pull --all --tags --prune

    popd 1>/dev/null
fi

sudo apt-get install qemu qemu-system-arm
