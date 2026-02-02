#!/bin/bash
PROJECT_ID="gen-lang-client-0074647990"

echo "📊 Deploying Truth Teller Dash..."
if [ -d "truth-teller-dash" ]; then
    cd truth-teller-dash
    npm install --no-audit && npm run build
    gcloud run deploy truth-teller-dash \
        --source . \
        --region us-central1 \
        --project $PROJECT_ID \
        --allow-unauthenticated \
        --quiet \
        --no-user-output-enabled
    cd ..
fi

echo "🔥 Deploying Firebase Apps..."
# This assumes firebase.json is in the root of Maroon-Core or the app subfolders
firebase deploy --project $PROJECT_ID
