#!/bin/bash
#
# Copyright (C) 2018 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

DEVICE_COMMON=sm6125-common
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

LINEAGE_ROOT="$MY_DIR"/../../..

HELPER="$LINEAGE_ROOT"/tools/extract-utils/extract_utils.sh
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
            CLEAN_VENDOR=false
            ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "$SRC" ]; then
    SRC=adb
fi

function blob_fixup() {
    case "${1}" in
        vendor/bin/mlipayd@1.1 | vendor/lib64/libmlipay.so | vendor/lib64/libmlipay@1.1.so)
            patchelf --remove-needed "vendor.xiaomi.hardware.mtdservice@1.0.so" "${2}"
            ;;
        vendor/etc/camera/camera_config.xml)
            # Remove vtcamera for ginkgo
            gawk -i inplace '{ p = 1 } /<CameraModuleConfig>/{ t = $0; while (getline > 0) { t = t ORS $0; if (/ginkgo_vtcamera/) p = 0; if (/<\/CameraModuleConfig>/) break } $0 = t } p' "${2}"
            ;;
    esac
}

# Initialize the common helper
setup_vendor "$DEVICE_COMMON" "$VENDOR" "$LINEAGE_ROOT" true $CLEAN_VENDOR

extract "$MY_DIR"/proprietary-files.txt "$SRC" \
    "${KANG}" --section "${SECTION}"

if [ -s "$MY_DIR"/../$DEVICE_SPECIFIED_COMMON/proprietary-files.txt ];then
    # Reinitialize the helper for device specified common
    setup_vendor "$DEVICE_SPECIFIED_COMMON" "$VENDOR" "$LINEAGE_ROOT" false "$CLEAN_VENDOR"
    extract "$MY_DIR"/../$DEVICE_SPECIFIED_COMMON/proprietary-files.txt "$SRC" \
    "${KANG}" --section "${SECTION}"
fi

if [ -s "$MY_DIR"/../$DEVICE/proprietary-files.txt ]; then
    # Reinitialize the helper for device
    setup_vendor "$DEVICE" "$VENDOR" "$LINEAGE_ROOT" false "$CLEAN_VENDOR"
    extract "$MY_DIR"/../$DEVICE/proprietary-files.txt "$SRC" \
    "${KANG}" --section "${SECTION}"
fi

"$MY_DIR"/setup-makefiles.sh
