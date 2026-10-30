FROM ubuntu:latest  

# Install systemd, dbus, and ssh tools
RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    dbus \
    openssh-server \
    sudo \
    && apt-get clean

# Tells Apple Containers to boot this as a full OS init system
CMD ["/sbin/init"]
