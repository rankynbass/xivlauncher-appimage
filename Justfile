podman := require("podman")
git := require("git")
build_image := "xivlauncher-appimage-builder"

@default:
    just --list

# Build an AppImage based on a given config (currently, either 'xivlauncher' or 'xivlauncher-rb')
[group('build')]
build config-name="xivlauncher" rebuild="false": (build-image rebuild)
    mkdir -p output
    "{{ podman }}" run --rm \
        -v $(pwd)/output:/src/appimage-build/output:z \
        xivlauncher-appimage-builder create-appimage {{ config-name }}

# Build or rebuild the container image used for building the AppImage.
[group('build')]
build-image rebuild="false":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{ rebuild }}" == "true" ]]; then
        echo "Rebuilding image..."
        "{{ podman }}" build \
        --no-cache -t {{ build_image }} .
    else
        if ! "{{ podman }}" image inspect {{ build_image }} >/dev/null 2>&1; then
            echo "Image not found, building..."
            "{{ podman }}" build --no-cache -t {{ build_image }} .
        else
            echo "Image already exists, skipping build"
        fi
    fi

# Remove the container image as well as built AppImages.
[group('build')]
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Removing Docker image {{ build_image }}..."
    "{{ podman }}" rmi {{ build_image }} 2>/dev/null || echo "Image not found, skipping..."
    echo "Removing output folder..."
    rm -rf output

# Creates a git tag according to the current date, or a given tag.
[group('git')]
tag-commit config-name custom-tag="":
    #!/usr/bin/env python3
    import json
    import os
    import re
    import subprocess
    from datetime import datetime

    def sh(*args):
        return subprocess.run([str(a) for a in args], capture_output=True, text=True).stdout

    config = json.load(open(os.path.join(os.getcwd(), "appimage-build", "config.json")))["{{ config-name }}"]

    full_tag = "%s/%s/" % (config["short_name"], config["version"])
    tags = [t.strip() for t in sh("{{ git }}", "tag").split()]

    custom_tag = "{{ custom-tag }}"
    full_tag += custom_tag if custom_tag else datetime.now().strftime("%Y-%m-%d")

    tags = [t for t in tags if re.match(r"^%s(\.(\d+))*$" % re.escape(full_tag), t)]
    if tags:
        full_tag += ".%d" % len(tags)

    sh("{{ git }}", "tag", full_tag)
    print(full_tag)
