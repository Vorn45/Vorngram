#!/bin/bash
set -e

echo "=============================================="
echo "🚀 Setting up Vorngram..."
echo "=============================================="

echo "[1/2] Installing Flutter mobile dependencies..."
flutter pub get

echo "[2/2] Installing companion server dependencies..."
cd server
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created server/.env from .env.example template"
fi
npm install
cd ..

echo ""
echo "=============================================="
echo "✅ Vorngram is fully set up and ready to run!"
echo ""
echo " - Mobile app:      flutter run"
echo " - Build APK:       flutter build apk --release"
echo " - Backend server:  cd server && npm start"
echo "=============================================="
