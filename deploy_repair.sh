#!/bin/bash
PROJECT_ID="gen-lang-client-0074647990"

echo "🧹 Clearing npm cache to fix EEXIST error..."
npm cache clean --force
rm -rf ~/.npm/_cacache

# Find the right folder
if [ -d "truth-teller-dash" ]; then
    cd truth-teller-dash
fi

echo "📦 Installing dependencies..."
npm install --no-audit

echo "🏗️ Building..."
npm run build

echo "🚀 Deploying to Cloud Run (Bypassing Python Crash)..."
# We use --quiet and disable_prompts to stop the gcloud crash
gcloud config set disable_prompts True
gcloud run deploy truth-teller-dash \
    --source . \
    --region us-central1 \
    --project $PROJECT_ID \
    --allow-unauthenticated \
    --quiet \
    --no-user-output-enabled

echo "🔥 Deploying Firebase..."
cd ..
firebase deploy --only hosting,functions --project $PROJECT_ID
