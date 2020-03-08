# README

## TODO

- SSH muss bereits im verwendeten Image aktiviert sein
- Skript zum Erstellen von mehreren Images mit aktiviertem SSH, Hostname, ggf. Auth-Keys, ausgehend von einer yaml-Datei? Anschließend diese yaml-Datei verwenden um in Vagrantfile dynamisch die Boxen zu erstellen und Images zuzuordnen

### Works, v1, needs modification of `lukechilds/dockerpi`

```Vagrantfile

  config.ssh.username = "pi"
  config.ssh.insert_key = false
  config.ssh.password = "raspberry"

  config.vm.provider "docker" do |d|
    d.image = "lukechilds/dockerpi"
    d.has_ssh = true
    # SSH muss bereits im Image aktiviert sein
    d.volumes = [ "/home/marty/Dokumente/Repos/wnklr/devices/rpi-base-box/.pibox/rpi/2019-09-26-raspbian-buster-lite.img:/sdcard/filesystem.img" ]
    d.env = {
      SSH_PORT: 22
    }
  end
```

### Works, v2, does not need modification of `lukechilds/dockerpi`

```Vagrantfile

  config.ssh.username = "pi"
  config.ssh.insert_key = false
  config.ssh.password = "raspberry"
  config.ssh.port = 5022
  config.vm.network :forwarded_port, id: "ssh", guest: 5022, host: 2222

  config.vm.provider "docker" do |d|
    d.image = "lukechilds/dockerpi"
    d.has_ssh = true
    # SSH muss bereits im Image aktiviert sein
    d.volumes = [ "/home/marty/Dokumente/Repos/wnklr/devices/rpi-base-box/.pibox/rpi/2019-09-26-raspbian-buster-lite.img:/sdcard/filesystem.img" ]
  end
```
