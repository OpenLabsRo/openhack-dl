# OpenHack Downloads

Static assets for distributing CLI tooling such as `hyperctl`. Deploy this folder to Vercel. Files placed under `public/` will be exposed as-is, so the installer script is available at `/hyperctl_install.sh`.

## Structure

- `public/hyperctl_install.sh` – Linux amd64 installer that fetches the latest `hyperctl` release from GitHub and installs it into `/usr/local/bin` by default.
- `public/index.html` – human-friendly landing page with usage instructions.

## Deployment

1. Connect this repository to Vercel and deploy as a static project. Vercel automatically serves the `public/` directory.
2. (Optional) Map the Vercel project to `dl.openhack.org` for clearer download URLs.

## Updating the HyperCTL Release

1. Build and upload the `hyperctl-linux-amd64` asset to a GitHub release in the [`openlabs-hq/hyperctl`](https://github.com/openlabs-hq/hyperctl) repository.
2. The installer points to `https://github.com/openlabs-hq/hyperctl/releases/latest/download/hyperctl-linux-amd64`, so no repository changes are needed when you publish new releases.
3. If you change the asset name or release location, update the installer script accordingly.

## Local Testing

```sh
sh public/hyperctl_install.sh
```

Override `INSTALL_DIR` if you do not want to write to `/usr/local/bin` in your development environment.
