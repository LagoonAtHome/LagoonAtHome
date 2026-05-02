# Lagoon At Home

<p align="center">
 <img src="./docs/assets/bluelagoon.svg" alt="The Lagoon logo is a blue triangle split in two pieces with an L-shaped cut" width="40%">
</p>

A lightweight distribution of [Lagoon](https://lagoon.sh) tailored for bare-metal setups, particularly homelabs.

> **Status: Alpha.** Expect rough edges. Use on disposable hardware until things stabilise.

## What it is

LagoonAtHome bundles Lagoon Core, Lagoon Remote, and the supporting infrastructure (k3s, MetalLB, ingress-nginx, cert-manager, Gatekeeper, MinIO, optional Harbor, optional Postgres/MariaDB) into a single interactive installer. The goal is to get a working Lagoon stack on one Linux box with a few prompts, rather than juggling a dozen Helm charts by hand.

## Prerequisites

- A Linux host (Ubuntu 22.04+, Debian 12+, Fedora 39+, openSUSE, or Arch). RHEL-likes that ship `firewalld` work too — the installer configures it.
- Root / sudo access (the installer uses `sudo` for k3s, sysctl, and package install).
- A static-ish IP on your LAN.
- For Let's Encrypt: a real domain pointing at your public IP, with ports 80/443 forwarded.
- For the Cloudflare DNS-01 mode: a domain on Cloudflare and an API token with `Zone:DNS:Edit`.

The installer auto-installs `make`, `docker`, `docker-buildx`, and NFS client packages if they're missing. `curl`, `git`, `openssl`, and `ssh-keygen` need to be present before you start.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/LagoonAtHome/LagoonAtHome/main/bootstrap.sh | bash
```

This clones the repo into `~/LagoonAtHome` and runs the interactive installer. To pin a specific release or use a different location:

```bash
LAGOON_VERSION=v0.1.0 LAGOON_HOME=/opt/LagoonAtHome \
  curl -fsSL https://raw.githubusercontent.com/LagoonAtHome/LagoonAtHome/main/bootstrap.sh | bash
```

Prefer to clone manually:

```bash
git clone https://github.com/LagoonAtHome/LagoonAtHome.git
cd LagoonAtHome
./install.sh
```

Either way, the installer walks you through:

1. **Network** — node IP and a small MetalLB range for LoadBalancer services.
2. **TLS** — choose self-signed (uses `nip.io`), Let's Encrypt HTTP-01, or Cloudflare DNS-01.
3. **Admin user** — email, name, organisation, SSH key.
4. **Optional components** — Harbor, Prometheus + Grafana, Postgres, MariaDB, Headlamp.

Random passwords are generated for every service and saved to `.env` (gitignored). The full install takes 15–25 minutes on a reasonable node.

When it's done, you'll get URLs and credentials printed at the end:

```
Dashboard:  https://dashboard.<your-domain>
API:        https://api.<your-domain>/graphql
Keycloak:   https://keycloak.<your-domain>
MinIO:      https://minio.<your-domain>
```

## Configuration

`install.sh` writes its choices to `.env`. You can re-run the installer to reconfigure, or edit `.env` directly and re-run individual `make` targets:

```bash
make cert-manager     # reapply TLS issuer changes
make lagoon-core      # re-helm lagoon-core after changing values
make lagoon-remote    # re-helm lagoon-remote
make apply-extras     # apply user resources from extras/
```

Run `make` with no target to do everything (`generate-config core-dependencies extras lagoon-core lagoon-remote lagoon-config`).

### TLS modes

| Mode | Best for | Domain |
| --- | --- | --- |
| `selfsigned` | Local LAN, no public IP | `<node-ip>.nip.io`, root CA written to `certs/rootCA.pem` |
| `letsencrypt` | Public-facing setup with 80/443 forwarded | Your real domain |
| `cloudflare` | Behind NAT, no port forwarding | Your real domain on Cloudflare |

In self-signed mode, install `certs/rootCA.pem` into your workstation's trust store to avoid certificate warnings.

### Adding your own resources

Drop YAML into `extras/`:

- `*.yml` / `*.yaml` — applied verbatim.
- `*.yml.tpl` / `*.yaml.tpl` — run through `envsubst` first, so you can use `${DOMAIN}`, `${CLUSTER_ISSUER}`, etc.
- `*.example` — ignored.

`make apply-extras` (run automatically as the last step of `install.sh`) applies them. The `extras/` directory itself is gitignored except for `.example` files, so your local resources don't get pushed.

### Build registry

By default, Lagoon's build pipeline pushes the build-deploy image to a small unauthenticated `twuni/docker-registry` running in-cluster. If you enable Harbor (`INSTALL_HARBOR=true`), it takes over as the build registry — Lagoon-Build-Deploy gets admin creds and creates per-project robot accounts automatically.

## Layout

```
config/      Cluster YAML (issuers, certs, mutations) — *.tpl files get envsubst
values/      Helm values — *.tpl files get envsubst
extras/      User-supplied YAML applied at install time
build/       Generated artifacts (gitignored)
certs/       Generated self-signed root CA (gitignored)
generated/   SSH host keys (gitignored)
docs/        Documentation assets
```

## Tearing down

```bash
make nuke   # removes k3s entirely + cleans build-deploy-tool checkout + ssh known_hosts entry
```

## Caveats

- Single-node only at the moment. Multi-node k3s should work in principle but isn't tested.
- Build-deploy-tool is built locally with Docker BuildKit — needs a working Docker + buildx on the install host.
- Internal mTLS uses a self-signed CA (`lagoon-issuer`) regardless of TLS mode; user-facing ingress can still use Let's Encrypt.

## Acknowledgements

Built on the shoulders of the [Lagoon](https://github.com/uselagoon/lagoon) project and the [`lagoon-charts`](https://github.com/uselagoon/lagoon-charts) Helm charts.
