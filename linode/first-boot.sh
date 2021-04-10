#!/bin/bash

set -eu

# <UDF name="HOSTNAME" label="The hostname for the machine." default="localhost" example="localhost" />
# <UDF name="HOSTNAME_APPEND_LINODE_ID" label="Append the Linode ID to the hostname?" oneof="yes,no" default="yes" />
# <UDF name="USERNAME" label="The username of the default non-root user." default="" example="user" />
# <UDF name="PASSWORD" label="The password of the default non-root user." default="" example="password" />
# <UDF name="SSH_PORT" label="Sets the SSH port. This won't be reflected in your Linode Dashboard." default="22" example="22" />
# <UDF name="LOCK_ROOT_ACCOUNT" label="Lock the root account?" oneof="yes,no" default="yes" />
# <UDF name="DEBIAN_UPGRADE" label="Upgrade the system automatically?" oneof="yes,no" default="yes" />
# <UDF name="GOLANG_VERSION" label="Version of Go you want to install. Check the list at https://golang.org/dl/." default="go1.16.3.linux-amd64" />

logfile="/var/log/stackscript.log"

log_error() {
  for x in "$@"; do
    test -n "$x" && \
      printf "[ERROR] ($(date '+%y-%m-%d %H:%M:%S')) %s\n" "$x" >> $logfile
  done
}

log_info() {
  for x in "$@"; do
    test -n "$x" && \
      printf "[INFO] ($(date '+%y-%m-%d %H:%M:%S')) %s\n" "$x" >> $logfile
  done
}

log() {
  local msg="$(2>&1 eval $1)"
  
  [ $? -ne 0 ] && \
    log_error "$msg" "$2" || \
    log_info "$msg" "$3"
}

create_user() {
  local ret=0

  [ -z "$PASSWORD" ] && \
    PASSWORD=$(awk -F: '$1 ~ /^root$/ { print $2 }' /etc/shadow) || \
    PASSWORD=$(openssl passwd -6 $PASSWORD)
  ret=$?
  
  useradd -mG sudo \
    -s /bin/bash \
    -p $PASSWORD \
    $USERNAME
  ret=$((ret+$?))

  return $ret
}

config_ssh() {
  local ret=0
  local sedopts="-i -E /etc/ssh/sshd_config -e 's/.*Port 22/Port $SSH_PORT/' \
                 -e 's/.*(PermitEmptyPasswords) .+/\1 no/' \
                 -e 's/.*(X11Forwarding) .+/\1 no/' \
                 -e 's/.*(ClientAliveInterval) .+/\1 300/' \
                 -e 's/.*(ClientAliveCountMax) .+/\1 2/' \
                 -e 's/.*(PubkeyAuthentication) .+/\1 yes/'"

  if [ -d /root/.ssh ]; then
    if [ "$USERNAME" ]; then
      sedopts="$sedopts -e 's/.*(PermitRootLogin) .+/\1 no/'"
      cp -r /root/.ssh /home/$USERNAME && \
        chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh && \
        chmod 700 /home/$USERNAME/.ssh
      ret=$?
    else
      sedopts="$sedopts -e 's/.*(PermitRootLogin) .+/\1 yes/'"
    fi
    
    sedopts="$sedopts -e 's/.*(PasswordAuthentication) .+/\1 no/'"
  else
    sedopts="$sedopts -e 's/.*(PasswordAuthentication) .+/\1 yes/'"
  fi

  eval sed $sedopts
  ret=$((ret+$?))
  systemctl restart ssh
  ret=$((ret+$?))

  return $ret
}

config_hostname() {
  local ret=0
  
  if [ "$HOSTNAME_APPEND_LINODE_ID" = "yes" ]; then
    HOSTNAME="$HOSTNAME-$LINODE_ID"
  fi

  hostnamectl set-hostname $HOSTNAME
  ret=$?
  sed -i "s/127.0.0.1	localhost/127.0.0.1	localhost $HOSTNAME/" /etc/hosts
  ret=$((ret+$?))

  return $ret
}

debian_upgrade () {
  export DEBIAN_FRONTEND="noninteractive"
  >/dev/null 2>&1 apt update -qq && \
    >/dev/null 2>&1 apt upgrade -qqy
}

install_keybase() {
  local ret=0

  wget https://prerelease.keybase.io/keybase_amd64.deb -O /tmp/keybase_amd64.deb
  ret=$?
  apt -y install /tmp/keybase_amd64.deb
  ret=$((ret+$?))
  rm /tmp/keybase_amd64.deb
  ret=$((ret+$?))

  return $ret
}

install_golang() {
  local ret=0

  wget https://golang.org/dl/$GOLANG_VERSION.tar.gz -O /tmp/$GOLANG_VERSION.tar.gz
  ret=$?
  tar -C /usr/local -xzf /tmp/$GOLANG_VERSION.tar.gz
  ret=$((ret+$?))
  rm /tmp/$GOLANG_VERSION.tar.gz
  ret=$((ret+$?))

  echo "export PATH=$PATH:/usr/local/go/bin" >> /home/$USERNAME/.profile
  ret=$((ret+$?))
  echo "export GOPATH=/home/$USERNAME/.go" >> /home/$USERNAME/.profile
  ret=$((ret+$?))
  
  return $ret
}

log "config_hostname" \
  "updating hostname to $HOSTNAME: failed." \
  "updating hostname to $HOSTNAME: successful."

log "create_user" \
  "creating user $USERNAME: failed." \
  "creating user $USERNAME: successful."

log "config_ssh" \
  "SSH configuration: failed." \
  "SSH configuration: successful."

[ "$LOCK_ROOT_ACCOUNT" = "yes" ] && {
  log "passwd -l root" \
    "locking root account: failed." \
    "locking root account: successful."
}

[ "$DEBIAN_UPGRADE" = "yes" ] && {
  log "debian_upgrade" \
    "upgrading system: failed." \
    "upgrading system: successful."
}

# Updates the packages on the system from the distribution repositories.
log "apt-get update" \
  "updating distribution repositories: failed." \
  "updating distribution repositories: successful."

# Installs the essential applications.
log "apt-get -y install build-essential git tree" \
  "installing applications: failed." \
  "installing applications: successful."

log "install_keybase" \
  "installing keybase: failed." \
  "installing keybase: successful."

log "install_golang" \
  "installing golang: failed." \
  "installing golang: successful."

# TODO: Setup git config
# TODO: Setup docker, python, node
