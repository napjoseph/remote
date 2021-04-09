#!/bin/bash

# <UDF name="username" label="The username of the default non-root user." default="user" example="user" />
# <UDF name="password" label="The password of the default non-root user." default="" example="password" />

# Updates the packages on the system from the distribution repositories.
apt-get update
apt-get upgrade -y

# Installs the essential applications.
apt install build-essential git tree --yes

# Creates a password-less user $USERNAME with sudo access.
adduser --disabled-password --gecos "" ${USERNAME}
usermod -aG sudo ${USERNAME}
# Only then will we add a password.
echo "${USERNAME}:${PASSWORD}" | chpasswd
