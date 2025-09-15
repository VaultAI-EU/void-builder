#!/usr/bin/env bash
# shellcheck disable=SC1091

set -e

APP_NAME_LC="$( echo "${APP_NAME}" | awk '{print tolower($0)}' )"

mkdir -p assets

if [[ "${OS_NAME}" == "osx" ]]; then
  if [[ -n "${CERTIFICATE_OSX_P12_DATA}" ]]; then
    if [[ "${CI_BUILD}" == "no" ]]; then
      RUNNER_TEMP="${TMPDIR}"
    fi

    CERTIFICATE_P12="${APP_NAME}.p12"
    KEYCHAIN="${RUNNER_TEMP}/buildagent.keychain"
    AGENT_TEMPDIRECTORY="${RUNNER_TEMP}"
    # shellcheck disable=SC2006
    KEYCHAINS=`security list-keychains | xargs`

    rm -f "${KEYCHAIN}"

    echo "${CERTIFICATE_OSX_P12_DATA}" | base64 --decode > "${CERTIFICATE_P12}"

    echo "+ create temporary keychain"
    security create-keychain -p pwd "${KEYCHAIN}"
    security set-keychain-settings -lut 21600 "${KEYCHAIN}"
    security unlock-keychain -p pwd "${KEYCHAIN}"
    # shellcheck disable=SC2086
    security list-keychains -s $KEYCHAINS "${KEYCHAIN}"
    # security show-keychain-info "${KEYCHAIN}"

    echo "+ import certificate to keychain"
    security import "${CERTIFICATE_P12}" -k "${KEYCHAIN}" -P "${CERTIFICATE_OSX_P12_PASSWORD}" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k pwd "${KEYCHAIN}" > /dev/null
    # security find-identity "${KEYCHAIN}"

    CODESIGN_IDENTITY="$( security find-identity -v -p codesigning "${KEYCHAIN}" | grep -oEi "([0-9A-F]{40})" | head -n 1 )"

    if [[ -n "${CODESIGN_IDENTITY}" ]]; then
      echo "+ signing"
      export CODESIGN_IDENTITY AGENT_TEMPDIRECTORY

      DEBUG="electron-osx-sign*" node vscode/build/darwin/sign.js "$( pwd )"
    else
      echo "Warning: No code signing identity found, skipping signing"
    fi
    # codesign --display --entitlements :- ""

    if [[ -n "${CODESIGN_IDENTITY}" && -n "${CERTIFICATE_OSX_ID}" ]]; then
      echo "+ notarize"

      cd "VSCode-darwin-${VSCODE_ARCH}"
      ZIP_FILE="./${APP_NAME}-darwin-${VSCODE_ARCH}-${RELEASE_VERSION}.zip"

      zip -r -X -y "${ZIP_FILE}" ./*.app

      xcrun notarytool store-credentials "${APP_NAME}" --apple-id "${CERTIFICATE_OSX_ID}" --team-id "${CERTIFICATE_OSX_TEAM_ID}" --password "${CERTIFICATE_OSX_APP_PASSWORD}" --keychain "${KEYCHAIN}"
      # xcrun notarytool history --keychain-profile "${APP_NAME}" --keychain "${KEYCHAIN}"
      xcrun notarytool submit "${ZIP_FILE}" --keychain-profile "${APP_NAME}" --wait --keychain "${KEYCHAIN}"

      echo "+ attach staple"
      xcrun stapler staple ./*.app
      # spctl --assess -vv --type install ./*.app

      rm "${ZIP_FILE}"

      cd ..
    else
      echo "Warning: Skipping notarization (no signing identity or Apple ID)"
      cd "VSCode-darwin-${VSCODE_ARCH}"
      cd ..
    fi
  fi

  if [[ "${SHOULD_BUILD_ZIP}" != "no" ]]; then
    echo "Building and moving ZIP"
    cd "VSCode-darwin-${VSCODE_ARCH}"
    zip -r -X -y "../assets/${APP_NAME}-darwin-${VSCODE_ARCH}-${RELEASE_VERSION}.zip" ./*.app
    cd ..
  fi

  if [[ "${SHOULD_BUILD_DMG}" != "no" ]]; then
    echo "Building and moving DMG"
    pushd "VSCode-darwin-${VSCODE_ARCH}"
    npx create-dmg ./*.app .
    mv ./*.dmg "../assets/${APP_NAME}.${VSCODE_ARCH}.${RELEASE_VERSION}.dmg"
    popd
  fi

  if [[ "${SHOULD_BUILD_SRC}" == "yes" ]]; then
    git archive --format tar.gz --output="./assets/${APP_NAME}-${RELEASE_VERSION}-src.tar.gz" HEAD
    git archive --format zip --output="./assets/${APP_NAME}-${RELEASE_VERSION}-src.zip" HEAD
  fi

  if [[ -n "${CERTIFICATE_OSX_P12_DATA}" ]]; then
    echo "+ clean"
    security delete-keychain "${KEYCHAIN}"
    # shellcheck disable=SC2086
    security list-keychains -s $KEYCHAINS
  fi

  VSCODE_PLATFORM="darwin"
elif [[ "${OS_NAME}" == "windows" ]]; then
  cd vscode || { echo "'vscode' dir not found"; exit 1; }

  npm run gulp "vscode-win32-${VSCODE_ARCH}-inno-updater"

  if [[ "${SHOULD_BUILD_ZIP}" != "no" ]]; then
    7z.exe a -tzip "../assets/${APP_NAME}-win32-${VSCODE_ARCH}-${RELEASE_VERSION}.zip" -x!CodeSignSummary*.md -x!tools "../VSCode-win32-${VSCODE_ARCH}/*" -r
  fi

  if [[ "${SHOULD_BUILD_EXE_SYS}" != "no" ]]; then
    npm run gulp "vscode-win32-${VSCODE_ARCH}-system-setup"
  fi

  if [[ "${SHOULD_BUILD_EXE_USR}" != "no" ]]; then
    npm run gulp "vscode-win32-${VSCODE_ARCH}-user-setup"
  fi

  if [[ "${VSCODE_ARCH}" == "ia32" || "${VSCODE_ARCH}" == "x64" ]]; then
    if [[ "${SHOULD_BUILD_MSI}" != "no" ]]; then
      . ../build/windows/msi/build.sh
    fi

    if [[ "${SHOULD_BUILD_MSI_NOUP}" != "no" ]]; then
      . ../build/windows/msi/build-updates-disabled.sh
    fi
  fi

  cd ..

  if [[ "${SHOULD_BUILD_EXE_SYS}" != "no" ]]; then
    echo "Moving System EXE"
    if ls vscode/.build/win32-${VSCODE_ARCH}/system-setup/*Setup*.exe 1> /dev/null 2>&1; then
      mv vscode/.build/win32-${VSCODE_ARCH}/system-setup/*Setup*.exe "assets/${APP_NAME}Setup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
    else
      echo "Warning: No system setup exe found in vscode/.build/win32-${VSCODE_ARCH}/system-setup/"
    fi
  fi

  if [[ "${SHOULD_BUILD_EXE_USR}" != "no" ]]; then
    echo "Moving User EXE"
    if ls vscode/.build/win32-${VSCODE_ARCH}/user-setup/*Setup*.exe 1> /dev/null 2>&1; then
      mv vscode/.build/win32-${VSCODE_ARCH}/user-setup/*Setup*.exe "assets/${APP_NAME}UserSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
    else
      echo "Warning: No user setup exe found in vscode/.build/win32-${VSCODE_ARCH}/user-setup/"
    fi
  fi

  if [[ "${VSCODE_ARCH}" == "ia32" || "${VSCODE_ARCH}" == "x64" ]]; then
    if [[ "${SHOULD_BUILD_MSI}" != "no" ]]; then
      echo "Moving MSI"
      if ls build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-${RELEASE_VERSION}.msi 1> /dev/null 2>&1; then
        mv build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-${RELEASE_VERSION}.msi assets/
      else
        echo "Warning: No MSI found in build/windows/msi/releasedir/"
      fi
    fi

    if [[ "${SHOULD_BUILD_MSI_NOUP}" != "no" ]]; then
      echo "Moving MSI with disabled updates"
      if ls build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-updates-disabled-${RELEASE_VERSION}.msi 1> /dev/null 2>&1; then
        mv build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-updates-disabled-${RELEASE_VERSION}.msi assets/
      else
        echo "Warning: No MSI with disabled updates found in build/windows/msi/releasedir/"
      fi
    fi
  fi

  VSCODE_PLATFORM="win32"
else
  cd vscode || { echo "'vscode' dir not found"; exit 1; }

  if [[ "${SHOULD_BUILD_APPIMAGE}" != "no" && "${VSCODE_ARCH}" != "x64" ]]; then
    SHOULD_BUILD_APPIMAGE="no"
  fi

  if [[ "${SHOULD_BUILD_DEB}" != "no" || "${SHOULD_BUILD_APPIMAGE}" != "no" ]]; then
    npm run gulp "vscode-linux-${VSCODE_ARCH}-prepare-deb"
    npm run gulp "vscode-linux-${VSCODE_ARCH}-build-deb"
  fi

  if [[ "${SHOULD_BUILD_RPM}" != "no" ]]; then
    npm run gulp "vscode-linux-${VSCODE_ARCH}-prepare-rpm"
    npm run gulp "vscode-linux-${VSCODE_ARCH}-build-rpm"
  fi

  if [[ "${SHOULD_BUILD_APPIMAGE}" != "no" ]]; then
    . ../build/linux/appimage/build.sh
  fi

  cd ..

  if [[ "${CI_BUILD}" == "no" ]]; then
    . ./stores/snapcraft/build.sh

    if [[ "${SKIP_ASSETS}" == "no" ]]; then
      mv stores/snapcraft/build/*.snap assets/
    fi
  fi

  if [[ "${SHOULD_BUILD_TAR}" != "no" ]]; then
    echo "Building and moving TAR"
    cd "VSCode-linux-${VSCODE_ARCH}"
    tar czf "../assets/${APP_NAME}-linux-${VSCODE_ARCH}-${RELEASE_VERSION}.tar.gz" .
    cd ..
  fi

  if [[ "${SHOULD_BUILD_DEB}" != "no" ]]; then
    echo "Moving DEB"
    mv vscode/.build/linux/deb/*/deb/*.deb assets/
  fi

  if [[ "${SHOULD_BUILD_RPM}" != "no" ]]; then
    echo "Moving RPM"
    mv vscode/.build/linux/rpm/*/*.rpm assets/
  fi

  if [[ "${SHOULD_BUILD_APPIMAGE}" != "no" ]]; then
    echo "Moving AppImage"
    mv build/linux/appimage/out/*.AppImage* assets/

    find assets -name '*.AppImage*' -exec bash -c 'mv $0 ${0/_-_/-}' {} \;
  fi

  VSCODE_PLATFORM="linux"
fi

if [[ "${SHOULD_BUILD_REH}" != "no" ]]; then
  echo "Building and moving REH"
  cd "vscode-reh-${VSCODE_PLATFORM}-${VSCODE_ARCH}"
  tar czf "../assets/${APP_NAME_LC}-reh-${VSCODE_PLATFORM}-${VSCODE_ARCH}-${RELEASE_VERSION}.tar.gz" .
  cd ..
fi

if [[ "${SHOULD_BUILD_REH_WEB}" != "no" ]]; then
  echo "Building and moving REH-web"
  cd "vscode-reh-web-${VSCODE_PLATFORM}-${VSCODE_ARCH}"
  tar czf "../assets/${APP_NAME_LC}-reh-web-${VSCODE_PLATFORM}-${VSCODE_ARCH}-${RELEASE_VERSION}.tar.gz" .
  cd ..
fi

if [[ "${OS_NAME}" != "windows" ]]; then
  ./prepare_checksums.sh
fi
