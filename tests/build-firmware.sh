#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script=$repo_root/forge-axe/build-firmware
tmp=$(mktemp -d /tmp/claude-1001/forge-firmware-test.XXXXXX)
build_dir=$repo_root/forge-axe/build
saved_build=false

if [[ -e $build_dir ]]; then
    mv -- "$build_dir" "$tmp/build.saved"
    saved_build=true
fi

cleanup() {
    rm -rf -- "$build_dir"
    if $saved_build; then
        mv -- "$tmp/build.saved" "$build_dir"
    fi
    rm -rf -- "$tmp"
}
trap cleanup EXIT

expect_failure() {
    local expected=$1
    shift
    if output=$("$@" 2>&1); then
        echo "expected failure: $*" >&2
        exit 1
    fi
    grep -Fq -- "$expected" <<<"$output"
}

expect_failure "usage:" "$script" 1 2
expect_failure "positive decimal" "$script" 0
expect_failure "positive decimal" "$script" 01
expect_failure "positive decimal" "$script" nope
expect_failure "32-bit" "$script" 4294967296

mkdir -p "$tmp/bin" "$tmp/store-master" "$tmp/store-v42"
printf master-bin >"$tmp/store-master/forge-axe-master.bin"
printf master-uf2 >"$tmp/store-master/forge-axe-master.uf2"
printf tag-bin >"$tmp/store-v42/forge-axe-v42.bin"
printf tag-uf2 >"$tmp/store-v42/forge-axe-v42.uf2"

cat >"$tmp/bin/nix" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\${UBOS_FW_VERSION-}:\$*" >>'$tmp/nix-calls'
case "\${UBOS_FW_VERSION-}" in
    "") printf '%s\n' '$tmp/store-master' ;;
    42) printf '%s\n' '$tmp/store-v42' ;;
    *) exit 64 ;;
esac
EOF
chmod +x "$tmp/bin/nix"

PATH="$tmp/bin:$PATH" "$script"
cmp "$tmp/store-master/forge-axe-master.bin" "$repo_root/forge-axe/build/forge-axe-master.bin"
cmp "$tmp/store-master/forge-axe-master.uf2" "$repo_root/forge-axe/build/forge-axe-master.uf2"

PATH="$tmp/bin:$PATH" "$script" 42
cmp "$tmp/store-v42/forge-axe-v42.bin" "$repo_root/forge-axe/build/forge-axe-v42.bin"
cmp "$tmp/store-v42/forge-axe-v42.uf2" "$repo_root/forge-axe/build/forge-axe-v42.uf2"

grep -Fxq ":build --no-link --print-out-paths --option allow-unsafe-native-code-during-evaluation true $repo_root#forge-axe" "$tmp/nix-calls"
grep -Fxq "42:build --no-link --print-out-paths --option allow-unsafe-native-code-during-evaluation true $repo_root#forge-axe --impure" "$tmp/nix-calls"
