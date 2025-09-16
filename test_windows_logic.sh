#!/bin/bash

# Test script pour simuler la logique Windows de prepare_assets.sh
set -e

echo "=== Test Windows Logic Simulation ==="

# Simuler l'environnement Windows
export OS_NAME="windows"
export VSCODE_ARCH="x64"
export APP_NAME="VaultCode"
export RELEASE_VERSION="1.99.30038"

# Créer la structure de fichiers simulée
mkdir -p "vscode/.build/win32-${VSCODE_ARCH}/system-setup"
mkdir -p "vscode/.build/win32-${VSCODE_ARCH}/user-setup"
mkdir -p "build/windows/msi/releasedir"
mkdir -p "assets"

# Créer des fichiers de test avec différents formats de noms
touch "vscode/.build/win32-${VSCODE_ARCH}/system-setup/VaultCodeSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
touch "vscode/.build/win32-${VSCODE_ARCH}/user-setup/VaultCodeUserSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
touch "build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-${RELEASE_VERSION}.msi"
touch "build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-updates-disabled-${RELEASE_VERSION}.msi"

echo "Files created:"
find vscode build -name "*.exe" -o -name "*.msi" | head -10

echo ""
echo "=== Testing EXE move logic ==="

# Tester la logique EXE
if ls vscode/.build/win32-${VSCODE_ARCH}/system-setup/*Setup*.exe 1> /dev/null 2>&1; then
  echo "✅ System setup EXE found"
  mv vscode/.build/win32-${VSCODE_ARCH}/system-setup/*Setup*.exe "assets/${APP_NAME}Setup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
  echo "✅ Moved to: assets/${APP_NAME}Setup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
else
  echo "❌ No system setup exe found"
fi

if ls vscode/.build/win32-${VSCODE_ARCH}/user-setup/*Setup*.exe 1> /dev/null 2>&1; then
  echo "✅ User setup EXE found"
  mv vscode/.build/win32-${VSCODE_ARCH}/user-setup/*Setup*.exe "assets/${APP_NAME}UserSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
  echo "✅ Moved to: assets/${APP_NAME}UserSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
else
  echo "❌ No user setup exe found"
fi

echo ""
echo "=== Testing MSI move logic ==="

# Tester la logique MSI
if ls build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-${RELEASE_VERSION}.msi 1> /dev/null 2>&1; then
  echo "✅ MSI found"
  mv build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-${RELEASE_VERSION}.msi assets/
  echo "✅ Moved MSI to assets/"
else
  echo "❌ No MSI found"
fi

if ls build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-updates-disabled-${RELEASE_VERSION}.msi 1> /dev/null 2>&1; then
  echo "✅ MSI with disabled updates found"
  mv build/windows/msi/releasedir/${APP_NAME}-${VSCODE_ARCH}-updates-disabled-${RELEASE_VERSION}.msi assets/
  echo "✅ Moved MSI with disabled updates to assets/"
else
  echo "❌ No MSI with disabled updates found"
fi

echo ""
echo "=== Final assets ==="
ls -la assets/

echo ""
echo "=== Cleanup ==="
rm -rf vscode build assets

echo "✅ Test completed successfully!"
