# Forge Firmware

Firmware builds for [Braiins Forge](https://braiinsforge.com/) products.
Product source code is kept in the `forge-micro` Git submodule; this repository
contains the product build entry points and CI configuration.

Clone the repository with its submodule:

```sh
git clone --recurse-submodules https://github.com/BraiinsForge/forge-firmware.git
cd forge-firmware
```

If the repository is already cloned, initialize the submodule with:

```sh
git submodule update --init
```

See [forge-axe](forge-axe/) for the currently supported firmware build.

This project is licensed under the GNU General Public License, version 3 or
later. See [LICENSE](LICENSE).
