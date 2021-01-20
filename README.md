# wasmer-install

**One-line commands to install Wasmer on your system.**

[![Build Status](https://github.com/wasmerio/wasmer-install/workflows/ci/badge.svg?branch=master)](https://github.com/wasmerio/wasmer-install/actions)

## Install Latest Version

**With Shell:**

```sh
curl https://get.wasmer.io -sSfL | sh
```

**With PowerShell:**

```powershell
iwr https://win.wasmer.io -useb | iex
```

## Install Specific Version

**With Shell:**

```sh
curl https://get.wasmer.io -sSfL | sh -s v0.17.0
```

**With PowerShell:**

```powershell
$v="1.0.0"; iwr https://win.wasmer.io -useb | iex
```

## Install via Package Manager

**With [Homebrew](https://formulae.brew.sh/formula/wasmer):**

```sh
brew install wasmer
```

**With [Scoop](https://github.com/ScoopInstaller/Main/blob/master/bucket/wasmer.json):**

```powershell
scoop install wasmer
```

**With [Chocolatey](https://chocolatey.org/packages/wasmer):**

**Wasmer is not yet available in Chocolatey, would you like to give us a hand? 🤗**

```powershell
choco install wasmer
```

**With [Cargo](https://crates.io/crates/wasmer-bin/):**


```sh
cargo install wasmer-cli --features singlepass,cranelift # add --features=llvm for LLVM compilation support
```

## Environment Variables

- `WASMER_DIR` - The directory in which to install Wasmer. This defaults to
  `$HOME/.wasmer`. The executable is placed in `$WASMER_DIR/bin`. One
  application of this is a system-wide installation:

  **With Shell (`/usr/local`):**

  ```sh
  curl https://get.wasmer.io -sSfL | sudo WASMER_DIR=/usr/local sh
  ```

  **With PowerShell (`C:\Program Files\wasmer`):**

  ```powershell
  # Run as administrator:
  $env:WASMER_DIR = "C:\Program Files\wasmer"
  iwr https://win.wasmer.io -useb | iex
  ```

## Compatibility

- The Shell installer can be used on Windows via the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/about).
