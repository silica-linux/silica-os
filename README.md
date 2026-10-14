<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/silica-logo-dark.svg">
    <img alt="Silica" src=".github/silica-logo-light.svg" width="200">
  </picture>
</p>

<h1 align="center">Silica OS</h1>

<p align="center">
  <b>The Silica distribution.</b><br>
  A bootc image on top of Fedora Atomic, with Silica as the default session.
</p>

<p align="center">
  <img alt="Fedora: Atomic · bootc" src="https://img.shields.io/badge/Fedora-Atomic%20%C2%B7%20bootc-51A2DA?style=flat-square&logo=fedora">
  <img alt="status: alpha" src="https://img.shields.io/badge/status-alpha-8a8a8a?style=flat-square">
</p>

Built from the packages of [`silica-packages`](https://github.com/silica-linux/silica-packages)
with Silica's defaults (Inter, silica-icons, appearance, Flatpak for third-party apps).

Why an image-based system: atomic updates with rollback, like a sealed system volume; the image
is built like a container and published by CI.

## Architecture

- **bootc.** The image is an OCI container (`Containerfile`, on `quay.io/fedora/fedora-bootc:44`)
  that boots as a whole system. Updates are new images: `bootc upgrade` stages the next one and
  it takes effect at reboot; `bootc rollback` goes back. Nothing is installed into `/usr` at
  runtime.
- **`/usr` is the image, `/etc` and `/var` are the machine.** `/usr` is read-only and replaced
  as a whole on every update. `/etc` keeps local changes across updates (three-way merge).
  `/var` holds all state (homes are `/var/home`), and the image's `/var` is copied only at
  install time; what the image needs there at every boot comes from `tmpfiles.d`.
- **Silica.** The packages of [`silica-packages`](https://github.com/silica-linux/silica-packages)
  (Ossido, the embedder, the shell, the daemon and the portal, the Flutter engine, the apps,
  silica-icons) are part of the image. The session runs Ossido on DRM/KMS with libinput; the
  seat comes from logind through libseat. Until the Silica greeter (D2) and the first-run
  assistant (D3, [`silica-setup`](https://github.com/silica-linux/silica-setup)) exist, greetd
  logs the user in automatically (`/etc/greetd/config.toml`); after logging out its text login
  starts the session again.
- **Third-party apps.** Flatpak, with Flathub configured system-wide
  (`/etc/flatpak/remotes.d`).
- **Apps by drag and drop** ([silica-os#3](https://github.com/silica-linux/silica-os/issues/3)).
  `/Applications` points to `/var/Applications`, created at boot (`tmpfiles.d`), writable by
  administrators (`wheel`); other users go through the polkit action
  `dev.silica.applications.install`. The registry and the launcher are in silica-desktop.
- **Branding.** `os-release` says Silica (`ID=silica`, `ID_LIKE=fedora`); `VERSION_ID` stays
  Fedora's because dnf and the image tools read it. The logo is not in the system yet.

### What silica-packages provides

The image expects these packages: `silica-session` (with `/usr/bin/silica-session` and
`/usr/share/wayland-sessions/silica.desktop`), `ossido`, `silica-embedder`, `silica-daemon`,
`silica-portal`, `silica-cli`, `silica-shell`, `silica-flutter-engine`, `silica-icons`,
`mustache`, `clock`, `calculator`, `terminal`, `mail`.

`silica-session` reads `/etc/silica/session.env` and then `/etc/silica/session.env.d/*.env`:
`OSSIDO_ARGS` (extra arguments for Ossido) and `SILICA_RENDERER` (renderer of the shell's
embedders). The boot test uses them to open the control channel and to render in software.

## Building

Requirements: podman, root (bootc-image-builder runs privileged and reads root's container
storage; the script uses sudo), and for the boot test QEMU/KVM.

```sh
# The Silica packages: RPMs in rpms/ (from a silica-packages release) …
gh release download <tag> -R silica-linux/silica-packages -p '*.rpm' -D rpms
tools/build-image.sh                    # image + output/qcow2/disk.qcow2
# … or a published dnf repository
tools/build-image.sh --repo https://…/silica.repo
# Only the image, without the Silica packages (checks the rest of the Containerfile)
tools/build-image.sh --no-packages --no-disk
```

The disk has a user `silica` (password `silica`, in `wheel`) from `tools/bib-config.toml`:
it is for development and tests, not for real installations.

## Testing

```sh
tools/build-image.sh --test             # the boot-test layer on top, then the disk
tools/boot-test.sh output/qcow2/disk.qcow2 [--show] [--keep]
```

The boot test boots the disk with virtio-vga, waits for Ossido's control channel (forwarded to
the host's port 7992), checks that Ossido runs on DRM ("drm backend ready" on the serial
console) and that the screenshot is not black. `output/boot-test/` keeps `screenshot.png` and
`console.log`. The boot-test layer (`test/`) only adds the control-channel forward, software
rendering and the serial console; it is never published.

CI (`.github/workflows/image.yml`) does the same on every push with the latest silica-packages
release (`v*`), and after each new release (a `packages-release` dispatch from
silica-packages). Before the first packages release it only builds the image without the Silica
packages.

## To do

- the login screen (the greeter of silica-desktop, D2) and the first-run assistant
  ([`silica-setup`](https://github.com/silica-linux/silica-setup), D3);
- the installation ISO (`anaconda-iso`), signed images in a registry, `bootc upgrade` from it;
- GPU rendering in the VM test (virtio-gpu with 3D).
