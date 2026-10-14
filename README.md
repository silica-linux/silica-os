# silica-os

La distro di [Silica](https://github.com/silica-linux/silica-desktop): un'immagine bootc sopra
Fedora Atomic con i pacchetti di `silica-packages` e i default di Silica (Inter, silica-icons,
aspetto, Flatpak per le app di terzi).

Perché un sistema a immagini: aggiornamenti atomici con ripristino, come un volume di sistema
sigillato; l'immagine si costruisce come un container e la CI la pubblica.

Da fare:
- Containerfile sopra l'immagine Fedora Atomic, con la sessione di Silica come predefinita;
- la schermata di login (greeter di silica-desktop) e l'assistente al primo avvio (`silica-setup`);
- pipeline di build e firma, registro delle immagini, ISO di installazione.
