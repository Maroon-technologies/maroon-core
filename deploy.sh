#!/bin/bash
# MAROON EMPIRE - ROBUST DEPLOYMENT SCRIPT
# This script is designed to be run from the /Maroon-Core directory.
# Features: Path auditing, local build verification, and GCP/Firebase deployment.

set -e

# --- CONFIGURATION ---
PROJECT_ID="gen-lang-client-0074647990"  # Verified from user edit
REGION="us-central1"
BASE_DIR="$(pwd)"

echo "🚀 MAROON EMPIRE: STARTING SYSTEM DEPLOYMENT..."
echo "📍 Base Directory: $BASE_DIR"

# --- 1. PRE-FLIGHT CHECKS ---
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ ERROR: $1 is not installed or not in PATH."
        exit 1
    fi
}

echo "🔍 Checking dependencies..."
check_dependency gcloud
check_dependency firebase
check_dependency npm

# --- 2. TRUTH TELLER DASH (Cloud Run) ---
echo "📊 DEPLOYING: Truth Teller Dash..."
cd "$BASE_DIR/mvp/truth-teller-dash"
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies for Truth Teller Dash..."
    npm install
fi

echo "🏗️ Building Truth Teller Dash..."
npm run build

echo "☁️ Deploying to Cloud Run..."
gcloud run deploy truth-teller-dash \
    --source . \
    --region $REGION \
    --project $PROJECT_ID \
    --allow-unauthenticated \
    --quiet

cd "$BASE_DIR"

# --- 3. FIREBASE APPS (Onitas Market, Maroon Law, Nanny) ---
echo "🔥 DEPLOYING: Firebase Suite..."

# Ensure we are in the root where firebase.json likely lives
if [ -f "firebase.json" ]; then
    # We need to build each app before deploying if they are hosted on Firebase
    build_app() {
        echo "🏗️ Building $1..."
        cd "$BASE_DIR/mvp/$1"
        if [ ! -d "node_modules" ]; then npm install; fi
        npm run build
        cd "$BASE_DIR"
    }

    build_app "onitas-market"
    build_app "maroon-law"
    #build_app "nanny" # Add if nanny has a build script

    echo "🚀 Pushing to Firebase..."
    firebase deploy --project $PROJECT_ID --only hosting,functions,firestore,storage
else
    echo "⚠️ WARNING: firebase.json not found in $BASE_DIR. Skipping Firebase deploy."
fi

echo ""
echo "✅ DEPLOYMENT SUCCESSFUL"
echo "🌐 DASHBOARD: https://console.cloud.google.com/run?project=$PROJECT_ID"
