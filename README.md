# remote

Helps you create your own remote web development environment.

## Pre-requisities

- Bash Shell. For windows, you can use [Windows Terminal](https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701) or [Git Bash](https://git-scm.com/downloads).
- Your local SSH key pair. See [GitHub's guide](https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
- A [Keybase](https://keybase.io/) account for storing your GPG keys.
- A [Linode account](https://www.linode.com/?r=b042b8d928111627044d292bdbca3691c536bf8d). You can go to their [docs](https://www.linode.com/docs/guides/getting-started/) to get a $100 promo code. 

## Creating your StackScripts

- Open the [StackScripts](https://cloud.linode.com/stackscripts/account) page and click **Create StackScript**.
- Copy the contents of [web.sh](./linode/web.sh). This will only work on **Debian 10**.
- Click **Deploy New Linode**.
