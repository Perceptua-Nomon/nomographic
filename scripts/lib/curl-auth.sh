#!/usr/bin/env bash
# curl-auth.sh — run curl with credentials supplied via a config file on
# stdin (process substitution) instead of `-u user:pass` on the command
# line, so the password never appears in `ps` output.
#
# CONTRACT: the caller defines AUTH="user:password" (dynamic scoping) before
# calling curl_auth. Backslashes and double quotes in AUTH are escaped per
# curl config syntax.

curl_auth() {
    local escaped="${AUTH//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    curl --config <(printf 'user = "%s"\n' "$escaped") "$@"
}
