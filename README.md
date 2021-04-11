# remote

Helps you create your own remote web development environment.

## Pre-requisities

- Bash Shell. For windows, you can use [Windows Terminal](https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701) or [Git Bash](https://git-scm.com/downloads).
- Your local SSH key pair. See [GitHub's guide](https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
- A [Keybase](https://keybase.io/) account for storing your GPG keys.
- A [Linode account](https://www.linode.com/?r=b042b8d928111627044d292bdbca3691c536bf8d). You can go to their [docs](https://www.linode.com/docs/guides/getting-started/) to get a $100 promo code. 

## Generate SSH Key Pair

Follow [GitHub's guide](https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) to generate your SSH key pair. Afterwards, add the key to your GitHub account.

For Windows users, you can check this [guide](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement). For posterity, you can run this in an elevated PowerShell prompt to enable the `ssh-agent`:

```
# Install the OpenSSHUtils module to the server. This will be valuable when deploying user keys.
Install-Module -Force OpenSSHUtils -Scope AllUsers

# By default the ssh-agent service is disabled. Allow it to be manually started for the next step to work.
Get-Service -Name ssh-agent | Set-Service -StartupType Manual

# Start the ssh-agent service to preserve the server keys
Start-Service ssh-agent

# Now start the sshd service
Start-Service sshd
```

## Creating your StackScripts

- Open the [StackScripts](https://cloud.linode.com/stackscripts/account) page and click **Create StackScript**.
- Copy the contents of [web.sh](./linode/web.sh). This will only work on **Debian 10**.
- Click **Deploy New Linode**.
