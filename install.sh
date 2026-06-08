#!/bin/sh
# mpl curl|sh installer. Hermetic-testable via MPL_VERSION + MPL_BASE_URL + HOME.
set -eu

# Public release-binary repo. The CLI source is proprietary (private repo); only the
# signed binaries are published here so curl|sh + brew can fetch them anonymously.
REPO="Mindpool-Labs/mpl"
INSTALL_DIR="${HOME}/.local/bin"
MPL_BASE_URL="${MPL_BASE_URL:-https://github.com/${REPO}/releases/download}"
MPL_API_URL="${MPL_API_URL:-https://api.github.com/repos/${REPO}/releases/latest}"

# PATH-block markers — MUST match mpl-core::shellenv (PATH_BLOCK_BEGIN/END).
BEGIN_MARK="# >>> mpl >>>"
END_MARK="# <<< mpl <<<"

err() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}
info() { printf '%s\n' "$1"; }

detect_target() {
    os=$(uname -s)
    arch=$(uname -m)
    case "$os" in
    Darwin)
        case "$arch" in
        arm64 | aarch64) echo "aarch64-apple-darwin" ;;
        *) err "mpl supports Apple Silicon only (got $arch); Intel Macs are unsupported" ;;
        esac
        ;;
    Linux)
        case "$arch" in
        x86_64 | amd64) echo "x86_64-unknown-linux-musl" ;;
        aarch64 | arm64) echo "aarch64-unknown-linux-musl" ;;
        *) err "unsupported Linux arch: $arch" ;;
        esac
        ;;
    *) err "unsupported OS: $os (Windows: run the Linux binary under WSL2)" ;;
    esac
}

resolve_version() {
    if [ -n "${MPL_VERSION:-}" ]; then
        echo "$MPL_VERSION"
        return
    fi
    tag=$(fetch "$MPL_API_URL" - | grep '"tag_name"' | head -1 |
        sed -E 's/.*"tag_name"[^"]*"([^"]+)".*/\1/')
    [ -n "$tag" ] || err "could not resolve the latest mpl version"
    echo "$tag"
}

fetch() { # url dest ('-' for stdout)
    if command -v curl >/dev/null 2>&1; then
        if [ "$2" = "-" ]; then curl -fsSL "$1"; else curl -fsSL "$1" -o "$2"; fi
    elif command -v wget >/dev/null 2>&1; then
        if [ "$2" = "-" ]; then wget -qO - "$1"; else wget -qO "$2" "$1"; fi
    else
        err "need curl or wget"
    fi
}

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    else err "need sha256sum or shasum"; fi
}

stamp_provenance() {
    cfg="${HOME}/.mpl"
    mkdir -p "$cfg"
    printf '%s\n' '{"method":"curl"}' >"$cfg/install.json.tmp"
    mv "$cfg/install.json.tmp" "$cfg/install.json"
}

rc_file() {
    case "${SHELL:-}" in
    */zsh) echo "${HOME}/.zshrc" ;;
    */bash) echo "${HOME}/.bashrc" ;;
    *) echo "${HOME}/.profile" ;;
    esac
}

edit_path() {
    rc=$(rc_file)
    if [ -f "$rc" ] && grep -qF "$BEGIN_MARK" "$rc"; then return; fi
    {
        printf '%s\n' "$BEGIN_MARK"
        # Literal line written verbatim into the user's rc; $PATH/$HOME expand at their
        # shell startup, not at install time, so single quotes are intentional.
        # shellcheck disable=SC2016
        printf '%s\n' 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
        printf '%s\n' "$END_MARK"
    } >>"$rc"
}

main() {
    target=$(detect_target)
    version=$(resolve_version)
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    asset="mpl-${target}.tar.gz"
    url="${MPL_BASE_URL}/${version}/${asset}"

    info "Downloading mpl ${version} (${target})..."
    fetch "$url" "$tmp/$asset"
    fetch "${url}.sha256" "$tmp/$asset.sha256"

    expected=$(awk '{print $1}' "$tmp/$asset.sha256")
    actual=$(sha256_of "$tmp/$asset")
    [ "$expected" = "$actual" ] ||
        err "checksum mismatch for $asset (expected $expected, got $actual)"

    tar -xzf "$tmp/$asset" -C "$tmp"
    bin=$(find "$tmp" -type f -name mpl | head -1)
    [ -n "$bin" ] || err "mpl binary not found in $asset"

    mkdir -p "$INSTALL_DIR"
    cp "$bin" "$INSTALL_DIR/mpl"
    chmod 0755 "$INSTALL_DIR/mpl"

    stamp_provenance
    edit_path

    info "Installed mpl to ${INSTALL_DIR}/mpl"
    info "Next: restart your shell (or source your rc), then run: mpl login"
}

main "$@"
