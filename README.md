# remote

Helps you create your own remote web development environment.

## Pre-requisities

- Bash. You can use [Git Bash](https://git-scm.com/downloads) or [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10).
- Your local SSH Key. See [GitHub's guide](https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
- A [Keybase](https://keybase.io/) account for storing your GPG keys.
- A [Linode](https://www.linode.com/?r=b042b8d928111627044d292bdbca3691c536bf8d) account. You can go to their [docs](https://www.linode.com/docs/guides/getting-started/) to get a $100 promo code. 

## Creating your StackScripts

- Open the [StackScripts](https://cloud.linode.com/stackscripts/account) page and click **Create StackScript**.
- Copy the contents of [first-boot.sh](./linode/first-boot.sh). This will only work on **Debian 10**.
- Click **Deploy New Linode**.
