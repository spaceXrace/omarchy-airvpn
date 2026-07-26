# Omarchy AirVPN

Minimal AirVPN bar widget for Omarchy Quickshell.

## Features

- VPN icon in the bar.
- Left click opens the AirVPN panel.
- Right click toggles connect/disconnect.
- Header shows connected/not connected state and current route.
- Mode selector: Auto, Country, Server.
- Bandwidth filter: Auto, 2 Gbit, 20 Gbit.
- Country and server lists include available AirVPN status metadata when the API exposes it.

## Requirements

- Omarchy Quattro shell plugin support.
- `nmcli`.
- `curl`.
- `python`.
- NetworkManager AirVPN VPN plugin registered as `vpn-type airvpn`.

This plugin intentionally treats `networkmanager-airvpn` as a hard dependency. It does not fall back to OpenVPN imports.

## Install Locally

From this repo:

```sh
omarchy plugin add file:///home/vincent/omarchy-airvpn --enable --yes
```

Then add it to the bar if it was not added automatically:

```sh
omarchy bar plugin add local.airvpn
```

## AirVPN Setup

Create or connect once through NetworkManager so the AirVPN API key is stored as a NetworkManager secret. The helper manages a connection named `AirVPN` by default.

Override the connection name if needed:

```sh
export OMARCHY_AIRVPN_CONNECTION="My AirVPN"
```

## Helper CLI

```sh
bin/omarchy-airvpn status
bin/omarchy-airvpn countries --filter auto
bin/omarchy-airvpn servers --filter 20gbit
bin/omarchy-airvpn connect --mode auto --filter 20gbit
bin/omarchy-airvpn connect --mode country --country ch
bin/omarchy-airvpn connect --mode server --server Achernar
bin/omarchy-airvpn disconnect
```

## Notes

AirVPN status data is cached for five minutes under `~/.cache/omarchy-airvpn/`.

Set `OMARCHY_AIRVPN_STATUS_URL` if AirVPN changes the public status endpoint.
