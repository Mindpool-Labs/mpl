# mpl

Public signed release binaries for **mpl** — the mindpool local-AI CLI.

> The CLI source is proprietary; this repository hosts only the signed, publicly
> downloadable binaries. Usage is enrollment-gated at runtime inside the binary.

## Install

**Homebrew** (macOS, Apple Silicon):

    brew install --cask mindpool-labs/tap/mpl

**curl | sh** (macOS Apple Silicon · Linux x86_64 / arm64):

    curl -fsSL https://raw.githubusercontent.com/Mindpool-Labs/mpl/main/install.sh | sh

Windows: run the Linux build under WSL2.

## Verify

- **macOS** binaries are Apple **Developer-ID signed + notarized**.
- **Linux** tarballs ship a minisign `.minisig` sidecar. Public key id `4ED51C6DC08905D9`:

      minisign -Vm mpl-x86_64-unknown-linux-musl.tar.gz -p minisign.pub

- All tarballs ship a `.sha256` checksum.

## Targets

| OS | Arch | Asset |
| --- | --- | --- |
| macOS (Apple Silicon) | arm64 | `mpl-aarch64-apple-darwin.tar.gz` |
| Linux | x86_64 | `mpl-x86_64-unknown-linux-musl.tar.gz` |
| Linux | arm64 | `mpl-aarch64-unknown-linux-musl.tar.gz` |
