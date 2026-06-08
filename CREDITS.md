# Credits

Third-party work used in this repository, with attribution.

## ASCII art

- **Bat** -- `lib/banner.sh::banner::splash`
  - Artist: **Joan Stark** (signature: `jgs`)
  - Source: From her ASCII art collection, widely shared on Usenet and ASCII
    archives starting in the late 1990s.
  - Notes: Original is a 4-line piece; the version embedded here is unmodified
    in shape, with ANSI color added for the eyes, fang, and body outline.

## Tools and libraries

The project builds on a robust ecosystem of open-source tools. Every component
listed in `config/versions.conf` (our "Bill of Materials") is upstream-licensed
software whose authors deserve the same credit.

### The Foundation

- [Bash](https://www.gnu.org/software/bash/) -- The heartbeat of the framework.
- [Git](https://git-scm.com/) -- Version control and configuration distribution.
- [Restic](https://restic.net/) -- Backups that are versioned, encrypted, and
  deduplicated.
- [Rclone](https://rclone.org/) -- The Swiss army knife of cloud storage sync.

### Media Stack

- [FFmpeg](https://ffmpeg.org/), [mpv](https://mpv.io/),
  [ImageMagick](https://imagemagick.org/)
- [libheif](https://github.com/strukturag/libheif),
  [libavif](https://github.com/AOMediaCodec/libavif),
  [libjxl](https://github.com/libjxl/libjxl),
  [libwebp](https://chromium.googlesource.com/webm/libwebp),
  [libraw](https://www.libraw.org/)
- [x264](https://www.videolan.org/developers/x264.html),
  [x265](https://www.videolan.org/developers/x265.html),
  [libvpx](https://www.webmproject.org/code/),
  [libaom](https://aomedia.googlesource.com/aom/),
  [libdav1d](https://www.videolan.org/projects/dav1d.html),
  [libsvtav1](https://gitlab.com/AOMediaCodec/SVT-AV1)
- [libopus](https://opus-codec.org/), [lame](https://lame.sourceforge.io/),
  [libfdk-aac](https://github.com/mstorsjo/fdk-aac)
- [libplacebo](https://code.videolan.org/videolan/libplacebo),
  [libvmaf](https://github.com/Netflix/vmaf),
  [libdisplay-info](https://gitlab.freedesktop.org/emersion/libdisplay-info)
- [Ghostscript](https://www.ghostscript.com/), [NASM](https://www.nasm.us/),
  [Meson](https://mesonbuild.com/), [Vulkan](https://vulkan.lunarg.com/)

### User Interface

- [yt-dlp](https://github.com/yt-dlp/yt-dlp),
  [alacritty](https://github.com/alacritty/alacritty),
  [kitty](https://sw.kovidgoyal.net/kitty/),
  [rofi](https://github.com/davatorium/rofi)

### Typography and Iconography

- [Nerd Fonts](https://www.nerdfonts.com/) (Ryan McIntyre and contributors)
- [Cascadia Code](https://github.com/microsoft/cascadia-code) (Microsoft)
- [Noto Color Emoji](https://fonts.google.com/noto/specimen/Noto+Color+Emoji)
  (Google Fonts)
- [Material Design Icons](https://materialdesignicons.com/) (Google) --
  brightness levels in `assets/icons/`

## Prior art and inspiration

This repository's architecture -- declarative manifests, idempotent bootstrap,
dotfiles as a versioned project -- owes a lot to the people who documented their
own setups publicly:

- [victoriadrake/dotfiles](https://github.com/victoriadrake/dotfiles) and her
  walkthrough
  [_"How to set up a fresh Ubuntu desktop using only dotfiles and bash scripts"_](https://victoria.dev/blog/how-to-set-up-a-fresh-ubuntu-desktop-using-only-dotfiles-and-bash-scripts/)
- [tomnomnom/dotfiles](https://github.com/tomnomnom/dotfiles)
- Ryan Dale's [_dotfiles guide_](https://daler.github.io/dotfiles/bash.html)
- _Effective Shell_ --
  [_managing your dotfiles_](https://effective-shell.com/part-5-building-your-toolkit/managing-your-dotfiles/)

## Licensing

This repository is MIT-licensed (see `LICENSE`). Embedded ASCII art remains the
work of its original authors, used here under fair use / cultural attribution
norms. If any rightsholder objects to inclusion, open an issue and the asset
will be removed.
