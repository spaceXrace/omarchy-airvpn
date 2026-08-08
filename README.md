# Omarchy AirVPN

Minimal AirVPN bar widget for Omarchy Quickshell.

## Features

- VPN icon in the bar.
- Left click opens the AirVPN panel.
- Right click toggles connect/disconnect.
- Header shows connected/not connected state and current route.
- Mode selector: Auto, Country, Server.
- Bandwidth filter for server selection: 2 Gbit/s and 20 Gbit/s.
- Country and server lists include available AirVPN status metadata when the API exposes it.

## Requirements

- Omarchy Quattro shell plugin support.
- `nmcli`.
- `curl`.
- `python`.
- `networkmanager-airvpn-core` from AUR.

This plugin intentionally treats `networkmanager-airvpn-core` as a hard dependency. It does not fall back to OpenVPN imports or implement AirVPN tunnel management itself.

Using `networkmanager-airvpn-core` is a good fit because it gives Omarchy a small nmcli-only backend that owns the security-sensitive parts: AirVPN profile generation, NetworkManager VPN activation, OpenVPN execution, caching, and secrets. Reimplementing that inside a Quickshell plugin would mean duplicating VPN profile generation, private-key/profile storage, error handling, NetworkManager integration, and OpenVPN lifecycle code in a UI plugin. Depending on the NetworkManager plugin keeps this project focused on the Omarchy UI and lets NetworkManager remain the single source of truth for VPN state.

## Install

```sh
omarchy plugin add https://github.com/spaceXrace/omarchy-airvpn --enable --yes
```

For local development, use `omarchy plugin add file:///path/to/omarchy-airvpn --enable --yes`.

Then add it to the bar if it was not added automatically:

```sh
omarchy bar plugin add local.airvpn
```

## AirVPN Setup

Open the AirVPN widget, click **Settings**, open the AirVPN API settings page, paste the API key, optionally set a device name, and save.

The helper manages a NetworkManager connection named `AirVPN` by default.

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
bin/omarchy-airvpn save-settings --api-key YOUR_KEY --device YOUR_DEVICE
```

## Notes

AirVPN status data is cached for five minutes under `~/.cache/omarchy-airvpn/`.

Set `OMARCHY_AIRVPN_STATUS_URL` if AirVPN changes the public status endpoint.
