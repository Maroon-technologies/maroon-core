# NEXT 15 CRITICAL STEPS - EXECUTION PLAN

## Priority: Corpus Organization and Governance (Start Now)

- Consolidate all `maroon*.md` into a single priority list and rewrite in order (system overview → rules → governance → architecture → execution).
- Freeze duplicates: mark redundant files and move them to `archive/duplicates/` after review.
- Establish a single “source of truth” folder tree and stop scattering new docs.
- Create a patents index that distinguishes filed vs. draft vs. opportunity.
- Align schemas and system specs to the Master Ontology before adding new features.

Proposed structure:
- `Maroon-Core/` (core source of truth)
- `Maroon-Core/docs/` (governance, rules, system overview)
- `Maroon-Core/patents/` (filed, draft, opportunities, valuation)
- `Maroon-Core/schemas/` (data models + migrations)
- `Maroon-Core/specs/` (engineering specs + runbooks)
- `Maroon-Core/runs/` (cycle outputs only)
- `archive/` (legacy, duplicates, external dumps)

Cleanup quick wins:
- Move large exports and raw dumps into `archive/` (keep originals).
- Remove stale reports that conflict with current counts (keep in archive).
- Keep only one active “portfolio” doc and one active “system overview” doc.

## Immediate Actions (Do These Now)

### Step 1-3: Deploy Live Website

```bash
# 1. Install Firebase CLI (if not already)
npm install -g firebase-tools

# 2. Login to Firebase
firebase login

# 3. Initialize and deploy
cd /Users/user1/Desktop/d9d3a104ccffaaced25a1a39fd6973a33055cfa64e6c4c88930d8a63763868ba-2026-02-01-16-51-09-7764e05a513d4615be1125c3811d675c/Maroon-Core
firebase init hosting
# Select: Use existing project or create new
# Public directory: . (current directory)
# Single-page app: Yes
# GitHub deploys: No (for now)

firebase deploy --only hosting
```

**Result**: Live website at `https://maroon-tech.web.app` or custom domain

---

### Step 4-5: Push to GitHub

```bash
# 4. Create GitHub repository
# Go to: https://github.com/new
# Name: Maroon-Core
# Description: Sovereign AI infrastructure for underserved communities
# Public/Private: Public (for credit applications)
# Do NOT initialize with README (we have one)

# 5. Push to GitHub
git remote add origin https://github.com/YOUR_USERNAME/Maroon-Core.git
git branch -M main
git push -u origin main
```

**Result**: Repository live at `https://github.com/YOUR_USERNAME/Maroon-Core`

---

### Step 6-7: Apply for Google Cloud Credits

**6. Navigate to Google for Startups**

- URL: <https://cloud.google.com/startup>
- Click "Apply Now" or "Get Started"
- Use email already in your inbox (check for existing thread)

**7. Complete Application Form**

Fill in using `business/GCP_STARTUP_APPLICATION.md`:

- **Company Name**: Maroon Technologies LLC
- **Website**: <https://maroon-tech.web.app> (your new Firebase site)
- **Company Description**:
  > Sovereign technology conglomerate building high-integrity AI systems for underserved communities. Core innovations: Truth Teller prediction engine and EBT Split transaction apparatus.

- **Founding Date**: 2024
- **Location**: Washington State, USA
- **Stage**: Pre-seed / Seed
- **Funding**: Self-funded via Maroon Trust

- **Problem Statement**:
  > Underserved communities lack sovereign infrastructure for essential services (Food, Law, Research). Currently, these corpus signals are fragmented and inaccessible, leading to systemic inefficiencies.

- **Solution**:
  > Maroon Technologies is building a high-integrity R&D ecosystem. Our core engine, Truth Teller, analyzes regulatory and market signals to drive vertical philanthropy and infrastructure. Our first major platform, Onitas Market, uses a patented EBT Split Transaction Apparatus to solve food-access audited transaction challenges.

- **Why Google Cloud**:
  > We require the scalability of BigQuery for our 2-year regulatory corpus (270MB+ signals) and the advanced agentic capabilities of Vertex AI to orchestrate our Master Orchestrator logic. The $100k+ credits will allow us to move from R&D to a production-grade rollout for 100k+ users in Washington State.

- **Tech Stack**:
  - AI/ML: Vertex AI, Gemini 1.5 Pro
  - Data: BigQuery, Cloud Spanner
  - Compute: GKE (Kubernetes Engine)
  - Integration: Firebase

- **Expected Monthly Spend**: $5,000-$10,000
- **Credit Amount Requested**: $100,000-$350,000

**Submit and monitor email for response**

---

### Step 8-9: Apply for AWS Activate

**8. Navigate to AWS Activate**

- URL: <https://aws.amazon.com/activate/>
- Click "Apply Now"
- Use email already in your inbox (check for existing thread)

**9. Complete Application Form**

Fill in using `business/AWS_ACTIVATE_APPLICATION.md`:

- **Company Name**: Maroon Foods LLC / Onitas Market
- **Website**: <https://maroon-tech.web.app>
- **Company Description**:
  > Onitas Market is a sovereign food marketplace designed specifically to handle complex regulatory requirements for WIC and EBT transactions. Our proprietary EBT Split Apparatus (Patent Pending) allows for seamless, real-time transaction forking at the point of sale.

