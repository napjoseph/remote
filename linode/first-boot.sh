#!/bin/bash

set -eu

# <UDF name="hostname" label="The hostname for the machine." default="localhost" example="localhost" />
# <UDF name="username" label="The username of the default non-root user." default="" example="user" />
# <UDF name="password" label="The password of the default non-root user." default="" example="password" />

sudo hostnamectl set-hostname $HOSTNAME

# Updates the packages on the system from the distribution repositories.
apt-get update
apt-get -y upgrade

# Installs the essential applications.
apt-get -y install build-essential git tree

# Creates a password-less user with sudo access.
adduser --disabled-password --gecos "" ${USERNAME}
usermod -aG sudo ${USERNAME}
# Only then will we add a password.
echo "${USERNAME}:${PASSWORD}" | chpasswd
# Copy the local public key to the new user's ~/.ssh/authorized_keys.
cp -r /root/.ssh /home/${USERNAME}/.ssh
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh

# TODO: Setup gpg keys
# TODO: Setup git config
# TODO: Setup docker, go, python, node
