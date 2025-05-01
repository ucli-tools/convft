<h1> ConvFT - File and Text Converter </h1>

<h2>Table of Contents</h2>

- [Introduction](#introduction)
- [Repository](#repository)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [1. Convert Files to Text (`ft`)](#1-convert-files-to-text-ft)
    - [Options:](#options)
    - [Examples:](#examples)
  - [2. Convert Text to Files (`tf`)](#2-convert-text-to-files-tf)
  - [3. Install ConvFT](#3-install-convft)
  - [4. Uninstall ConvFT](#4-uninstall-convft)
  - [5. Display Help](#5-display-help)
- [How It Works](#how-it-works)
- [Notes](#notes)
- [Contributing](#contributing)
- [License](#license)

---

## Introduction

ConvFT is a simple yet powerful bash script that allows you to convert between files and a single text file representation. It's perfect for backing up file structures, sharing multiple files as a single text file, or reconstructing files from a text representation. Ideal for AI work, backup, sharing, and reconstructing complex directory hierarchies.

## Repository

https://github.com/mik-tf/convft

## Features

- Convert multiple files (including directory structure) into a single text file
- Reconstruct files and directories from the text file representation
- Include or exclude specific files or directories during conversion
- Control the depth of directory tree traversal
- Easy to install and use
- Lightweight and portable

## Installation

You can install ConvFT directly from this repository:

```bash
git clone https://github.com/Mik-TF/convft.git
cd convft
sudo bash convft.sh install
```

This will install the script to `/usr/local/bin/convft`, making it available system-wide.

## Usage

After installation, you can use ConvFT with the following commands:

### 1. Convert Files to Text (`ft`)

Convert files and directories into a single text file:

```bash
convft ft [OPTIONS]
```

#### Options:
- `-i, --include [PATH...]`: Include specific directories or files (defaults to the current directory).
- `-e, --exclude [PATH...]`: Exclude specific directories or files.
- `-t, --tree-depth [DEPTH]`: Set the directory tree depth (default is 1).

#### Examples:
- Convert all files in the current directory (default depth of 1):
  ```bash
  convft ft
  ```
- Convert files in `/my/project` with a tree depth of 3, excluding `/my/project/temp` and `/my/project/build.sh`:
  ```bash
  convft ft -i /my/project -t 3 -e /my/project/temp /my/project/build.sh
  ```
- Convert specific files:
  ```bash
  convft ft -i /path/to/file1.txt /path/to/file2.c
  ```

### 2. Convert Text to Files (`tf`)

Reconstruct files and directories from the text file representation:

```bash
convft tf
```

This will read the `all_files_text.txt` file in the current directory and recreate the original files and directory structure.

### 3. Install ConvFT

Install ConvFT system-wide:

```bash
sudo convft install
```

### 4. Uninstall ConvFT

Remove ConvFT from your system:

```bash
sudo convft uninstall
```

### 5. Display Help

Show the help message with usage instructions:

```bash
convft help
```

## How It Works

- The `ft` (file-to-text) option recursively scans the specified directories, writing the content of each file to `all_files_text.txt` along with filename information. It also includes a directory tree representation at the beginning of the file.
- The `tf` (text-to-file) option reads `all_files_text.txt` and recreates the original file structure and content.

## Notes

- Be cautious when using the `tf` option, as it will overwrite existing files with the same names.
- The script skips processing itself and the output file to avoid recursive issues.
- Binary files are automatically skipped during the `ft` operation.
- The `.git` directory is excluded by default.

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/mik-tf/convft/issues).

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.