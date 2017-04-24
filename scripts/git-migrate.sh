#!/usr/bin/bash

function confirmation() {
    read -p "$1 (y/n)" -n 1 -r
    echo
    if ! [[ $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

function finish_cleanup() {
    if [[ -d $TEMP_PATCH_DIR ]]; then
        rm -fr "$TEMP_PATCH_DIR"
    fi
}

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 component source_dir dest_dir commit commit commit ..."
    exit 1
fi

trap finish_cleanup EXIT

set -e

COMPONENT="$1" && shift
SOURCE_DIR="$1" && shift
DEST_DIR="$1" && shift
ORIGIN_DIR="$(pwd)"

pushd "$SOURCE_DIR"

GIT_ROOT="$(basename $(git rev-parse --show-toplevel))"
if [[ "$GIT_ROOT" =~ (openssl|nss|gnutls) ]]; then
    GIT_TYPE="downstream"
else
    GIT_TYPE="upstream"
fi

echo -e "Selected component: \e[1m$COMPONENT\e[0m"
echo -e "git root directory is '$GIT_ROOT' which is \e[1m$GIT_TYPE\e[0m"
confirmation "Is this information correct?"
if [[ "$GIT_TYPE" == "downstream" ]]; then
    echo "This directory will be used as a component name for a path substitution"
    confirmation "Is this setup OK?"
    if [[ "$GIT_ROOT" != "$COMPONENT" ]]; then
        echo >&2 "Downstream repository is for component $GIT_ROOT, but the" \
                 "selected component is $COMPONENT"
        exit 1
    fi
fi

echo "Requested patches for following commits:"
git --no-pager show -s --oneline $@

echo "-------------------"

set +e

# Generate patches

GENERATED_PATCHES=()
TEMP_PATCH_DIR="$(mktemp -d "$ORIGIN_DIR/git-migrate-patches.XXXXXX")"
if [[ ! -d $TEMP_PATCH_DIR ]]; then
    echo >&2 "Failed to create a temporary dir"
    exit 1
fi

for patch in $(git format-patch $@); do
    echo "Generating patch $patch"
    if [[ $? -eq 0 && -n $patch ]]; then
        tmpfile="$(mktemp)"
        mv "$patch" "$tmpfile"
        awk -v dstr_comp="$GIT_ROOT" -v target_comp="$COMPONENT" '
        function bold(text) {
            return "\033[1m" text "\033[0m";
        }
        function green(text) {
            return "\033[32m" text "\033[39m";
        }
        function red(text) {
            return "\033[31m" text "\033[39m";
        }

        BEGIN {
            relevant = 0
        }
        # Match diff paths, eg.:
        # --- a/openssl/Interoperability/CC-openssl-with-gnutls/runtest.sh
        # +++ b/openssl/Interoperability/CC-openssl-with-gnutls/runtest.sh
        match($0, /^[+-]{3} [ab]\/([^\/]+)\/.+$/, m) {
            relevant = 1

            if(m[1] ~ /^(openssl|nss|gnutls)$/) {
                print "GOT: " m[1] " TARGET: " target_comp > "/dev/stderr"
                if(m[1] != target_comp) {
                    print "Skipping commit (target: " target_comp ", commit: " m[1] ")" > "/dev/stderr"
                    exit 1
                }
                # First path component is a component name => upstream repo
                # Supported components: openssl, nss, gnutls
                print "Found an " bold("upstream") " path: " green($0) > "/dev/stderr"
                # Remove the component name from the path
                $0 = gensub(/^([+-]{3} [ab])\/[^\/]+(\/.+)$/,
                       "\\1\\2", 1, $0);
                print "Rewriting this path to: " red($0) > "/dev/stderr"
            } else if(m[1] ~ /^(Interoperability)$/) {
                # First path component is a test type => downstream repo
                # Supported test types: Interoperability
                print "Found a " bold("downstream") " path: " green($0) > "/dev/stderr"
                # Prepend the component name to the path
                $0 = gensub(/^([+-]{3} [ab]\/)([^\/]+\/.+)$/,
                       "\\1" dstr_comp "/\\2", 1, $0);
                print "Rewriting this path to:  " red($0)> "/dev/stderr"
            } else {
                print "Unrelated commit, skipping..." > "/dev/stderr"
                exit 1
            }
        }
        {
            print $0;
        }
        END {
            if(relevant != 1) {
                print "Unrelated commit, skipping..." > "/dev/stderr"
                exit 1
            }
        }
        ' "$tmpfile" > "$patch"
        if [[ $? -ne 0 ]]; then
            rm $patch
        else
            echo "Patch saved as $patch"
            mv "$patch" "$TEMP_PATCH_DIR/"
            GENERATED_PATCHES+=("$TEMP_PATCH_DIR/$patch")
        fi
        rm "$tmpfile"
    else
        echo >&2 "git format-patch failed: ($patch)"
    fi
done

echo "Patches were saved in $TEMP_PATCH_DIR"

# TODO: Apply patches
set -e

popd

echo -e "\nApplying patches\n---------------"

pushd "$DEST_DIR"

for patch in ${GENERATED_PATCHES[@]}; do
    echo "PATCH: $patch"
    # Check if a patch was already applied
    if ! git apply --check -R < "$patch" &> /dev/null; then
        git am < "$patch"
    else
        echo "Patch $(basename $patch) is already applied, skipping..."
    fi
done


exit 0
