# remote

Helps you create your own remote web development environment.

## Pre-requisities

- Bash Shell. For windows, you can use [Windows Terminal](https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701) or [Git Bash](https://git-scm.com/downloads).
- Your local SSH key pair. See [GitHub's guide](https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
- A [GitHub](https://github.com) account.
- A [Keybase](https://keybase.io/) account for storing your GPG keys.
- A [Linode account](https://www.linode.com/?r=b042b8d928111627044d292bdbca3691c536bf8d). You can go to their [docs](https://www.linode.com/docs/guides/getting-started/) to get a $100 promo code.
- [Visual Studio Code](https://code.visualstudio.com/).

## Generate SSH Key for your local machine

Follow [GitHub's guide](https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) to generate your SSH key pair. For Windows users, you may need to check this [guide from Microsoft](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement) to enable SSH in your machine.

Afterwards, add the key to your GitHub and Linode account.

## Generate SSH Key for your new Linode instance

Create a new SSH Key for your new Linode instance. Save this for now as we'll use this later.

## Generate GPG Key

Follow this [guide to generate a GPG key using Keybase](https://github.com/pstadler/keybase-gpg-github).

**NOTE**: For Windows, if you already installed the Keybase app, you should have the CLI app will be ready to use (no need to install via brew).

Again, you need to add this key to your GitHub account.

## Creating your server instance using Linode's StackScripts

- Open the [StackScripts](https://cloud.linode.com/stackscripts/account) page and click **Create StackScript**.
- Copy the contents of [web.sh](./linode/web.sh). This will only work on **Debian 10**.
- Click **Deploy New Linode**.
- Fill out the fields and then click **Create Linode**.
- Wait for your instance to be provisioned.
- If all goes well, the status will change to **Running** and you can then connect to your instance.

## Connecting via SSH

Start the ssh-agent in the background:

```bash
# linux/macos

$ eval `ssh-agent -s`
> Agent pid 59566
```

```powershell
# windows

Start-Service ssh-agent
```

Add your SSH private key to the ssh-agent. If you created your key with a different name, or if you are adding an existing key that has a different name, replace id_ed25519 in the command with the name of your private key file.

```bash
ssh-add ~/.ssh/id_ed25519
```

Then connect via SSH:

```bash
ssh <NON_ROOT_USERNAME>@<LINODE_IPV4_ADDRESS> -p <SSH_PORT>
```

Congratulations! You can now connect to your remote server instance.

## Additional setup

The essentials are already installed in your instance. However, we need to configure a few applications we will use.

### Enable Zsh

```bash
zsh
```

This will also let you set up the [powerlevel10k zsh theme](https://github.com/romkatv/powerlevel10k).

**TODO**: Add instructions how to set up your terminal in Windows.

### Configure Keybase

```bash
# login
keybase login

# check if you have more than one key saved
keybase pgp export

# if yes, specify the id in the commands below
# keybase pgp export -q 31DBBB1F6949DA68 | gpg --import

# import public key
keybase pgp export | gpg --import

# import private key
keybase pgp export --secret | gpg --allow-secret-key-import --import

# check imported key
gpg --list-secret-keys --keyid-format LONG
# /Users/pstadler/.gnupg/secring.gpg
# ----------------------------------
# sec   4096R/E870EE00 2016-04-06 [expires: 2032-04-02]
# uid                  Patrick Stadler <patrick.stadler@gmail.com>
# ssb   4096R/F9E3E72E 2016-04-06
```

Notice the hash `E870EE00`. We will use this in the next section.

### Configure Git

```bash
# add your basic information
git config --global user.name "Your Name"
git config --global user.email "your_name@example.com"

# sign all commits using your GPG key
git config --global user.signingkey E870EE00
git config --global commit.gpgsign true
```
