#!/usr/bin/env bash

# BASED ON THIS COMMENT: https://github.com/Carthage/Carthage/issues/3019#issuecomment-665136323

# wcarthage.sh
# Usage example: ./wcarthage.sh update --platform ios

echo "Carthage wrapper"
echo "Applying Xcode 12 workaround..."

set -euo pipefail

xcconfig=$(mktemp /tmp/static.xcconfig.XXXXXX)
trap 'rm -f "$xcconfig"' INT TERM HUP EXIT
 # xcconfig="/tmp/xc12-carthage.xcconfig"

# For Xcode 12 make sure EXCLUDED_ARCHS is set to arm architectures otherwise
# the build will fail on lipo due to duplicate architectures.
# Xcode 12 Beta 3:
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12A8169g = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12 beta 4
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12A8179i = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12 beta 5
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12A8189h = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12 beta 6
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12A8189n = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12 GM (12A7208)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12A7208 = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12 GM (12A7209)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12A7209 = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12.0.1 GM (12A7300)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12A7300 = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12.2 (12B45b)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12B45b = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12.3 (12C33)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12C33 = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12.4 (12D4e)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12D4e = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12.5 (12E262)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12E262 = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 12.5.1 (12E507)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_12E507 = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 13.0 beta 5 (13A5212g)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1300__BUILD_13A5212g = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
# Xcode 13.0 (13A233)
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1300__BUILD_13A233 = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig

echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200 = $(EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200__BUILD_$(XCODE_PRODUCT_BUILD_VERSION))' >> $xcconfig
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1300 = $(EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1300__BUILD_$(XCODE_PRODUCT_BUILD_VERSION))' >> $xcconfig
echo 'EXCLUDED_ARCHS = $(inherited) $(EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_$(EFFECTIVE_PLATFORM_SUFFIX)__NATIVE_ARCH_64_BIT_$(NATIVE_ARCH_64_BIT)__XCODE_$(XCODE_VERSION_MAJOR))' >> $xcconfig

echo 'ONLY_ACTIVE_ARCH=NO' >> $xcconfig
echo 'VALID_ARCHS = $(inherited) x86_64' >> $xcconfig

export XCODE_XCCONFIG_FILE="$xcconfig"

echo "Workaround applied. xcconfig here: $XCODE_XCCONFIG_FILE"

carthage $@
