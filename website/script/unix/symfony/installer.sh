#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installer."

# Download latest version of symfony-cli.
if [ -d /tmp/symfony ]; then
    rm -rf /tmp/symfony
fi

mkdir -p /tmp/symfony

# Resolve the host CPU architecture so the symfony-cli binary matches the PHP container,
# which Docker runs using the host's native architecture. Hardcoding amd64 would break
# Apple Silicon and other ARM hosts.
case "$(uname -m)" in
    x86_64 | amd64) SYMFONY_ARCH="amd64" ;;
    aarch64 | arm64) SYMFONY_ARCH="arm64" ;;
    *)
        echo "[WADDLE ERROR] Unsupported host architecture for symfony-cli: $(uname -m)"
        exit 1
        ;;
esac

# Download and extract to /tmp first so a failed or corrupt download does not
# leave a partial binary in the project's bin/ directory.
SYMFONY_URL="$(curl -sL --retry 3 --retry-delay 5 \
    https://api.github.com/repos/symfony-cli/symfony-cli/releases/latest \
    | grep '"browser_download_url"' \
    | grep "linux_${SYMFONY_ARCH}\.tar\.gz" \
    | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/' | head -1)"
curl -L --retry 3 --retry-delay 5 "${SYMFONY_URL}" -o /tmp/symfony.tar.gz
tar -C /tmp/symfony -xzf /tmp/symfony.tar.gz

if [ ! -f /tmp/symfony/symfony ]; then
    echo "[WADDLE ERROR] Archive missing symfony binary."
    exit 1
fi

mv /tmp/symfony/symfony "./bin/symfony"
chmod +x "./bin/symfony"

rm -rf /tmp/symfony
rm -f /tmp/symfony.tar.gz

if [ -n "$(ls -A "./website/src" 2>/dev/null)" ]; then
    if [ "${WADDLE_BACKUP_SRC}" = "0" ]; then
        ./bin/web/backup
    fi
    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/unix/${WADDLE_PLATFORM}/upgrade.sh
else
    . ./website/script/unix/${WADDLE_PLATFORM}/install.sh
fi
