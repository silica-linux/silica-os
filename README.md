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
  <img alt="status: planned" src="https://img.shields.io/badge/status-planned-8a8a8a?style=flat-square">
</p>

Built from the packages of [`silica-packages`](https://github.com/silica-linux/silica-packages)
with Silica's defaults (Inter, silica-icons, appearance, Flatpak for third-party apps).

Why an image-based system: atomic updates with rollback, like a sealed system volume; the image
is built like a container and published by CI.

## To do

- a Containerfile on the Fedora Atomic image, with the Silica session as the default;
- the login screen (the greeter of silica-desktop) and the first-run assistant
  ([`silica-setup`](https://github.com/silica-linux/silica-setup));
- build and signing pipeline, image registry, installation ISO.
