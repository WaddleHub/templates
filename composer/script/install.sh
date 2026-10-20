#!/bin/sh -eux

echo "[WADDLE NOTICE] Running Composer installation script."

# Create binary & home directories.
mkdir -p "{{project_path 'bin'}}" "{{project_path 'composer/conf/home'}}"

# Check that composer resource exists.
if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 https://getcomposer.org/download/{{tags.composer.version.full_raw}}/composer.phar)" != "200" ]; then
    echo "[WADDLE] Failed to find Composer download!"
    exit 1
fi

# Download Composer installer (overwrite existing).
curl -fL --retry 3 --retry-delay 5 https://getcomposer.org/download/{{tags.composer.version.full_raw}}/composer.phar -o "{{project_path 'bin'}}/composer"

# Download the detached signature covering that exact phar.
curl -fL --retry 3 --retry-delay 5 https://getcomposer.org/download/{{tags.composer.version.full_raw}}/composer.phar.sig -o "{{project_path 'composer/conf/home'}}/.composer.phar.sig"

# Verify the signature against Composer's pinned "tags" public key (composer/conf/releases.pub).
php -r '
$signature = base64_decode(json_decode(file_get_contents($argv[1]), true)["sha384"]);
$data = file_get_contents($argv[2]);
$key = openssl_pkey_get_public(file_get_contents($argv[3]));
if (openssl_verify($data, $signature, $key, OPENSSL_ALGO_SHA384) !== 1) {
    fwrite(STDERR, "[WADDLE] Composer signature verification failed!\n");
    exit(1);
}
' "{{project_path 'composer/conf/home'}}/.composer.phar.sig" "{{project_path 'bin'}}/composer" "{{project_path 'composer/conf/releases.pub'}}"

rm -f "{{project_path 'composer/conf/home'}}/.composer.phar.sig"

# Make binary executable.
chmod +x "{{project_path 'bin'}}/composer"

# Smoke test.
composer --version
