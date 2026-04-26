#!/bin/bash
set -euxo pipefail
shopt -s extglob

url=$1
cached=$2


image=""

if [[ ${url} == file* ]]; then
    image="${url#file://}"
    image_path="$(dirname ${image})"
    echo "Using local file as image: ${url}"
else
    image_path="${RUNNER_TEMP}/image"
    mkdir --parent "${image_path}"
    case ${url} in
        http?(s)://*.yam?(l) )
            if [[ ${cached} != 'true' ]]; then
                sudo apt-get --quiet update
                sudo apt-get --yes --quiet install yq
                echo "Downloading manifest from ${url}"
                wget --no-verbose --output-document="manifest.yaml" "${url}"
                echo "=== Manifest contents ==="
                cat manifest.yaml
                echo "========================="
                yq -r '.urls[] | "\(.url) \(.sha256sum)"' ./manifest.yaml > urls
                while read -r file_url sha; do
                    filename="$(basename ${file_url})"
                    echo "Downloading: ${filename} from ${file_url}"
                    wget --no-verbose --output-document=${download_path}/${filename} ${file_url}
                    echo "$sha ${download_path}/$filename" | sha256sum -c -
                    [[ ${filename} = *.img.xz ]] && image="${download_path}/${filename}"
                done < urls
            fi
            cp -r "${download_path}/." "${image_path}/"
            image=$(find ${image_path} -type f \( -name *.img* \) -printf "%s %p\n" | sort -n | tail -1 | cut -d " " -f2)
        ;;
        http?(s)://* )
            download="${download_path}/$(basename ${url})"
            if [[ ${cached} != 'true' ]]; then
                echo "Downloading from ${url} to ${download}"
                wget --no-verbose --output-document="${download}" ${url}
            fi
            cp -r "${download_path}/." "${image_path}/"
            image=${image_path}/$(basename ${download})
        ;;
        * )
            echo "Unrecognized image source ${url}. Exiting!"
            exit 1
        ;;
    esac
fi

echo "Image: ${image}"
ls -la ${image_path}

if [[ ${image} = *.xz ]]; then
    echo "Unzipping ${image}"
    unxz ${image}
    image=${image%.xz}
fi

if [[ ${image} = *.tar ]]; then
    echo "Untarring ${image}"
    tar -xf ${image}
    rm ${image}
    image=$(find ${image_path} -type f \( -name *.img \) -printf "%s %p\n" | sort -n | tail -1 | cut -d " " -f2)
fi

echo "Image: ${image}"
ls -la $(dirname ${image})

if [[ ${image} != *.img ]]; then
    echo "${image} isn't a valid image file"
    exit 1
fi

echo "image_path=${image_path}" >> "$GITHUB_ENV"
echo "image=${image}" >> "$GITHUB_OUTPUT"