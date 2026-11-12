# AWS Emulator on Podman

Run AWS Emulator locally on an Apple silicon Mac. This setup builds the ARM image with Podman and starts it with Podman Compose.

The emulator listens on `https://127.0.0.1:9297`. It stores emulated resources in memory, so they are lost when the emulator stops.

## Install the tools

You need an Apple silicon Mac. You do not need an AWS account to run the emulator.

1. Install [Homebrew](https://brew.sh/) if you do not have it. Follow its post-installation instructions to add `brew` to your shell.
2. Open Terminal and install Podman and Podman Compose:

   ```bash
   brew install podman podman-compose
   ```

3. If you do not have a Podman machine, create and start one:

   ```bash
   podman machine init --rootful --memory 4096
   podman machine start
   ```

   This creates a Linux virtual machine with 4 GiB of memory. The example uses rootful mode to match the tested setup. In this mode, Podman runs with root privileges inside the virtual machine. The emulator process still runs as a non-root user.

4. If you want the AWS CLI for the examples below, install it with `brew install awscli`. You can use an AWS SDK instead.
5. If you want Topgrade to rebuild the image during your updates, install it with `brew install topgrade` and follow [Update the image](#update-the-image).

If you already have a Podman machine, use `podman machine list` to see its status. If it is stopped, run `podman machine start`.

The launcher expects Podman and Podman Compose at `/opt/homebrew/bin/podman` and `/opt/homebrew/bin/podman-compose`. If your installation uses different paths, update `start.command`.

## Start the emulator

The commands below assume that this folder is `~/Documents/AWS Emulator`. If it is elsewhere, use its path instead.

If the shared directory does not exist, create it:

```bash
mkdir -p "$HOME/.aws/emulator"
```

Double-click `start.command` in Finder. Alternatively, run:

```bash
cd "$HOME/Documents/AWS Emulator"
./start.command
```

The first launch builds the image if it is not already present. The launcher keeps an existing container instead of recreating it. It also sets the memory and swap limits to 2 GiB in total.

Make sure that the emulator is ready:

```bash
curl --fail --cacert "$HOME/.aws/emulator/9297/ca.pem" \
  https://127.0.0.1:9297/__admin/health
```

The response is `ok`. The emulator creates the certificate and credentials in `~/.aws/emulator/9297/` when it starts.

## Connect an AWS SDK or the AWS CLI

Use a separate terminal for emulator work. In that terminal, clear any existing credentials and set the emulator variables:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE
export AWS_ENDPOINT_URL=https://127.0.0.1:9297
export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/emulator/9297/emulator_credentials"
export AWS_CONFIG_FILE="$HOME/.aws/emulator/9297/config"
export AWS_CA_BUNDLE="$HOME/.aws/emulator/9297/ca.pem"
export AWS_EC2_METADATA_DISABLED=true
export AWS_DISABLE_HOST_PREFIX_INJECTION=true
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
```

If you installed the AWS CLI, make sure that the account is correct before you run your tests:

```bash
aws sts get-caller-identity
```

The emulator returns account `000000000000` and the ARN `arn:aws:iam::000000000000:user/emulator`. If you see your own account, stop and examine the environment variables.

> [!IMPORTANT]
> If `AWS_ENDPOINT_URL` is not set in the terminal that runs your tests, requests can go to AWS. Use the emulator variables only in a dedicated terminal. Close that terminal when you finish.

Some SDKs need an additional setting to trust the emulator certificate. See [Pointing your AWS SDK at AWS Emulator](https://docs.aws.amazon.com/emulator/latest/userguide/point-sdk-to-emulator.html).

## Update the image

You can add a custom command to Topgrade to rebuild the image. It pulls the latest Amazon Linux base image and downloads the latest ARM package. It does not stop the running emulator.

Create `~/.config/topgrade.toml` if it does not exist. If `~/.config` does not exist, create it with `mkdir -p "$HOME/.config"`. Add the following section to the file. If the file already has a `[commands]` section, add only the entry under that heading. Change the paths if needed.

```toml
[commands]
"AWS Emulator" = '/opt/homebrew/bin/podman-compose --podman-path /opt/homebrew/bin/podman -f "$HOME/Documents/AWS Emulator/compose.yaml" build --pull=always --no-cache'
```

Run `topgrade` to rebuild the image with your other updates.

To rebuild manually:

```bash
cd "$HOME/Documents/AWS Emulator"
podman-compose build --pull=always --no-cache
```

> [!WARNING]
> The current container keeps using its existing image after a rebuild. To use the new image, remove the container and start it again. This deletes all emulated resources in memory.

```bash
cd "$HOME/Documents/AWS Emulator"
podman-compose down
./start.command
```

The package installation has reported an `NOKEY` warning. The current `Containerfile` does not verify the RPM signature against an imported signing key.

## Stop and troubleshoot

To stop and remove the container, run `podman-compose down` from this folder. This deletes all emulated resources in memory.

To inspect the container or read its logs, run:

```bash
cd "$HOME/Documents/AWS Emulator"
podman-compose ps
podman-compose logs --tail 100
```

If the health check fails, make sure that the Podman machine is running and that port `9297` is available. The emulator binds this port to the local machine only.

## Files

| File | Purpose |
| --- | --- |
| `Containerfile` | Builds the Amazon Linux image with the ARM emulator package. |
| `compose.yaml` | Defines the image, local port, shared directory and memory limits. |
| `start.command` | Starts the container without recreating a running instance. |

For more details, see [AWS Emulator: Getting started with Docker](https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-docker.html).
