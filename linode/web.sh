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
# <UDF name="UPGRADE_SHELL_EXPERIENCE" label="Upgrade shell experience? Uses zsh, oh-my-zsh, and powerlevel10k." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_KEYBASE" label="Install Keybase? See https://keybase.io for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_GOLANG" label="Install the Go Programming Language? See https://golang.org for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_NVM" label="Install Node Version Manager? See https://github.com/nvm-sh/nvm for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_DOCKER" label="Install docker? See https://www.docker.com for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_HOMEBREW" label="Install homebrew? See https://brew.sh for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_PYENV" label="Install pyenv? See https://github.com/pyenv/pyenv for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_BYOBU" label="Install byobu? See https://byobu.org for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_SPACEVIM" label="Install spacevim? See https://spacevim.org for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_BAT" label="Install bat? See https://github.com/sharkdp/bat for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_DIRENV" label="Install direnv? See https://direnv.net/ for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_LAZYGIT" label="Install lazygit? Requires Go to be installed. See https://github.com/jesseduffield/lazygit for more details." oneof="yes,no" default="yes" />
# <UDF name="INSTALL_STOW" label="Install stow? See https://www.gnu.org/software/stow for more details." oneof="yes,no" default="yes" />
# <UDF name="SYSTEM_TIMEZONE" label="Choose system timezone." default="Asia/Manila" example="Asia/Manila" />
# <UDF name="SYSTEM_PUBLIC_KEY" label="If you want to copy a specific SSH key identity, put the PUBLIC_KEY here. Otherwise, leave this blank." example="ssh-ed25519 AAAA...zzzz name@email.com" />
# <UDF name="SYSTEM_PRIVATE_KEY" label="If you want to copy a specific SSH key identity, put the PRIVATE_KEY here. Otherwise, leave this blank." example="-----BEGIN OPENSSH PRIVATE KEY----- ... -----END OPENSSH PRIVATE KEY-----" />

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

  local DEFAULT_SHELL=/bin/bash
  if [ "$UPGRADE_SHELL_EXPERIENCE" = "yes" ]; then
    DEFAULT_SHELL=$(which zsh)
  fi

  useradd -mG sudo \
    -s $DEFAULT_SHELL \
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
        chmod -R 700 /home/$USERNAME/.ssh
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
    
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh && \
      chmod -R 700 /home/$USERNAME/.ssh
    ret=$((ret+$?))

    # Install keychain for ssh-agent convenience:
    #  https://stackoverflow.com/a/24902046
    #  https://unix.stackexchange.com/a/90869
    apt update -y && \
      apt --fix-broken install -y && \
      apt install -y keychain
    ret=$((ret+$?))
    
    # Create a .zlogin file that is sourced in login shells.
    echo "
# keychain
eval \$(keychain --quiet --nogui --noask --clear --agents ssh --eval $HOSTNAME)
source ~/.keychain/$HOSTNAME-sh
" >> /home/$USERNAME/.profile
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

install_essentials() {
  local ret=0
  
  apt update -y && \
    apt --fix-broken install -y && \
    apt install -y build-essential procps curl file tree git
  ret=$((ret+$?))
  
  if [ "$UPGRADE_SHELL_EXPERIENCE" = "yes" ]; then
    apt update -y && \
      apt --fix-broken install -y && \
      apt install -y zsh
    ret=$((ret+$?))
  fi
  
  return $ret
}

