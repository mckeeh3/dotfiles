
# Dot files for Mac OSX and Arch Linux systems

## Omarchy (Bash)

Use the separate [Omarchy Bash profile](src/omarchy/README.md) to install the
Zsh-like Bash customizations while retaining Omarchy's defaults:

```bash
bash omarchy-setup.sh
# To back up and replace an existing .bashrc after reviewing it:
bash omarchy-setup.sh --replace-bashrc
```

Do not use `arch-linux-setup.sh` for this profile; it installs the older Zsh and
application configs. Local overrides and installer backups stay outside Git.

## Legacy platform configs

~~~bash
.
├── README.md
└── src
    ├── arch-linux  # <-- common arch linux files
    │   ├── vimrc
    │   └── zshrc
    ├── arch-linux-asrock-x570  # <-- for system specific files
    │   ├── vimrc
    │   └── zshrc
    ├── arch-linux-x99-extreme4  # <-- for system specific files
    │   ├── vimrc
    │   └── zshrc
    ├── mac  # <-- common mac osx files
    │   ├── vimrc
    │   └── zshrc
    ├── mac-2016  # <-- for system specific files
    │   ├── vimrc
    │   └── zshrc
    └── mac-2019  # <-- for system specific files
        ├── vimrc
        └── zshrc
~~~

## tmux

Use [Awesome Tmux](https://github.com/rothgar/awesome-tmux).

Copy or link to `~/.tmux.conf.local` for custom config settings.

On Arch Linux, install `xclip`.
