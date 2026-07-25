# iPad Tailscale SSH Bridge

This bridge lets a GitHub-hosted Actions runner join the same Tailscale network as the iPad, connect to `100.116.117.65:22` as `mobile`, elevate with `sudo`, run `remote/ipad-command.sh`, and save the terminal output as a workflow artifact.

## One-time setup

### 1. Create a Tailscale auth key

In the Tailscale admin console, create an auth key for the GitHub runner.

Recommended settings:

- Reusable
- Ephemeral
- Pre-approved if device approval is enabled
- Tagged with a restricted CI tag when possible
- Short expiration

### 2. Add two GitHub Actions secrets

Open this repository's **Settings → Secrets and variables → Actions** and add:

- `TAILSCALE_AUTHKEY` — the Tailscale auth key
- `IPAD_PASSWORD` — the iPad `mobile` SSH password; the workflow also supplies it to `sudo`

Never put either value in `remote/ipad-command.sh`, commits, issues, workflow inputs, or build logs.

## Run a command

Edit `remote/ipad-command.sh` on the `main` branch. A push affecting that file automatically starts **iPad Tailscale SSH Bridge**.

The workflow:

1. Joins the tailnet as an ephemeral runner.
2. Waits for Tailscale connectivity to `100.116.117.65`.
3. Reads the iPad SSH host key over Tailscale.
4. Logs in as `mobile` on port `22`.
5. Runs the command file through `sudo /bin/sh`.
6. Uploads `ipad-output.txt` for seven days.

The workflow can also be started manually from the Actions tab; a manual run executes the current contents of `remote/ipad-command.sh`.

## iPad requirements

- Tailscale connected with incoming connections allowed.
- OpenSSH server listening on port `22`.
- The `mobile` account can log in with the configured password.
- `sudo` is installed and accepts the same configured password.

## Security

- The repository is public, so command files and commit history are public. Never write credentials or private data into the command file.
- Keep the Tailscale key and iPad password only in GitHub encrypted secrets.
- Revoke the Tailscale auth key to disable future runner access.
- Disable or delete `.github/workflows/ipad-tailscale-ssh.yml` to remove the bridge.
