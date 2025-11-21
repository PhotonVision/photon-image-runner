#!/bin/bash
set -euo pipefail

url=$1
image=$(basename ${url})

echo "Downloading ${image} from ${url}"
wget --no-verbose ${url}

if [[ ${image} = *.xz ]]; then
    echo "Unzipping ${image}"
    unxz ${image}
    image=${image%.xz}
fi

echo "PWD: $(pwd)"
ls -l ${image}

if [[ ${image} != *.img ]]; then
    echo "${image} isn't a valid image file"
    exit 1
fi

echo "image=${image}" >> "$GITHUB_OUTPUT"