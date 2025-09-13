#!/bin/bash

# Script de test pour prepare_assets.sh
# Simule uniquement la partie Windows EXE

set -e

# Variables d'environnement simulées
export VSCODE_ARCH="x64"
export APP_NAME="VaultCode"
export RELEASE_VERSION="1.4.3"
export SHOULD_BUILD_EXE_SYS="yes"
export SHOULD_BUILD_EXE_USR="yes"

echo "🧪 Test du script prepare_assets.sh"
echo "Variables:"
echo "  VSCODE_ARCH=$VSCODE_ARCH"
echo "  APP_NAME=$APP_NAME"
echo "  RELEASE_VERSION=$RELEASE_VERSION"
echo ""

cd test_prepare_assets

echo "📁 Fichiers avant traitement:"
find . -name "*.exe" -type f

echo ""
echo "🔄 Exécution des commandes de déplacement..."

# Test de la commande System Setup
if [[ "${SHOULD_BUILD_EXE_SYS}" != "no" ]]; then
  echo "Moving System EXE"
  echo "Commande: mv \"vscode\\.build\\win32-${VSCODE_ARCH}\\system-setup\\VSCodeSetup\"*.exe \"assets\\${APP_NAME}Setup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe\""

  # Version adaptée pour bash (sans échappement Windows)
  mv vscode/.build/win32-${VSCODE_ARCH}/system-setup/VSCodeSetup*.exe "assets/${APP_NAME}Setup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
  echo "✅ System setup déplacé avec succès"
fi

# Test de la commande User Setup
if [[ "${SHOULD_BUILD_EXE_USR}" != "no" ]]; then
  echo "Moving User EXE"
  echo "Commande: mv \"vscode\\.build\\win32-${VSCODE_ARCH}\\user-setup\\VSCodeUserSetup\"*.exe \"assets\\${APP_NAME}UserSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe\""

  # Version adaptée pour bash (sans échappement Windows)
  mv vscode/.build/win32-${VSCODE_ARCH}/user-setup/VSCodeUserSetup*.exe "assets/${APP_NAME}UserSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
  echo "✅ User setup déplacé avec succès"
fi

echo ""
echo "📁 Fichiers après traitement:"
find . -name "*.exe" -type f

echo ""
echo "🎉 Test terminé avec succès !"