# This is still a work in progress.
install_latest_git() {
  local ret=0
  
  # Install the latest non-rc version of git.
  # From https://git-scm.com/book/en/v2/Getting-Started-Installing-Git.
  
  apt update -y && \
    apt --fix-broken install -y && \
    apt install -y dh-autoreconf libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev asciidoc xmlto docbook2x install-info && \
    curl -s https://api.github.com/repos/git/git/tags | grep -E 'tarball_url' | grep -v 'rc' | head -1 | cut -d '"' -f 4 | wget -qi - -O /tmp/git.tar.gz && \
    mkdir -p /tmp/git && \
    tar -C /tmp/git -xzf /tmp/git.tar.gz && \
    TMP_GIT_DIR=$(ls -d /tmp/git/*/ | head -n 1) && \
    GIT_SRC_DIR=${TMP_GIT_DIR%/} && \
    make -C $GIT_SRC_DIR configure && \
    $GIT_SRC_DIR/configure --prefix=/usr && \
    make -C $GIT_SRC_DIR all doc info && \
    make -C $GIT_SRC_DIR install install-doc install-html install-info
  ret=$((ret+$?))
  
  return $ret
}

install_keybase() {
  local ret=0

  wget https://prerelease.keybase.io/keybase_amd64.deb -O /tmp/keybase_amd64.deb
  ret=$?
  dpkg --force-confold -i /tmp/keybase_amd64.deb
  ret=$((ret+$?))
  rm /tmp/keybase_amd64.deb
  ret=$((ret+$?))

  return $ret
}

install_golang() {
  local ret=0

  wget "https://golang.org/dl/$(curl https://golang.org/VERSION?m=text).linux-amd64.tar.gz" -O /tmp/golang.tar.gz && \
    tar -C /usr/local -xzf /tmp/golang.tar.gz && \
    rm /tmp/golang.tar.gz
  ret=$((ret+$?))

  echo "
# go
export GOPATH=/home/$USERNAME/.go
export PATH=\$PATH:/usr/local/go/bin:\$GOPATH/bin
" >> /home/$USERNAME/.profile
  ret=$((ret+$?))
  
  return $ret
}

install_nvm() {
  local ret=0
  
  # NOTE: nvm is not meant to be install globally so we will run the command as the non-root user.
  # If you want that functionality, maybe you can use https://github.com/tj/n.
  export NVM_DIR="/home/$USERNAME/.nvm" && (
    git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    # Checkout the latest versioned release.
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
    chown -R $USERNAME:$USERNAME "$NVM_DIR"
    chmod +x "$NVM_DIR/nvm.sh"
  ) && runuser -u $USERNAME -- /bin/bash -c "$NVM_DIR/nvm.sh" 
  
  echo '
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
' >> /home/$USERNAME/.zshenv
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
  
  # Install zsh plugins: autocomplete and syntax highlighting.
  git clone https://github.com/zsh-users/zsh-autosuggestions /usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting /usr/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    sed -i 's/plugins=(\(\w\+\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/g' /usr/share/oh-my-zsh/zshrc
  ret=$((ret+$?))
  
  # Add a function to reload the zsh config.
  echo '
# Manually reloads the zsh configuration files.
function reload() {
  [ -s ~/.zshenv ] && \. ~/.zshenv
  [ -s ~/.zprofile ] && \. ~/.zprofile
  [ -s ~/.zshrc ] && \. ~/.zshrc
}' >> /usr/share/oh-my-zsh/zshrc

  # Copy this to the skeleton templates directory.
  ln /usr/share/oh-my-zsh/zshrc /etc/skel/.zshrc
  ret=$((ret+$?))
  
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

install_homebrew() {
  local ret=0
  
  # Installs homebrew on /home/linuxbrew/.linuxbrew.
  mkdir -p /home/linuxbrew/.linuxbrew && \
    chown -R $USERNAME:$USERNAME /home/linuxbrew/.linuxbrew
  ret=$((ret+$?))
  
  # We are using runuser here since it will error out when su is used.
  # echo | <command> simulates pressing [ENTER].
  echo | runuser -u $USERNAME -- /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ret=$((ret+$?))
  
  echo '
# brew
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
' >> /home/$USERNAME/.profile

  return $ret
}

install_pyenv() {
  local ret=0
  
  # Install pyenv for the non-root user.
  export PYENV_DIR="/home/$USERNAME/.pyenv" && (
    git clone --depth 1 https://github.com/pyenv/pyenv.git $PYENV_DIR
    # Try to compile dynamic bash extension to speed up pyenv.
    $PYENV_DIR/src/configure && make -C $PYENV_DIR/src
  ) && chown -R $USERNAME:$USERNAME $PYENV_DIR
  
  git clone https://github.com/pyenv/pyenv.git ~/.pyenv
  ret=$((ret+$?))
  
  echo '
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init --path)"
fi
' >> /home/$USERNAME/.profile

  return $ret
}

install_byobu() {
  local ret=0
  
  # Install from apt.
  apt update -y && \
    apt --fix-broken install -y && \
    apt install -y byobu

  # Add byobu to the list of shells.
  which byobu | tee -a /etc/shells
  ret=$((ret+$?))
  
  # Enable byobu on login.
  echo "
# byobu
_byobu_sourced=1 . /usr/bin/byobu-launch 2>/dev/null || true
" >> /home/$USERNAME/.profile
  ret=$((ret+$?))
  
  # Fix the reuse session bug.
  local BYOBU_DIR="/home/$USERNAME/.byobu"
  mkdir -p $BYOBU_DIR && \
    touch $BYOBU_DIR/.reuse-session
  ret=$((ret+$?))
  
  # Fix byobu closes window when pressing q on F1/F9 screen.
  grep new-window /usr/share/byobu/keybindings/f-keys.tmux \
    | grep ' -k' \
    | sed -e 's/ -k/ -ak/' \
    >> $BYOBU_DIR/keybindings.tmux
  
  # Set the default shell to use.
  local DEFAULT_SHELL=/bin/bash
  if [ "$UPGRADE_SHELL_EXPERIENCE" = "yes" ]; then
    DEFAULT_SHELL=$(which zsh)
  fi
  echo "
set -g default-shell $DEFAULT_SHELL
set -g default-command $DEFAULT_SHELL
" >> $BYOBU_DIR/.tmux.conf
  ret=$((ret+$?))
  
  # Make sure the non-root user is the owner of the files.
  chown -R $USERNAME:$USERNAME $BYOBU_DIR
  ret=$((ret+$?))

  return $ret
}

install_spacevim() {
  local ret=0
  
  # Install vim-gtk3 for debian to fix blank guide buffer issue.
  apt update -y && \
    apt --fix-broken install -y && \
    apt install -y neovim vim-gtk3
  ret=$((ret+$?))

  runuser -u $USERNAME -- /bin/bash -c "$(curl -fsSL https://spacevim.org/install.sh)"
  ret=$((ret+$?))
  
  # Manually build vimproc to prevent errors (it happens).
  runuser -u $USERNAME -- make -C /home/$USERNAME/.SpaceVim/bundle/vimproc.vim/
  ret=$((ret+$?))
 
  return $ret
}

install_bat() {
  local ret=0

  # Download the latest non-musl release for amd64 machines.
  curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | grep -E 'browser_download_url' | grep amd64 | grep -v musl | cut -d '"' -f 4 | wget -qi - -O /tmp/bat_amd64.deb
  ret=$((ret+$?))
  dpkg --force-confold -i /tmp/bat_amd64.deb
  ret=$((ret+$?))
  rm /tmp/bat_amd64.deb
  ret=$((ret+$?))
 
  return $ret
}

install_direnv() {
  local ret=0

  # Download the latest release for linux amd64 machines.
  curl -s https://api.github.com/repos/direnv/direnv/releases/latest | grep -E 'browser_download_url' | grep linux-amd64 | cut -d '"' -f 4 | wget -qi - -O /usr/local/bin/direnv
  ret=$((ret+$?))
  chmod +x /usr/local/bin/direnv
  ret=$((ret+$?))
  
  # Add hook.
  if [ "$UPGRADE_SHELL_EXPERIENCE" = "yes" ]; then
    echo "
# direnv
emulate zsh -c \"\$(direnv hook zsh)\"
" >> /home/$USERNAME/.zshrc
    echo "
emulate zsh -c \"\$(direnv export zsh)\"
" >> /home/$USERNAME/.zshenv
  else
    echo "
# direnv
eval \"\$(direnv hook bash)\"
" >> /home/$USERNAME/.bashrc
  fi
  ret=$((ret+$?))
 
  return $ret
}

install_lazygit() {
  local ret=0

  # Installs Go if not yet installed.
  [ "$INSTALL_GOLANG" = "no" ] && {
    log "install_golang" \
      "installing golang: failed." \
      "installing golang: successful."
  }
  ret=$((ret+$?))

  go get github.com/jesseduffield/lazygit
  ret=$((ret+$?))
 
  return $ret
}

install_stow() {
  local ret=0
  
  # Install from apt.
  apt update -y && \
    apt --fix-broken install -y && \
    apt install -y stow
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
    # Use zsh by default.
    sed -i 's/DSHELL=\/bin\/bash/DSHELL=\/bin\/zsh/g' /etc/adduser.conf
  
    # Create a .zprofile file that loads the values from .profile.
    echo "[[ -e ~/.profile ]] && emulate sh -c 'source ~/.profile'" >> /etc/skel/.zshenv
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

# Installs the essential applications.
log "install_essentials" \
  "installing essential applications: failed." \
  "installing essential applications: successful."

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

[ "$INSTALL_KEYBASE" = "yes" ] && {
  log "install_keybase" \
    "installing keybase: failed." \
    "installing keybase: successful."
}

[ "$INSTALL_GOLANG" = "yes" ] && {
  log "install_golang" \
    "installing golang: failed." \
    "installing golang: successful."
}

[ "$INSTALL_NVM" = "yes" ] && {
  log "install_nvm" \
    "installing nvm: failed." \
    "installing nvm: successful."
}

[ "$INSTALL_DOCKER" = "yes" ] && {
  log "install_docker" \
    "installing docker: failed." \
    "installing docker: successful."
}

[ "$INSTALL_PYENV" = "yes" ] && {
  log "install_pyenv" \
    "installing pyenv: failed." \
    "installing pyenv: successful."
}

[ "$INSTALL_BYOBU" = "yes" ] && {
  log "install_byobu" \
    "installing byobu: failed." \
    "installing byobu: successful."
}

[ "$INSTALL_SPACEVIM" = "yes" ] && {
  log "install_spacevim" \
    "installing spacevim: failed." \
    "installing spacevim: successful."
}

[ "$INSTALL_BAT" = "yes" ] && {
  log "install_bat" \
    "installing bat: failed." \
    "installing bat: successful."
}

[ "$INSTALL_DIRENV" = "yes" ] && {
  log "install_direnv" \
    "installing direnv: failed." \
    "installing direnv: successful."
}

[ "$INSTALL_LAZYGIT" = "yes" ] && {
  log "install_lazygit" \
    "installing lazygit: failed." \
    "installing lazygit: successful."
}

[ "$INSTALL_STOW" = "yes" ] && {
  log "install_stow" \
    "installing stow: failed." \
    "installing stow: successful."
}

# Moving this at the bottom since it takes too long.
[ "$INSTALL_HOMEBREW" = "yes" ] && {
  log "install_homebrew" \
    "installing homebrew: failed." \
    "installing homebrew: successful."
}
