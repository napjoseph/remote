#!/bin/bash

set -eu

export DEBIAN_FRONTEND="noninteractive"

# <UDF name="HOSTNAME" label="The hostname for the machine." default="localhost" example="localhost" />
# <UDF name="HOSTNAME_APPEND_LINODE_ID" label="Append the Linode ID to the hostname?" oneof="yes,no" default="yes" />
# <UDF name="USERNAME" label="The username of the default non-root user." default="" example="user" />
# <UDF name="PASSWORD" label="The password of the default non-root user." default="" example="password" />
# <UDF name="SSH_PORT" label="Sets the SSH port. This won't be reflected in your Linode Dashboard." default="22" example="22" />
# <UDF name="LOCK_ROOT_ACCOUNT" label="Lock the root account?" oneof="yes,no" default="yes" />
# <UDF name="UPGRADE_DEBIAN" label="Upgrade the system automatically?" oneof="yes,no" default="yes" />
# <UDF name="GOLANG_VERSION" label="Version of Go you want to install. Check the list at https://golang.org/dl/." default="go1.16.3.linux-amd64" />
# <UDF name="UPGRADE_SHELL_EXPERIENCE" label="Upgrade shell experience? Uses zsh and oh-my-zsh." oneof="yes,no" default="yes" />
# <UDF name="SYSTEM_TIMEZONE" label="Choose system timezone." default="Asia/Manila" example="Asia/Manila" />
# <UDF name="SYSTEM_PUBLIC_KEY" label="If you want to copy a specific SSH key identity, put the public key here. Otherwise, leave this blank." example="ssh-ed25519 AAAA...zzzz name@email.com" />
# <UDF name="SYSTEM_PRIVATE_KEY" label="If you want to copy a specific SSH key identity, put the private key here. Otherwise, leave this blank." example="-----BEGIN OPENSSH PRIVATE KEY----- ... -----END OPENSSH PRIVATE KEY-----" />

if [ "$HOSTNAME_APPEND_LINODE_ID" = "yes" ]; then
  HOSTNAME="$HOSTNAME-$LINODE_ID"
fi

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
  ret=$((ret+$?))
  
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
      ret=$((ret+$?))
    else
      sedopts="$sedopts -e 's/.*(PermitRootLogin) .+/\1 yes/'"
    fi
    
    sedopts="$sedopts -e 's/.*(PasswordAuthentication) .+/\1 no/'"
  else
    sedopts="$sedopts -e 's/.*(PasswordAuthentication) .+/\1 yes/'"
  fi
  
  # When provided, copy the system public and private SSH keys to the newly created user's .ssh directory.
  if [ "$USERNAME" ] && [ "$SYSTEM_PUBLIC_KEY" ] && [ "$SYSTEM_PRIVATE_KEY" ]; then
    echo ${SYSTEM_PUBLIC_KEY} >> /home/$USERNAME/.ssh/$HOSTNAME.pub
    echo ${SYSTEM_PRIVATE_KEY} >> /home/$USERNAME/.ssh/$HOSTNAME

    # Install keychain for ssh-agent convenience:
    #  https://stackoverflow.com/a/24902046
    #  https://unix.stackexchange.com/a/90869
    apt-get -y install keychain
    ret=$((ret+$?))
  fi

  eval sed $sedopts
  ret=$((ret+$?))
  systemctl restart ssh
  ret=$((ret+$?))

  return $ret
}

config_hostname() {
  local ret=0

  hostnamectl set-hostname $HOSTNAME
  ret=$?
  sed -i "s/127.0.0.1	localhost/127.0.0.1	localhost $HOSTNAME/" /etc/hosts
  ret=$((ret+$?))

  return $ret
}

upgrade_debian () {
  apt update -y && \
    apt upgrade -y
}

config_timezone() {
  if [ "$SYSTEM_TIMEZONE" = "" ]; then
    SYSTEM_TIMEZONE="Asia/Manila"
  fi

  timedatectl set-timezone $SYSTEM_TIMEZONE
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

  wget https://golang.org/dl/$GOLANG_VERSION.tar.gz -O /tmp/$GOLANG_VERSION.tar.gz && \
    tar -C /usr/local -xzf /tmp/$GOLANG_VERSION.tar.gz && \
    rm /tmp/$GOLANG_VERSION.tar.gz
  ret=$((ret+$?))

  echo "export PATH=$PATH:/usr/local/go/bin" >> /home/$USERNAME/.profile && \
    echo "export GOPATH=/home/$USERNAME/.go" >> /home/$USERNAME/.profile
  ret=$((ret+$?))
  
  return $ret
}

