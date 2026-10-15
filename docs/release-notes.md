**Silica @TAG@ is an alpha.** It is a preview for trying Silica in a virtual machine. It is not ready for daily use or for real hardware.

Silica is a Linux desktop environment and a Fedora-based OS. It has its own compositor, Ossido (Rust, Smithay), with real-time glass. The shell and apps are written in Flutter. The aim is a polished, coherent desktop, designed down to the pixel.

## Try it in a virtual machine

1. Download `silica-os-@TAG@.qcow2`. If the release has `.part00`, `.part01`… files instead, download them all and join them:
   `cat silica-os-@TAG@.qcow2.part* > silica-os-@TAG@.qcow2`
2. Check the download with `sha256sum -c SHA256SUMS`.
3. Boot the disk in one of these:
   - **GNOME Boxes:** use "Create a virtual machine from file" and pick the `.qcow2`.
   - **virt-manager:** import an existing disk image and choose Fedora 44 as the OS. Give it at least 4 GB of RAM and 2 CPUs. Set the video model to Virtio.
   - **QEMU:**
     ```sh
     qemu-system-x86_64 -enable-kvm -m 4096 -smp 4 -cpu host \
       -drive file=silica-os-@TAG@.qcow2,if=virtio \
       -device virtio-vga -display gtk -usb -device usb-tablet \
       -nic user,model=virtio-net-pci
     ```

The session starts on its own and logs in as user `silica`, password `silica`. The account is in `wheel`.

## Try it on Fedora Atomic (bootc)

From Fedora Silverblue, Kinoite or another bootc system:

```sh
sudo bootc switch ghcr.io/silica-os/silica-os:@TAG@
```

Then reboot. To go back, run `sudo bootc rollback`. This is an alpha, so only do it on a machine you can afford to break.

## What's in it

- **Ossido:** windows with glass effects, shadows and animations. It also has spaces, Panorama, the app switcher and screenshots.
- **The shell:**
  - menu bar and Dock;
  - Faro search;
  - Launcher;
  - Control Center;
  - notifications and the volume and brightness HUD.
- **Apps:** Mustache (files), Mail, Terminal, Clock, Calculator and Settings.
- **Third-party apps:** Flatpak, with Flathub enabled.
- **Built with:** silica-packages `@PACKAGES@`, on Fedora 44 bootc.

## Known limitations

- In a VM, rendering is software only, so animations can stutter. GPU acceleration in the guest is not done yet.
- There is no login screen yet: the session logs in automatically. There is no installer either, and no first-run setup.
- Settings is not there yet. Mail runs on sample data unless you add an account, and OAuth is not done.
- Some values are still provisional while measurement continues.

Source code and issues are on [GitHub](https://github.com/silica-os). Please file bug reports in [silica-desktop](https://github.com/silica-os/silica-desktop/issues).
