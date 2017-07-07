## -*- docker-image-name: "scaleway/docker" -*-
FROM scaleway/ubuntu:amd64-xenial
# following 'FROM' lines are used dynamically thanks do the image-builder
# which dynamically update the Dockerfile if needed.
#FROM scaleway/ubuntu:armhf-xenial     # arch=armv7l
#FROM scaleway/ubuntu:arm64-xenial     # arch=arm64
#FROM scaleway/ubuntu:i386-xenial      # arch=i386
#FROM scaleway/ubuntu:mips-xenial      # arch=mips


MAINTAINER Scaleway <opensource@scaleway.com> (@scaleway)


# Prepare rootfs for image-builder
RUN /usr/local/sbin/builder-enter && apt-get install -y -q jq


# Install packages
RUN sed -i '/mirror.scaleway/s/^/#/' /etc/apt/sources.list \
 && apt-get -q update                   \
 && echo "Y" | apt-get upgrade  -y -qq  \
 && apt-get install -y -q               \
      apparmor                          \
      arping                            \
      aufs-tools                        \
      dnsutils                          \
      ufw                               \
      apt-transport-https               \
      btrfs-tools                       \
      bridge-utils                      \
      cgroup-lite                       \
      git                               \
      ifupdown                          \
      kmod                              \
      lxc                               \
      python-setuptools                 \
      vlan                              \
      gosu                              \
 && apt-get clean


# Install Docker
RUN apt-get install -q -y docker.io docker-compose

# Install k8s
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
 && echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list \
 && rm -rf /etc/apt/apt.conf.d/50unattended-upgrades.ucf-dist

# Install Docker Machine
RUN case "${ARCH}" in                                                                                                                                                 \
    x86_64|amd64|i386)                                                                                                                                                \
        arch_docker=x86_64;                                                                                                                                           \
        ;;                                                                                                                                                            \
    aarch64|arm64)                                                                                                                                                    \
        arch_docker=aarch64;                                                                                                                                          \
        ;;                                                                                                                                                            \
    armhf|armv7l|arm)                                                                                                                                                 \
        arch_docker=armhf;                                                                                                                                            \
        ;;                                                                                                                                                            \
    *)                                                                                                                                                                \
        echo "docker-machine not yet supported for this architecture."; exit 0;                                                                                       \
        ;;                                                                                                                                                            \
    esac;                                                                                                                                                             \
    MACHINE_REPO=https://api.github.com/repos/docker/machine/releases/latest;                                                                                         \
    MACHINE_URL=$(curl -s -L $MACHINE_REPO | jq -r --arg n "docker-machine-Linux-${arch_docker}" '.assets[] | select(.name | contains($n)) | .browser_download_url'); \
    curl -s -L $MACHINE_URL >/usr/local/bin/docker-machine && chmod +x /usr/local/bin/docker-machine


# Install Pipework
RUN wget -qO /usr/local/bin/pipework https://raw.githubusercontent.com/jpetazzo/pipework/master/pipework  \
 && chmod +x /usr/local/bin/pipework

# Patch rootfs
COPY ./overlay /

# Configure UFW
RUN sed -i 's/DEFAULT_INPUT_POLICY="DROP"/DEFAULT_INPUT_POLICY="ACCEPT"/g' /etc/default/ufw && \
    sed -i '/^COMMIT/i-A ufw-reject-input -j DROP' /etc/ufw/after.rules && \
    ufw logging off && \
    ufw allow ssh && \
    ufw allow from any to any port 6443 && \
    ufw enable
#
RUN systemctl disable docker; systemctl enable docker; systemctl enable k8s-install.service

# Clean rootfs from image-builder
RUN /usr/local/sbin/builder-leave && apt-get -fy autoremove
