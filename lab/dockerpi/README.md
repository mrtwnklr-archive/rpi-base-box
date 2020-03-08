# Benutzung mit DockerPi

1. Image mit aktiviertem SSH
`/home/marty/Dokumente/Repos/wnklr/devices/rpi-base-box/.pibox/rpi/2019-09-26-raspbian-buster-lite.img`

1. Start des Docker-Containers mit Port-Weiterleitung
`docker run -it -p 5022:5022 -v /home/marty/Dokumente/Repos/wnklr/devices/rpi-base-box/.pibox/rpi/2019-09-26-raspbian-buster-lite.img:/sdcard/filesystem.img lukechilds/dockerpi:vm`

1. Test der Verbindung
`ssh -o 'NoHostAuthenticationForLocalhost=yes' -p 5022 pi@127.0.0.1 "echo Hallo $(uname -a)"`