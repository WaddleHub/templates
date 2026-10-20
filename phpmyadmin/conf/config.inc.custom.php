<?php

if (!isset($i)) {
    $i = 1;
}

if (!is_array($cfg)) {
    $cfg = [];
}

if (!isset($cfg["Servers"])) {
    $cfg["Servers"] = [];
}

function addDbConf(
    &$cfg,
    &$i,
    $host,
    $un,
    $pw,
    $authType = "config",
    $allowNoPassword = true,
    $compress = false
) {
    $cfg["Servers"][$i] = [
        "auth_type" => $authType,
        "host" => $host,
        "user" => $un,
        "password" => $pw,
        "compress" => $compress,
        "AllowNoPassword" => $allowNoPassword
    ];

    $i++;
}

// Credentials are provided to the php container via the gitignored .env, never committed here.
addDbConf(
    $cfg,
    $i,
    "db",
    '{{private.website_credentials.db_username}}',
    '{{private.website_credentials.db_password}}'
);