- **Sector**: Retail / Logistics / FinTech
- **Location**: Washington State, USA

- **Product Description**:
  > Onitas Market is built on a serverless microservices architecture to handle high-concurrency during peak food-access distribution windows.

- **AWS Services Needed**:
  - Payment Processing: AWS Lambda + DynamoDB for high-speed split calculation (<200ms)
  - Logistics: Real-time integration with ShipDay and Shopify via EventBridge
  - Infrastructure: Amazon S3 for regulatory receipt storage and auditing

- **Use of Credits**:
  > The AWS Activate credits ($10k-$100k) will fund our initial production pilot in King County, WA. We aim to scale to 10k transactions per day within the first 6 months, requiring robust, scalable infrastructure that AWS provides.

- **Innovation**:
  > We are the first Black-owned company to implement a sovereign, audited split-transaction logic that directly addresses the "Hidden Profit Gem" of commissary kitchens as identified in the 2025 BCG Matrix.

- **Expected Monthly Spend**: $2,000-$5,000
- **Credit Amount Requested**: $10,000-$100,000

**Submit and monitor email for response**

---

### Step 10-11: Enable GitHub Copilot

**10. Enable Copilot for Repository**

- Go to: <https://github.com/settings/copilot>
- Enable GitHub Copilot (free trial or $10/month)
- Add Maroon-Core repository to allowed list

**11. Configure Copilot Instructions**
Create `.github/copilot-instructions.md`:

```markdown
# Maroon Empire Coding Standards

## Terminology
- Use "corpus" not "data"
- Use "ontology" for system architecture
- Use "sovereignty" for ownership principles

## Architecture
- Reference MASTER_ONTOLOGY.md for system design
- Follow ENGINEERING_GUIDELINES.md for code standards
- Use schema.org markup for all web content

## Documentation
- Link code to specific corpus sources
- Maintain traceability to protocols
- Ensure legal defensibility
```

---

### Step 12-13: Clean Up Disk Space

**12. Run Cleanup Commands**

```bash
# Clear caches (safe, ~400MB)
rm -rf ~/Library/Caches/Homebrew/*
rm -rf ~/Library/Caches/Google/*
rm -rf ~/Library/Caches/ms-playwright-go/*
rm -rf ~/Library/Caches/node-gyp/*
rm -rf ~/Library/Caches/pip/*
```

**13. Configure Google Drive Stream Mode**

- Open Google Drive app
- Settings → Preferences
- Select "Stream files" instead of "Mirror files"
- This frees ~4GB immediately

---

### Step 14: Monitor CloudDocs Sync

**Check what's syncing**:

```bash
ls -lah ~/Library/Application\ Support/CloudDocs/session/
```

**Options**:

1. **Wait**: Let iCloud finish syncing (recommended)
2. **Disable temporarily**: System Settings → iCloud → iCloud Drive → Off
3. **Selective sync**: Choose which folders to sync

**Goal**: Free 41GB once sync completes

---

### Step 15: Verify Deployment & Credits

**Checklist**:

- [ ] Website live at Firebase URL
- [ ] GitHub repository public and accessible
- [ ] GCP application submitted (check email for confirmation)
- [ ] AWS application submitted (check email for confirmation)
- [ ] Disk space <80% (run `df -h`)
- [ ] GitHub Copilot enabled
- [ ] schema.json validated at <https://validator.schema.org/>

---

## Email Monitoring

### For GCP Application

**Subject to watch for**: "Google for Startups Cloud Program Application"
**From**: <cloud-startup@google.com> or similar
**Action**: Respond promptly with any requested information
**Timeline**: 1-2 weeks for initial response

### For AWS Activate

**Subject to watch for**: "AWS Activate Application Status"
**From**: <aws-activate@amazon.com> or similar
**Action**: Respond promptly with any requested information
**Timeline**: 1-2 weeks for initial response

---

## Budget Tracking Post-Deployment

### Current Status

- Operational: $135 remaining of $150
- GCP Credits: $750 available (confirmed)
- GCP Pending: $100k-$350k (application in progress)
- AWS Pending: $10k-$100k (application in progress)

### Firebase Hosting Cost

- **Free Tier**: 10GB storage, 360MB/day transfer
- **Expected**: Well within free tier
- **Cost**: $0.00/month

### GitHub Cost

- **Repository**: Free (public)
- **Copilot**: $10/month (or free trial)
- **Actions**: Free tier (2,000 minutes/month)

---

## Success Metrics

After completing all 15 steps:

1. ✅ Live website with schema.org markup
2. ✅ GitHub repository with 227+ corpus files
3. ✅ GCP application submitted
4. ✅ AWS application submitted
5. ✅ Disk space freed (target: <80%)
6. ✅ GitHub Copilot integrated
7. ✅ All documentation aligned

**Total Time**: 2-3 hours for execution
**Total Cost**: $0-$10 (Copilot only, optional)
**Expected Credits**: $110k-$450k (if both applications approved)

---

## Critical Reminders

1. **Use the live website URL** in both applications
2. **Check email frequently** for application responses
3. **Respond within 24 hours** to any requests
4. **Keep schema.org updated** as products evolve
5. **Monitor disk space** daily until CloudDocs clears

---

*Created: 2026-02-01T15:21:00-08:00*
*Status: READY FOR EXECUTION*
