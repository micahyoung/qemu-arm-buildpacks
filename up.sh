#!/bin/bash
set -o errexit -o nounset -o pipefail

if ! [ -f bionic.qcow2 ]; then
  rsync -aP rsync://cloud-images.ubuntu.com/cloud-images/bionic/current/bionic-server-cloudimg-arm64.img bionic.qcow2
  qemu-img resize bionic.qcow2 20G
fi

cat > meta-data <<EOF
local-hostname: docker-arm64
EOF

cat > user-data <<EOF
#cloud-config
ssh_pwauth: True
groups:
- docker
users:
- name: ubuntu
  sudo: ALL=(ALL) NOPASSWD:ALL
  groups:
  - docker
chpasswd:
  list: |
     ubuntu:ubuntu
  expire: True

packages:
- build-essential
- curl
- git
- htop
- apt-transport-https
- ca-certificates
- gnupg-agent
- software-properties-common
- docker-ce
- golang-go

apt:
  preserve_sources_list: true
  sources:
    docker.list:
      source: "deb [arch=arm64] https://download.docker.com/linux/ubuntu \$RELEASE stable"
      keyid: 0EBFCD88
    golang-key-ignored1:
      source: "ppa:longsleep/golang-backports"
EOF

rm -f user-data.iso
mkisofs -output user-data.iso -volid cidata -joliet -rock user-data meta-data

qemu-system-aarch64 -M virt -m 2048 -smp 2 -cpu cortex-a53 \
  -bios /usr/local/share/qemu/edk2-aarch64-code.fd \
  -drive file=user-data.iso,media=cdrom \
  -drive if=none,file=bionic.qcow2,format=qcow2,id=hd \
  -device virtio-blk-pci,drive=hd \
  -netdev user,id=mynet,hostfwd=tcp::10022-:22 \
  -device virtio-net-pci,netdev=mynet \
  -nographic -no-reboot
