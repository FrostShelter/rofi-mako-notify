# rofi-mako-notify

A lightweight notification history viewer and manager for [Mako](https://github.com/emersion/mako) using [Rofi](https://github.com/davatorium/rofi).

## Dependencies

* `mako`
* `rofi-wayland`
* `jq`

## Installation

Clone the repository and make the script executable:

```bash
git clone https://github.com/FrostShelter/rofi-mako-notify.git
cd rofi-mako-notify
sudo install -Dm755 rofi-mako-notify.sh /usr/local/bin/rofi-notify
rm -rf ~/rofi-mako-notify
```
## Usage
In any terminal type:

```bash
rofi-notify
```
## Uninstall
To remove the binary from your system:

```bash
sudo rm /usr/local/bin/rofi-notify
hash -r
```
