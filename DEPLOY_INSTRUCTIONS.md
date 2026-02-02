# DEPLOY INSTRUCTIONS - Get Live Apps in 5 Minutes

## What This Does

Deploys ALL Maroon Empire infrastructure to Google Cloud:

- ✅ 4 live web apps (click able URLs)
- ✅ BigQuery datasets with tables
- ✅ Cloud Functions (serverless backend)
- ✅ ERP database (PostgreSQL)
- ✅ $0 cost (free tier)

## Prerequisites

### 1. Install Google Cloud CLI

```bash
# Mac
brew install google-cloud-sdk

# Or download: https://cloud.google.com/sdk/docs/install
```

### 2. Login to Google Cloud

```bash
gcloud auth login
```

### 3. Set Your Project

```bash
# If you have a project:
gcloud config set project YOUR_PROJECT_ID

# If you need to create one:
gcloud projects create maroon-empire-PROJECT_ID
gcloud config set project maroon-empire-PROJECT_ID
```

### 4. Enable Billing (Free Tier Only)

- Go to: <https://console.cloud.google.com/billing>
- Link free trial ($300 credits) OR use your workspace credits
- Everything we deploy stays within free tier limits

## DEPLOY (One Command)

```bash
cd Maroon-Core
./deploy.sh
```

**That's it!** Script runs for ~15 minutes, then you have live apps.

## What You'll Get

### Live URLs

After deployment, you'll see:

```
Truth Teller Dash: https://truth-teller-dash-xxx.run.app
Onitas Market: https://maroon-empire-xxx.web.app  
Maroon Law: https://maroon-law-xxx.web.app
Nanny: https://nanny-xxx.web.app
```

Click any URL → Working app!

### BigQuery Console

- <https://console.cloud.google.com/bigquery?project=YOUR_PROJECT>
- 4 datasets created:
  - `maroon_corpus` - All conversation data
  - `usda_data` - Food desert data
  - `patent_data` - Patent tracking
  - `erp_data` - Financial system

### Cloud Functions

- `ebt-split-processor` - Patent 001 backend
- `multi-hub-router` - Patent 002 backend

## Costs

**Current usage: $0/month** (all free tier)

Free tier includes:

- Cloud Run: 180,000 vCPU-seconds/month
- BigQuery: 10 GB storage, 1 TB queries/month
- Firebase Hosting: 10 GB storage, 360 MB/day transfer
- Cloud Functions: 2M invocations/month
- Cloud SQL: f1-micro instance

You won't hit limits unless you get 100K+ visitors.

## Troubleshooting

### "gcloud: command not found"

```bash
# Install Google Cloud SDK first
brew install google-cloud-sdk
```

### "Permission denied: deploy.sh"

```bash
chmod +x deploy.sh
```

### "Billing account required"

- Enable free trial: <https://console.cloud.google.com/billing>
- You get $300 free credits, valid 90 days
- Everything we use is free tier anyway

### "API not enabled"

Script auto-enables, but if it fails:

```bash
gcloud services enable run.googleapis.com cloudfunctions.googleapis.com bigquery.googleapis.com
```

## Manual Deployment (If Script Fails)

### Deploy Truth Teller Dash Only

```bash
cd mvp/truth-teller-dash
gcloud run deploy truth-teller-dash --source . --region us-central1 --allow-unauthenticated
```

### Create BigQuery Dataset Only

```bash
bq mk --dataset maroon_corpus
```

### Deploy Firebase Only

```bash
cd mvp/onitas-market
firebase deploy
```

## Next Steps After Deployment

1. **Test Apps**: Click each URL, verify they load
2. **Load Data**: Import conversation corpus to BigQuery
3. **Run Queries**: Test patent analytics in BigQuery console
4. **Share URLs**: Send live links to Sean, investors, etc.

## Update Apps (After Code Changes)

Just run deploy script again:

```bash
./deploy.sh
```

It redeploys only changed apps (~2 minutes).

---

**Questions?** Check logs:

```bash
gcloud run logs read truth-teller-dash --region us-central1
```

**Physical result in 15 minutes: Live clickable apps!**