upgrade_shell_experience() {
  local ret=0
  
  # Install oh-my-zsh.
  # Modified from https://stackoverflow.com/questions/31624649/how-can-i-get-a-secure-system-wide-oh-my-zsh-configuration/61917655#61917655
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh && \
    cp /usr/share/oh-my-zsh/templates/zshrc.zsh-template /usr/share/oh-my-zsh/zshrc && \
    mkdir -p /etc/skel/.oh-my-zsh/cache && \
    sed -i 's/export ZSH=$HOME\/.oh-my-zsh/export ZSH=\/usr\/share\/oh-my-zsh/g' /usr/share/oh-my-zsh/zshrc  && \
    sed -i 's/# DISABLE_AUTO_UPDATE="true"/DISABLE_AUTO_UPDATE="true"/g' /usr/share/oh-my-zsh/zshrc  && \
    sed -i 's/source $ZSH\/oh-my-zsh.sh//g' /usr/share/oh-my-zsh/zshrc && \
    echo '

ZSH_CACHE_DIR=$HOME/.cache/oh-my-zsh
if [[ ! -d $ZSH_CACHE_DIR ]]; then
  mkdir -p $ZSH_CACHE_DIR
fi

source $ZSH/oh-my-zsh.sh
' >> /usr/share/oh-my-zsh/zshrc
  ret=$((ret+$?))
  
  # Install the powerlevel10k theme.
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /usr/share/oh-my-zsh/custom/themes/powerlevel10k && \
    sed -i 's/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"powerlevel10k\/powerlevel10k\"/g' /usr/share/oh-my-zsh/zshrc
  ret=$((ret+$?))
  
  # Install oh-my-zsh autocomplete.
  git clone https://github.com/zsh-users/zsh-autosuggestions /usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    sed -i 's/plugins=(\(\w\+\))/plugins=(\1 zsh-autosuggestions)/g' /usr/share/oh-my-zsh/zshrc
  ret=$((ret+$?))
  
  # Copy this to the skeleton templates directory.
  ln /usr/share/oh-my-zsh/zshrc /etc/skel/.zshrc && \
    sed -i 's/DSHELL=\/bin\/bash/DSHELL=\/bin\/zsh/g' /etc/adduser.conf
  ret=$((ret+$?))
  
  # Change the default shell of the non-root user to zsh.
  chsh -s /usr/bin/zsh ${USERNAME}
  
  return $ret
}

install_docker() {
  local ret=0
  
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && \
    sh /tmp/get-docker.sh && \
    usermod -aG docker $USERNAME
  ret=$((ret+$?))
  
  return $ret
}

update_skel_files() {
  local ret=0
  
  # The initialization files used in bash can be (okay, it IS) confusing.
  # See https://medium.com/@rajsek/zsh-bash-startup-files-loading-order-bashrc-zshrc-etc-e30045652f2e
  
  # Define the tty for gpg. Without this you will get "Inappropriate ioctl for device" errors.
  echo '
GPG_TTY=$(tty)
export GPG_TTY
' >> /etc/skel/.profile
  ret=$((ret+$?))
  
  # Use vim as the default editor.
  echo '
export VISUAL=vim
export EDITOR="$VISUAL"
' >> /etc/skel/.profile
  ret=$((ret+$?))
  
  if [ "$UPGRADE_SHELL_EXPERIENCE" = "yes" ]; then
    # Create a .zprofile file that loads the values from .profile.
    echo "[[ -e ~/.profile ]] && emulate sh -c 'source ~/.profile'" >> /etc/skel/.zprofile
    ret=$((ret+$?))

    # Create a .zlogin file that is sourced in login shells.
    echo "eval `keychain --agents ssh --eval $HOSTNAME --quiet --nogui --noask --clear`" >>  /etc/skel/.zlogin
    ret=$((ret+$?))
  fi
  
  return $ret
}

log "config_timezone" \
  "updating timezone: failed." \
  "updating timezone: successful."

log "config_hostname" \
  "updating hostname: failed." \
  "updating hostname: successful."

[ "$UPGRADE_DEBIAN" = "yes" ] && {
  log "upgrade_debian" \
    "upgrading system: failed." \
    "upgrading system: successful."
}

# Updates the packages on the system from the distribution repositories.
log "apt-get update" \
  "updating distribution repositories: failed." \
  "updating distribution repositories: successful."

# Installs the essential applications.
log "apt-get -y install build-essential git tree zsh" \
  "installing applications: failed." \
  "installing applications: successful."

[ "$UPGRADE_SHELL_EXPERIENCE" = "yes" ] && {
  log "upgrade_shell_experience" \
    "upgrading shell experience: failed." \
    "upgrading shell experience: successful."
}

log "update_skel_files" \
  "updating skel files: failed." \
  "updating skel files: successful."

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

log "install_keybase" \
  "installing keybase: failed." \
  "installing keybase: successful."

log "install_golang" \
  "installing golang: failed." \
  "installing golang: successful."

log "install_docker" \
  "installing docker: failed." \
  "installing docker: successful."

# TODO: Setup brew, python, node
