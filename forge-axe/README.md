# Forge Axe firmware

Firmware for the [Braiins Forge Axe](https://braiinsforge.com/products/braiins-forge-axe).
The source package is named `braiins-axe` inside the `forge-micro` submodule;
published firmware is named `forge-axe`.

## Build

Install Nix with flakes enabled, initialize the submodule, then run:

```sh
./forge-axe/build-firmware
```

This creates:

- `forge-axe/build/forge-axe-master.bin` for firmware updates
- `forge-axe/build/forge-axe-master.uf2` for USB bootloader installation

For a numbered release, pass the positive decimal version used in a `v<N>` Git
tag. For example:

```sh
./forge-axe/build-firmware 42
```

This embeds firmware version `42` and creates `forge-axe-v42.bin` and
`forge-axe-v42.uf2` in `forge-axe/build/`.
