# 🎵 LyricMaker

**A modern, cross-platform application for creating and synchronizing lyrics with audio files.**

LyricMaker allows you to easily load audio files, type out lyrics, and synchronize them in real-time. Built with a focus on a clean interface and precise timing, it generates `.lya` (Lyric Audio) files that bundle your audio and synchronized lyrics together into a single, highly efficient binary package.

---

## ✨ Features

*   **Cross-Platform:** Native-feeling applications for **Windows**, **macOS**, and **Linux**.
*   **Real-time Synchronization:** Set lyric timestamps instantly while the audio plays.
*   **Adaptive UI:** Clean interface that respects your system's Light/Dark mode settings (macOS/KDE Plasma).
*   **The `.lya` Format:** Saves your work in a custom binary format (`QDataStream`) that encapsulates both the MP3 audio data and the precise lyric timestamps. No need to manage separate `.mp3` and `.lrc` files!
*   **Precise Scrubbing:** Easily scrub through the audio to fine-tune specific lyric timings.
*   **Live Preview:** Watch your synchronized lyrics update in real-time as the audio plays.

## 🚀 Installation & Build Instructions

LyricMaker uses different underlying technologies to ensure the best performance and native feel on each platform.

### 🐧 Linux (KDE Plasma / Debian-based)

LyricMaker for Linux is built using **C++** and **Qt5**, ensuring seamless integration with the KDE Plasma desktop environment.

**Prerequisites:**
You will need the Clang compiler and Qt5 development libraries.
```bash
sudo apt update
sudo apt install clang qtbase5-dev qtmultimedia5-dev pkg-config
