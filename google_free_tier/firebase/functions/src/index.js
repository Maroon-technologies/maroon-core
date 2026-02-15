const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { BigQuery } = require("@google-cloud/bigquery");
const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions, logger } = require("firebase-functions/v2");

setGlobalOptions({
  region: "us-central1",
  maxInstances: 1,
  timeoutSeconds: 120,
  memory: "512MiB"
});

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || "";
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || "";
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY || "";
const DEEPSEEK_BASE_URL = process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com/v1";
const GEMINI_DEFAULT_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";
const CLAUDE_DEFAULT_MODEL = process.env.CLAUDE_MODEL || "claude-3-5-sonnet-20241022";
const DEEPSEEK_DEFAULT_MODEL = process.env.DEEPSEEK_MODEL || "deepseek-chat";
const PRIMARY_PROVIDER = (process.env.PRIMARY_PROVIDER || "claude").toLowerCase();
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || "";
const BIGQUERY_PROJECT = process.env.BIGQUERY_PROJECT || process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
const BIGQUERY_DATASET = process.env.BIGQUERY_DATASET || "maroon_ops";
const BIGQUERY_LOCATION = process.env.BIGQUERY_LOCATION || "US";
const BQ_MAX_BYTES_BILLED_RAW = Number(process.env.BQ_MAX_BYTES_BILLED || 500000000);
const BQ_MAX_BYTES_BILLED = Number.isFinite(BQ_MAX_BYTES_BILLED_RAW) && BQ_MAX_BYTES_BILLED_RAW > 0
  ? Math.floor(BQ_MAX_BYTES_BILLED_RAW)
  : 500000000;
const DEFAULT_BQ_ALLOWLIST = [
  "executive_data_plane_overview",
  "maroon_architecture_runs",
  "maroon_architecture_lineage",
  "maroon_complete_picture_runs",
  "maroon_complete_picture_system_registry",
  "maroon_execution_tickets",
  "maroon_counsel_ip_queue",
  "maroon_asset_ownership_registry",
  "maroon_hidden_gems_docket",
  "maroon_redteam_gap_register",
  "maroon_db_embedding_forensic_inspection",
  "maroon_corpus_quality_overview",
  "maroon_corpus_gap_register",
  "maroon_corpus_file_inventory"
];
const BQ_FILTER_OPS = new Set([
  "eq",
  "neq",
  "gt",
  "gte",
  "lt",
  "lte",
  "in",
  "not_in",
  "contains",
  "is_null",
  "is_not_null"
]);
const BQ_ALLOWLIST = new Set(
  (process.env.MAROON_BQ_ALLOWLIST || DEFAULT_BQ_ALLOWLIST.join(","))
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
);
const FIREBASE_AUTH_REQUIRED = asBoolean(process.env.MAROON_REQUIRE_FIREBASE_AUTH, true);
const FIREBASE_REQUIRE_EMAIL_VERIFIED = asBoolean(process.env.MAROON_REQUIRE_EMAIL_VERIFIED, true);
const FIREBASE_ALLOWED_EMAILS = new Set(
  (process.env.MAROON_AUTH_ALLOWED_EMAILS || "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean)
);
const FIREBASE_ALLOWED_DOMAINS = new Set(
  (process.env.MAROON_AUTH_ALLOWED_DOMAINS || "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean)
);
const OPERATOR_ROLE_VALUES = new Set(["founder", "counsel", "engineer"]);
const DEFAULT_OPERATOR_ROLE_RAW = asString(process.env.MAROON_DEFAULT_ROLE, "engineer").trim().toLowerCase();
const DEFAULT_OPERATOR_ROLE = OPERATOR_ROLE_VALUES.has(DEFAULT_OPERATOR_ROLE_RAW)
  ? DEFAULT_OPERATOR_ROLE_RAW
  : "engineer";
const ROLE_BOOTSTRAP_KEY = asString(process.env.MAROON_ROLE_ADMIN_KEY, "").trim();
const ROLE_TABLE_ACCESS = {
  founder: new Set(Array.from(BQ_ALLOWLIST.values())),
  counsel: new Set([
    "executive_data_plane_overview",
    "maroon_complete_picture_runs",
    "maroon_counsel_ip_queue",
    "maroon_asset_ownership_registry",
    "maroon_redteam_gap_register"
  ]),
  engineer: new Set(Array.from(BQ_ALLOWLIST.values()))
};
const ENDPOINT_ROLE_ACCESS = {
  commandCenterSnapshot: new Set(["founder", "counsel", "engineer"]),
  bigQueryRead: new Set(["founder", "counsel", "engineer"]),
  assistantQuery: new Set(["founder", "counsel", "engineer"]),
  getOperatorProfile: new Set(["founder", "counsel", "engineer"]),
  setOperatorRoleClaim: new Set(["founder"])
};
const EMBEDDING_MODEL_CANDIDATES = (
  process.env.GEMINI_EMBED_MODELS || "gemini-embedding-001,text-embedding-004"
)
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);
const bq = new BigQuery(BIGQUERY_PROJECT ? { projectId: BIGQUERY_PROJECT } : {});

function redactSensitive(input) {
  return String(input || "")
    .replace(/\b\d{3}-\d{2}-\d{4}\b/g, "[REDACTED_SSN]")
    .replace(/\b(?:\d[ -]*?){13,16}\b/g, "[REDACTED_CARD]")
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[REDACTED_EMAIL]");
}

function setCors(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return true;
  }
  return false;
}

function asString(value, fallback = "") {
  if (typeof value === "string") return value;
  if (value == null) return fallback;
  return String(value);
}

function asNumber(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function asBoolean(value, fallback = false) {
  if (typeof value === "boolean") return value;
  if (typeof value !== "string") return fallback;
  const normalized = value.trim().toLowerCase();
  if (normalized === "true") return true;
  if (normalized === "false") return false;
  return fallback;
}

function clip(text, max = 3000) {
  const s = asString(text, "");
  return s.length <= max ? s : `${s.slice(0, max)}...`;
}

function sanitizeIdentifier(value) {
  const candidate = asString(value, "").trim();
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(candidate)) {
    throw new Error(`invalid identifier: ${candidate}`);
  }
  return candidate;
}

function sanitizeProjectId(value) {
  const candidate = asString(value, "").trim();
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(candidate)) {
    throw new Error(`invalid project id: ${candidate}`);
  }
  return candidate;
}

function resolveQueryProject() {
  if (BIGQUERY_PROJECT) return BIGQUERY_PROJECT;
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  if (process.env.GCP_PROJECT) return process.env.GCP_PROJECT;
  throw new Error("BIGQUERY_PROJECT/GCLOUD_PROJECT is not configured");
}

function getQualifiedTable(tableName) {
  const normalized = sanitizeIdentifier(tableName);
  if (!BQ_ALLOWLIST.has(normalized)) {
    throw new Error(`table not allowlisted: ${normalized}`);
  }
  const project = sanitizeProjectId(resolveQueryProject());
  const dataset = sanitizeIdentifier(BIGQUERY_DATASET);
  return `\`${project}.${dataset}.${normalized}\``;
}

async function runBigQuery(query, params = {}) {
  const [job] = await bq.createQueryJob({
    query,
    params,
    useLegacySql: false,
    location: BIGQUERY_LOCATION,
    maximumBytesBilled: BQ_MAX_BYTES_BILLED
  });
  const [rows] = await job.getQueryResults();
  return { rows, jobId: job.id || "" };
}

async function readSingleMetric(query, params = {}) {
  const result = await runBigQuery(query, params);
  return {
    row: Array.isArray(result.rows) && result.rows.length > 0 ? result.rows[0] : {},
    job_id: result.jobId
  };
}

function jsonSafe(value) {
  try {
    return JSON.parse(JSON.stringify(value));
  } catch (_) {
    return value;
  }
}

function extractBearerToken(req) {
  const authHeader = asString(req.headers && req.headers.authorization, "").trim();
  if (!authHeader.toLowerCase().startsWith("bearer ")) return "";
  return authHeader.slice(7).trim();
}

function isScalarFilterValue(value) {
  const t = typeof value;
  return t === "string" || t === "number" || t === "boolean";
}

function normalizeOperatorRole(value, fallback = DEFAULT_OPERATOR_ROLE) {
  const candidate = asString(value, fallback).trim().toLowerCase();
  if (OPERATOR_ROLE_VALUES.has(candidate)) return candidate;
  return fallback;
}

function extractOperatorRoles(decoded) {
  const claimed = Array.isArray(decoded && decoded.maroon_roles)
    ? decoded.maroon_roles
    : [];
  const normalized = claimed
    .map((role) => normalizeOperatorRole(role, ""))
    .filter(Boolean);
  const roleFromPrimaryClaim = normalizeOperatorRole(
    decoded && (decoded.maroon_role || decoded.role),
    ""
  );
  if (roleFromPrimaryClaim && !normalized.includes(roleFromPrimaryClaim)) {
    normalized.push(roleFromPrimaryClaim);
  }
  if (normalized.length === 0) {
    normalized.push(DEFAULT_OPERATOR_ROLE);
  }
  return normalized;
}

function hasRoleBootstrapKey(req) {
  if (!ROLE_BOOTSTRAP_KEY) return false;
  const headerKey = asString(req.headers && req.headers["x-maroon-admin-key"], "").trim();
  const bodyKey = asString(req.body && req.body.admin_key, "").trim();
  const candidate = headerKey || bodyKey;
  if (!candidate) return false;
  const expectedBuf = Buffer.from(ROLE_BOOTSTRAP_KEY);
  const providedBuf = Buffer.from(candidate);
  if (expectedBuf.length !== providedBuf.length) return false;
  return crypto.timingSafeEqual(expectedBuf, providedBuf);
}

function ensureEndpointRole(res, operator, endpointName) {
  const allowed = ENDPOINT_ROLE_ACCESS[endpointName];
  if (!allowed || allowed.size === 0) return true;
  const role = normalizeOperatorRole(operator && operator.role, DEFAULT_OPERATOR_ROLE);
  if (allowed.has(role)) return true;
  res.status(403).json({
    error: "auth_role_not_allowed",
    detail: `Role ${role} is not allowed for ${endpointName}.`,
    endpoint: endpointName,
    allowed_roles: Array.from(allowed.values()).sort()
  });
  return false;
}

function ensureTableRole(role, table) {
  const normalizedRole = normalizeOperatorRole(role, DEFAULT_OPERATOR_ROLE);
  const allowedTables = ROLE_TABLE_ACCESS[normalizedRole] || new Set();
  if (allowedTables.has(table)) return true;
  return false;
}

async function hasFounderClaim() {
  let pageToken = undefined;
  for (let i = 0; i < 10; i += 1) {
    const page = await admin.auth().listUsers(1000, pageToken);
    for (const user of page.users || []) {
      const claims = user.customClaims || {};
      const role = normalizeOperatorRole(claims.maroon_role || claims.role, "");
      if (role === "founder") return true;
      if (Array.isArray(claims.maroon_roles)) {
        const hasFounderRole = claims.maroon_roles
          .map((entry) => normalizeOperatorRole(entry, ""))
          .includes("founder");
        if (hasFounderRole) return true;
      }
    }
    if (!page.pageToken) return false;
    pageToken = page.pageToken;
  }
  return false;
}

async function requireFirebaseOperator(req, res) {
  if (!FIREBASE_AUTH_REQUIRED) {
    return {
      uid: "auth_bypass",
      email: "",
      provider: "bypass",
      role: "founder",
      roles: ["founder"]
    };
  }

  const token = extractBearerToken(req);
  if (!token) {
    res.status(401).json({
      error: "auth_required",
      detail: "Provide Firebase ID token in Authorization: Bearer <token>."
    });
    return null;
  }

  let decoded;
  try {
    decoded = await admin.auth().verifyIdToken(token);
  } catch (err) {
    logger.warn("firebase_auth_invalid_token", { message: err && err.message ? err.message : String(err) });
    res.status(401).json({
      error: "auth_invalid",
      detail: "Token verification failed."
    });
    return null;
  }

  const email = asString(decoded.email, "").toLowerCase();
  const emailDomain = email.includes("@") ? email.split("@").pop() : "";
  const emailVerified = decoded.email_verified === true;

  if (FIREBASE_REQUIRE_EMAIL_VERIFIED && !emailVerified) {
    res.status(403).json({
      error: "auth_unverified_email",
      detail: "Verified email is required."
    });
    return null;
  }

  if (FIREBASE_ALLOWED_EMAILS.size > 0 && !FIREBASE_ALLOWED_EMAILS.has(email)) {
    res.status(403).json({
      error: "auth_email_not_allowed",
      detail: "Account is not allowlisted."
    });
    return null;
  }

  if (FIREBASE_ALLOWED_DOMAINS.size > 0 && !FIREBASE_ALLOWED_DOMAINS.has(emailDomain)) {
    res.status(403).json({
      error: "auth_domain_not_allowed",
      detail: "Email domain is not allowlisted."
    });
    return null;
  }

  const roles = extractOperatorRoles(decoded);
  const primaryRole = normalizeOperatorRole(decoded.maroon_role || decoded.role || roles[0], DEFAULT_OPERATOR_ROLE);
  return {
    uid: asString(decoded.uid, ""),
    email,
    provider: "firebase_auth",
    role: primaryRole,
    roles,
    email_verified: emailVerified
  };
}

function normalizeProvider(value) {
  const p = asString(value, PRIMARY_PROVIDER).toLowerCase().trim();
  if (p === "claude" || p === "gemini" || p === "deepseek") return p;
  if (PRIMARY_PROVIDER === "gemini") return "gemini";
  if (PRIMARY_PROVIDER === "deepseek") return "deepseek";
  return "claude";
}

function makeId(prefix, parts = []) {
  const h = crypto
    .createHash("sha256")
    .update(parts.join("|"))
    .digest("hex")
    .slice(0, 24);
  return `${prefix}_${h}`;
}

function cosineSimilarity(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length || a.length === 0) {
    return -1;
  }
  let dot = 0;
  let magA = 0;
  let magB = 0;
  for (let i = 0; i < a.length; i += 1) {
    const av = Number(a[i]);
    const bv = Number(b[i]);
    if (!Number.isFinite(av) || !Number.isFinite(bv)) return -1;
    dot += av * bv;
    magA += av * av;
    magB += bv * bv;
  }
  const denom = Math.sqrt(magA) * Math.sqrt(magB);
  if (!Number.isFinite(denom) || denom === 0) return -1;
  return dot / denom;
}

function parseGithubRepo(repoUrl) {
  const raw = asString(repoUrl, "").trim();
  if (!raw) return null;
  const fromSlug = raw.match(/^([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)$/);
  if (fromSlug) {
    return { owner: fromSlug[1], repo: fromSlug[2].replace(/\.git$/i, "") };
  }
  try {
    const u = new URL(raw);
    if (!/github\.com$/i.test(u.hostname)) return null;
    const parts = u.pathname.replace(/^\/+|\/+$/g, "").split("/");
    if (parts.length < 2) return null;
    return {
      owner: parts[0],
      repo: parts[1].replace(/\.git$/i, "")
    };
  } catch (_) {
    return null;
  }
}

async function fetchGithubJson(path) {
  const headers = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "maroon-signal-console"
  };
  if (GITHUB_TOKEN) headers.Authorization = `Bearer ${GITHUB_TOKEN}`;
  const resp = await fetch(`https://api.github.com${path}`, { headers });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(`GitHub API error ${resp.status}: ${clip(JSON.stringify(data), 500)}`);
  }
  return data;
}

async function fetchGithubRepoContext(repoUrl) {
  const parsed = parseGithubRepo(repoUrl);
  if (!parsed) return null;
  const slug = `${parsed.owner}/${parsed.repo}`;

  const [repoData, commitsData] = await Promise.all([
    fetchGithubJson(`/repos/${slug}`),
    fetchGithubJson(`/repos/${slug}/commits?per_page=8`)
  ]);

  let readmeText = "";
  try {
    const readmeData = await fetchGithubJson(`/repos/${slug}/readme`);
    if (readmeData && readmeData.content) {
      readmeText = Buffer.from(readmeData.content, "base64").toString("utf8");
    }
  } catch (_) {
    // README can be absent or access-restricted; do not fail the full run.
  }

  return {
    repo: slug,
    default_branch: repoData.default_branch || "",
    stars: repoData.stargazers_count || 0,
    open_issues: repoData.open_issues_count || 0,
    description: clip(repoData.description || "", 240),
    readme_excerpt: clip(readmeText, 2200),
    recent_commits: Array.isArray(commitsData)
      ? commitsData.map((c) => ({
          sha: asString(c.sha, "").slice(0, 8),
          message: clip(c && c.commit && c.commit.message, 180),
          author: asString(c && c.commit && c.commit.author && c.commit.author.name, "")
        }))
      : []
  };
}

async function geminiCall(path, payload) {
  if (!GEMINI_API_KEY) {
    throw new Error("GEMINI_API_KEY (or GOOGLE_API_KEY) is not configured");
  }
  const url = `https://generativelanguage.googleapis.com/v1beta/${path}?key=${encodeURIComponent(GEMINI_API_KEY)}`;
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(`Gemini API error ${resp.status}: ${clip(JSON.stringify(data), 1000)}`);
  }
  return data;
}

async function generateWithGemini({ prompt, system = "", model = GEMINI_DEFAULT_MODEL, temperature = 0.2 }) {
  const payload = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature,
      maxOutputTokens: 1200
    }
  };
  if (system.trim()) {
    payload.systemInstruction = { parts: [{ text: system }] };
  }
  const data = await geminiCall(`models/${encodeURIComponent(model)}:generateContent`, payload);
  const text = (data.candidates || [])
    .flatMap((c) => ((c.content && c.content.parts) || []).map((p) => p.text || ""))
    .join("\n")
    .trim();
  if (!text) {
    throw new Error("Gemini returned no text output");
  }
  return { text, model };
}

async function embedWithGemini(text) {
  let lastErr = null;
  for (const model of EMBEDDING_MODEL_CANDIDATES) {
    try {
      const data = await geminiCall(`models/${encodeURIComponent(model)}:embedContent`, {
        content: { parts: [{ text }] }
      });
      const values = data?.embedding?.values;
      if (Array.isArray(values) && values.length > 0) {
        return {
          embedding: values,
          model
        };
      }
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr || new Error("Unable to compute embeddings from Gemini");
}

async function generateWithClaude({ prompt, system = "", model = CLAUDE_DEFAULT_MODEL, temperature = 0.2 }) {
  if (!ANTHROPIC_API_KEY) {
    throw new Error("ANTHROPIC_API_KEY is not configured");
  }
  const payload = {
    model,
    max_tokens: 1200,
    temperature,
    messages: [{ role: "user", content: prompt }]
  };
  if (system.trim()) {
    payload.system = system;
  }
  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01"
    },
    body: JSON.stringify(payload)
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(`Claude API error ${resp.status}: ${clip(JSON.stringify(data), 1000)}`);
  }
  const text = (data.content || [])
    .filter((part) => part.type === "text")
    .map((part) => part.text || "")
    .join("\n")
    .trim();
  if (!text) {
    throw new Error("Claude returned no text output");
  }
  return { text, model };
}

async function generateWithDeepSeek({ prompt, system = "", model = DEEPSEEK_DEFAULT_MODEL, temperature = 0.2 }) {
  if (!DEEPSEEK_API_KEY) {
    throw new Error("DEEPSEEK_API_KEY is not configured");
  }
  const base = DEEPSEEK_BASE_URL.replace(/\/+$/, "");
  const messages = [];
  if (system.trim()) {
    messages.push({ role: "system", content: system });
  }
  messages.push({ role: "user", content: prompt });
  const payload = {
    model,
    temperature,
    max_tokens: 1200,
    messages
  };
  const resp = await fetch(`${base}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${DEEPSEEK_API_KEY}`
    },
    body: JSON.stringify(payload)
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(`DeepSeek API error ${resp.status}: ${clip(JSON.stringify(data), 1000)}`);
  }
  const text = asString(
    data &&
      data.choices &&
      data.choices[0] &&
      data.choices[0].message &&
      data.choices[0].message.content,
    ""
  ).trim();
  if (!text) {
    throw new Error("DeepSeek returned no text output");
  }
  return { text, model };
}

async function callProvider({ provider, prompt, system = "", model = "", temperature = 0.2 }) {
  if (provider === "claude") {
    const result = await generateWithClaude({
      prompt,
      system,
      model: model || CLAUDE_DEFAULT_MODEL,
      temperature
    });
    return { ...result, provider: "claude" };
  }
  if (provider === "gemini") {
    const result = await generateWithGemini({
      prompt,
      system,
      model: model || GEMINI_DEFAULT_MODEL,
      temperature
    });
    return { ...result, provider: "gemini" };
  }
  if (provider === "deepseek") {
    const result = await generateWithDeepSeek({
      prompt,
      system,
      model: model || DEEPSEEK_DEFAULT_MODEL,
      temperature
    });
    return { ...result, provider: "deepseek" };
  }
  throw new Error("provider must be gemini, claude, or deepseek");
}

async function logArtifact(payload) {
  try {
    await db.collection("artifacts").add({
      ...payload,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (err) {
    logger.error("artifact_log_failed", err);
  }
}

exports.ingestLearningEvent = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const source = asString(req.body && req.body.source, "unknown");
  const summary = asString(req.body && req.body.summary, "");
  const learnedAt = asString(req.body && req.body.learned_at, new Date().toISOString());

  if (!summary.trim()) {
    res.status(400).json({ error: "summary is required" });
    return;
  }

  const redacted = redactSensitive(summary);
  await db.collection("learning_events").add({
    source,
    learned_at: learnedAt,
    summary: redacted,
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });
  await logArtifact({
    type: "learning_event",
    source,
    summary_preview: clip(redacted, 300)
  });
  res.status(200).json({ status: "ok", data: {
    source,
    learned_at: learnedAt,
    summary: redacted
  }});
});

exports.upsertTask = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const id = asString(req.body && req.body.id, "").trim();
  const title = asString(req.body && req.body.title, "").trim();
  const priority = asString(req.body && req.body.priority, "P2");
  const status = asString(req.body && req.body.status, "open");
  const details = asString(req.body && req.body.details, "");

  if (!id || !title) {
    res.status(400).json({ error: "id and title are required" });
    return;
  }

  await db.collection("tasks").doc(id).set({
    id,
    title,
    priority,
    status,
    details: redactSensitive(details),
    updated_at: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  await logArtifact({
    type: "task_upsert",
    task_id: id,
    title_preview: clip(title, 140),
    priority,
    status
  });
  res.status(200).json({
    status: "ok",
    task: { id, title, priority, status }
  });
});

exports.quotaSnapshot = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  const payload = {
    status: "ok",
    captured_at: new Date().toISOString(),
    budget_usd: 0,
    policy: "free-tier-only",
    primary_provider: PRIMARY_PROVIDER,
    model_keys: {
      gemini_configured: Boolean(GEMINI_API_KEY),
      claude_configured: Boolean(ANTHROPIC_API_KEY),
      deepseek_configured: Boolean(DEEPSEEK_API_KEY)
    }
  };
  await db.collection("quota_snapshots").add({
    ...payload,
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });
  res.status(200).json(payload);
});

exports.modelRouter = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const provider = normalizeProvider(req.body && req.body.provider);
  const prompt = asString(req.body && req.body.prompt, "").trim();
  const system = asString(req.body && req.body.system, "");
  const model = asString(req.body && req.body.model, "");
  const temperature = asNumber(req.body && req.body.temperature, 0.2);
  const redactBeforeSend = req.body && req.body.redact_before_send !== false;
  const useCache = req.body && req.body.use_cache !== false;
  const cacheTtlSeconds = Math.max(0, Math.min(asNumber(req.body && req.body.cache_ttl_seconds, 21600), 604800));

  if (!prompt) {
    res.status(400).json({ error: "prompt is required" });
    return;
  }

  const outboundPrompt = redactBeforeSend ? redactSensitive(prompt) : prompt;
  const cacheKey = asString(req.body && req.body.cache_key, "").trim() || makeId("mcache", [
    provider,
    model,
    system,
    outboundPrompt
  ]);
  try {
    if (useCache) {
      const cachedSnap = await db.collection("model_cache").doc(cacheKey).get();
      if (cachedSnap.exists) {
        const cached = cachedSnap.data() || {};
        const nowMs = Date.now();
        const cachedAtMs = Number(cached.cached_at_epoch_ms || 0);
        const ageSeconds = Math.floor(Math.max(0, nowMs - cachedAtMs) / 1000);
        if (cachedAtMs > 0 && ageSeconds <= cacheTtlSeconds) {
          res.status(200).json({
            status: "ok",
            cached: true,
            cache_key: cacheKey,
            provider,
            model: cached.model || model || (provider === "claude" ? CLAUDE_DEFAULT_MODEL : GEMINI_DEFAULT_MODEL),
            text: asString(cached.text, "")
          });
          return;
        }
      }
    }

    const result = await callProvider({
      provider,
      prompt: outboundPrompt,
      system,
      model,
      temperature
    });

    const nowMs = Date.now();
    await db.collection("model_cache").doc(cacheKey).set({
      cache_key: cacheKey,
      provider,
      model: result.model,
      text: result.text,
      prompt_preview: clip(outboundPrompt, 400),
      system_preview: clip(system, 400),
      cached_at_epoch_ms: nowMs,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    await db.collection("model_calls").add({
      provider,
      model: result.model,
      redact_before_send: redactBeforeSend,
      cached: false,
      cache_key: cacheKey,
      prompt_preview: clip(outboundPrompt, 500),
      response_preview: clip(result.text, 500),
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
    await logArtifact({
      type: "model_response",
      provider,
      model: result.model,
      prompt_preview: clip(outboundPrompt, 300),
      response_preview: clip(result.text, 300)
    });

    res.status(200).json({
      status: "ok",
      cached: false,
      cache_key: cacheKey,
      provider,
      model: result.model,
      text: result.text
    });
  } catch (err) {
    logger.error("model_router_failed", err);
    res.status(500).json({
      error: "model_router_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200)
    });
  }
});

exports.claudeBuildPipeline = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const goal = asString(req.body && req.body.goal, "").trim();
  const repoUrl = asString(req.body && req.body.repo_url, "").trim();
  const corpusContextRaw = asString(req.body && req.body.corpus_context, "");
  const useGeminiRewrite = req.body && req.body.use_gemini_rewrite !== false;
  const includeRepoContext = req.body && req.body.include_repo_context !== false;
  const maxContextChars = Math.max(1000, Math.min(asNumber(req.body && req.body.max_context_chars, 24000), 120000));
  const temperature = asNumber(req.body && req.body.temperature, 0.2);
  const rewriteModel = asString(req.body && req.body.rewrite_model, "");
  const claudeModel = asString(req.body && req.body.claude_model, "");
  const system = asString(req.body && req.body.system, "").trim() || [
    "You are a principal software architect and security engineer.",
    "Produce production-ready build and hardening guidance.",
    "Prefer measurable, testable, and incremental steps.",
    "Never instruct destructive corpus mutation."
  ].join(" ");

  if (!goal) {
    res.status(400).json({ error: "goal is required" });
    return;
  }
  if (!ANTHROPIC_API_KEY) {
    res.status(500).json({ error: "claude_not_configured", detail: "ANTHROPIC_API_KEY is not configured" });
    return;
  }

  const runId = makeId("build", [goal, repoUrl, corpusContextRaw.slice(0, 500)]);
  const corpusContext = clip(corpusContextRaw, maxContextChars);
  let corpusBrief = corpusContext;
  let rewriteMeta = { used: false, provider: "none", model: "" };

  try {
    if (useGeminiRewrite && GEMINI_API_KEY && corpusContext.trim()) {
      const rewritePrompt = [
        "Goal:",
        goal,
        "",
        "Normalize this corpus into a concise build brief for an app hardening implementation.",
        "Keep key systems, inventions, business constraints, and integration facts.",
        "Output sections: Required Scope, Existing Assets, Risks, Build Priorities, Non-Negotiables.",
        "",
        "Corpus:",
        corpusContext
      ].join("\n");
      const rewrite = await generateWithGemini({
        prompt: rewritePrompt,
        model: rewriteModel || GEMINI_DEFAULT_MODEL,
        temperature: 0.1
      });
      corpusBrief = clip(rewrite.text, 18000);
      rewriteMeta = { used: true, provider: "gemini", model: rewrite.model };
    }

    let repoContext = null;
    if (includeRepoContext && repoUrl) {
      repoContext = await fetchGithubRepoContext(repoUrl);
    }

    const prompt = [
      "Build Goal:",
      goal,
      "",
      repoContext
        ? `GitHub Context (JSON):\n${clip(JSON.stringify(repoContext), 6000)}`
        : "GitHub Context: none provided",
      "",
      "Corpus Build Brief:",
      corpusBrief || "(empty)",
      "",
      "Return a markdown response with exactly these top-level sections:",
      "1) Architecture Blueprint",
      "2) Security Hardening Plan",
      "3) Implementation Backlog (P0/P1/P2)",
      "4) Test and Verification Plan",
      "5) First 10 GitHub Tasks",
      "Be concrete and implementation-ready."
    ].join("\n");

    const claude = await generateWithClaude({
      prompt,
      system,
      model: claudeModel || CLAUDE_DEFAULT_MODEL,
      temperature
    });

    await db.collection("build_runs").doc(runId).set({
      run_id: runId,
      goal: clip(goal, 500),
      repo_url: repoUrl,
      used_gemini_rewrite: rewriteMeta.used,
      rewrite_provider: rewriteMeta.provider,
      rewrite_model: rewriteMeta.model,
      claude_model: claude.model,
      output_preview: clip(claude.text, 1200),
      created_at: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    await logArtifact({
      type: "claude_build_pipeline",
      run_id: runId,
      repo_url: repoUrl,
      rewrite_used: rewriteMeta.used,
      claude_model: claude.model,
      output_preview: clip(claude.text, 300)
    });

    res.status(200).json({
      status: "ok",
      run_id: runId,
      provider: "claude",
      model: claude.model,
      rewrite: rewriteMeta,
      repo_context: repoContext
        ? {
            repo: repoContext.repo,
            stars: repoContext.stars,
            commits: Array.isArray(repoContext.recent_commits) ? repoContext.recent_commits.length : 0
          }
        : null,
      text: claude.text
    });
  } catch (err) {
    logger.error("claude_build_pipeline_failed", err);
    res.status(500).json({
      error: "claude_build_pipeline_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200)
    });
  }
});

exports.upsertVectorChunk = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const namespace = asString(req.body && req.body.namespace, "default").trim() || "default";
  const sourcePath = asString(req.body && req.body.source_path, "");
  const text = asString(req.body && req.body.text, "").trim();
  const explicitId = asString(req.body && req.body.id, "").trim();
  const nowIso = new Date().toISOString();

  if (!text) {
    res.status(400).json({ error: "text is required" });
    return;
  }

  let embedding = Array.isArray(req.body && req.body.embedding) ? req.body.embedding : null;
  let embeddingModel = asString(req.body && req.body.embedding_model, "");

  try {
    if (!embedding || embedding.length === 0) {
      const embedded = await embedWithGemini(text);
      embedding = embedded.embedding;
      embeddingModel = embedded.model;
    }

    if (!Array.isArray(embedding) || embedding.length === 0) {
      res.status(400).json({ error: "embedding must be a non-empty number array" });
      return;
    }

    const docId = explicitId || makeId("vec", [namespace, sourcePath, text.slice(0, 200)]);
    await db.collection("vector_chunks").doc(docId).set({
      id: docId,
      namespace,
      source_path: sourcePath,
      text,
      text_preview: clip(text, 500),
      embedding,
      embedding_dims: embedding.length,
      embedding_model: embeddingModel || "external",
      updated_at: nowIso,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    await logArtifact({
      type: "vector_chunk_upsert",
      vector_id: docId,
      namespace,
      source_path: sourcePath,
      dims: embedding.length
    });

    res.status(200).json({
      status: "ok",
      id: docId,
      namespace,
      embedding_dims: embedding.length,
      embedding_model: embeddingModel
    });
  } catch (err) {
    logger.error("vector_upsert_failed", err);
    res.status(500).json({
      error: "vector_upsert_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200)
    });
  }
});

exports.vectorSearch = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const namespace = asString(req.body && req.body.namespace, "default").trim() || "default";
  const query = asString(req.body && req.body.query, "").trim();
  const k = Math.min(Math.max(asNumber(req.body && req.body.k, 8), 1), 50);
  const maxScan = Math.min(Math.max(asNumber(req.body && req.body.max_scan, 400), 10), 2000);

  if (!query) {
    res.status(400).json({ error: "query is required" });
    return;
  }

  try {
    const embedded = await embedWithGemini(query);
    const queryEmbedding = embedded.embedding;
    const snap = await db.collection("vector_chunks")
      .where("namespace", "==", namespace)
      .limit(maxScan)
      .get();

    const scored = [];
    snap.forEach((doc) => {
      const data = doc.data() || {};
      const score = cosineSimilarity(queryEmbedding, data.embedding || []);
      if (score < -0.5) return;
      scored.push({
        id: doc.id,
        score,
        source_path: data.source_path || "",
        text_preview: clip(data.text_preview || data.text || "", 400),
        embedding_dims: data.embedding_dims || 0
      });
    });

    scored.sort((a, b) => b.score - a.score);
    const top = scored.slice(0, k);
    await logArtifact({
      type: "vector_search",
      namespace,
      query_preview: clip(query, 240),
      returned: top.length,
      scanned: snap.size
    });

    res.status(200).json({
      status: "ok",
      namespace,
      embedding_model: embedded.model,
      scanned: snap.size,
      results: top
    });
  } catch (err) {
    logger.error("vector_search_failed", err);
    res.status(500).json({
      error: "vector_search_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200)
    });
  }
});

exports.commandCenterSnapshot = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST" && req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const operator = await requireFirebaseOperator(req, res);
    if (!operator) return;
    if (!ensureEndpointRole(res, operator, "commandCenterSnapshot")) return;

    const overviewTable = getQualifiedTable("executive_data_plane_overview");
    const completeRunsTable = getQualifiedTable("maroon_complete_picture_runs");
    const ticketsTable = getQualifiedTable("maroon_execution_tickets");
    const counselTable = getQualifiedTable("maroon_counsel_ip_queue");
    const redteamTable = getQualifiedTable("maroon_redteam_gap_register");
    const forensicTable = getQualifiedTable("maroon_db_embedding_forensic_inspection");

    const [
      overview,
      completePicture,
      tickets,
      counsel,
      redteam,
      forensic
    ] = await Promise.all([
      readSingleMetric(`SELECT * FROM ${overviewTable} LIMIT 1`),
      readSingleMetric(
        `SELECT run_id, generated_at, systems_total, systems_after_compression, structural_review_count, invention_candidates_count, artifact_count, alignment_score FROM ${completeRunsTable} ORDER BY generated_at DESC LIMIT 1`
      ),
      readSingleMetric(
        `SELECT COUNT(*) AS tickets_open, SUM(CASE WHEN priority = 'P1' THEN 1 ELSE 0 END) AS p1_open FROM ${ticketsTable} WHERE status = 'open'`
      ),
      readSingleMetric(
        `SELECT COUNT(*) AS counsel_open, SUM(CASE WHEN queue_status = 'evidence_bundle_required' THEN 1 ELSE 0 END) AS evidence_bundle_required FROM ${counselTable} WHERE queue_status IN ('open', 'evidence_bundle_required')`
      ),
      readSingleMetric(
        `SELECT COUNT(*) AS open_gaps, SUM(CASE WHEN severity = 'P1' THEN 1 ELSE 0 END) AS p1_gaps, SUM(CASE WHEN severity = 'P2' THEN 1 ELSE 0 END) AS p2_gaps FROM ${redteamTable}`
      ),
      readSingleMetric(
        `SELECT generated_at, health_status, ARRAY_LENGTH(health_flags) AS health_flag_count FROM ${forensicTable} ORDER BY generated_at DESC LIMIT 1`
      )
    ]);

    const payload = {
      status: "ok",
      generated_at: new Date().toISOString(),
      bigquery_project: resolveQueryProject(),
      bigquery_dataset: BIGQUERY_DATASET,
      max_bytes_billed: BQ_MAX_BYTES_BILLED,
      allowlist_size: BQ_ALLOWLIST.size,
      operator: {
        uid: operator.uid,
        email: operator.email,
        role: operator.role
      },
      metrics: {
        overview: overview.row,
        complete_picture_latest: completePicture.row,
        tickets: tickets.row,
        counsel_queue: counsel.row,
        redteam: redteam.row,
        forensic_latest: forensic.row
      },
      jobs: {
        overview: overview.job_id,
        complete_picture_latest: completePicture.job_id,
        tickets: tickets.job_id,
        counsel_queue: counsel.job_id,
        redteam: redteam.job_id,
        forensic_latest: forensic.job_id
      }
    };

    await logArtifact({
      type: "command_center_snapshot",
      generated_at: payload.generated_at,
      p1_open: payload.metrics.tickets && payload.metrics.tickets.p1_open,
      operator_uid: operator.uid,
      operator_email: operator.email,
      operator_role: operator.role
    });
    res.status(200).json(jsonSafe(payload));
  } catch (err) {
    logger.error("command_center_snapshot_failed", err);
    res.status(500).json({
      error: "command_center_snapshot_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200)
    });
  }
});

exports.bigQueryRead = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const operator = await requireFirebaseOperator(req, res);
    if (!operator) return;
    if (!ensureEndpointRole(res, operator, "bigQueryRead")) return;

    const table = sanitizeIdentifier(asString(req.body && req.body.table, "").trim());
    if (!ensureTableRole(operator.role, table)) {
      const role = normalizeOperatorRole(operator.role, DEFAULT_OPERATOR_ROLE);
      const allowedTables = ROLE_TABLE_ACCESS[role] || new Set();
      throw new Error(
        `role ${role} cannot read table ${table}; allowed tables: ${Array.from(allowedTables.values()).sort().join(", ")}`
      );
    }
    const qualifiedTable = getQualifiedTable(table);
    const limit = Math.min(Math.max(asNumber(req.body && req.body.limit, 25), 1), 200);
    const requestedFields = Array.isArray(req.body && req.body.fields)
      ? req.body.fields.map((field) => sanitizeIdentifier(field))
      : [];
    const fieldsSql = requestedFields.length > 0
      ? requestedFields.map((field) => `\`${field}\``).join(", ")
      : "*";

    const orderByField = asString(req.body && req.body.order_by, "").trim();
    const orderBySql = orderByField
      ? ` ORDER BY \`${sanitizeIdentifier(orderByField)}\` ${asString(req.body && req.body.order_dir, "DESC").toUpperCase() === "ASC" ? "ASC" : "DESC"}`
      : "";

    const rawFilters = Array.isArray(req.body && req.body.filters) ? req.body.filters : [];
    if (rawFilters.length > 10) {
      throw new Error("too many filters (max 10)");
    }

    const whereClauses = [];
    const params = { limit };
    const appliedFilters = [];

    for (let i = 0; i < rawFilters.length; i += 1) {
      const raw = rawFilters[i] || {};
      const field = sanitizeIdentifier(asString(raw.field, "").trim());
      const op = asString(raw.op, "").trim().toLowerCase();
      if (!BQ_FILTER_OPS.has(op)) {
        throw new Error(`unsupported filter operator: ${op}`);
      }
      const paramName = `f${i}`;
      const paramRef = `@${paramName}`;
      const value = raw.value;

      if (op === "is_null" || op === "is_not_null") {
        whereClauses.push(`\`${field}\` IS ${op === "is_not_null" ? "NOT " : ""}NULL`);
        appliedFilters.push({ field, op });
        continue;
      }

      if (op === "in" || op === "not_in") {
        if (!Array.isArray(value) || value.length === 0 || value.length > 100) {
          throw new Error(`operator ${op} requires non-empty array value (max 100)`);
        }
        if (!value.every(isScalarFilterValue)) {
          throw new Error(`operator ${op} requires scalar array values`);
        }
        params[paramName] = value;
        whereClauses.push(`\`${field}\` ${op === "not_in" ? "NOT " : ""}IN UNNEST(${paramRef})`);
        appliedFilters.push({ field, op, value_count: value.length });
        continue;
      }

      if (op === "contains") {
        const s = asString(value, "");
        if (!s) {
          throw new Error("operator contains requires non-empty string value");
        }
        params[paramName] = s;
        whereClauses.push(`CONTAINS_SUBSTR(CAST(\`${field}\` AS STRING), ${paramRef})`);
        appliedFilters.push({ field, op, value_preview: clip(s, 80) });
        continue;
      }

      if (!isScalarFilterValue(value)) {
        throw new Error(`operator ${op} requires scalar value`);
      }
      params[paramName] = value;
      const opSql = {
        eq: "=",
        neq: "!=",
        gt: ">",
        gte: ">=",
        lt: "<",
        lte: "<="
      }[op];
      if (!opSql) {
        throw new Error(`operator mapping missing: ${op}`);
      }
      whereClauses.push(`\`${field}\` ${opSql} ${paramRef}`);
      appliedFilters.push({ field, op, value_preview: clip(String(value), 80) });
    }

    const whereSql = whereClauses.length > 0 ? ` WHERE ${whereClauses.join(" AND ")}` : "";
    const query = `SELECT ${fieldsSql} FROM ${qualifiedTable}${whereSql}${orderBySql} LIMIT @limit`;
    const result = await runBigQuery(query, params);

    await logArtifact({
      type: "bigquery_read",
      table,
      row_count: Array.isArray(result.rows) ? result.rows.length : 0,
      operator_uid: operator.uid,
      operator_email: operator.email,
      operator_role: operator.role
    });

    res.status(200).json(jsonSafe({
      status: "ok",
      table,
      row_count: Array.isArray(result.rows) ? result.rows.length : 0,
      limit,
      rows: result.rows,
      job_id: result.jobId,
      dataset: BIGQUERY_DATASET,
      project_id: resolveQueryProject(),
      operator_role: operator.role,
      applied_filters: appliedFilters
    }));
  } catch (err) {
    logger.error("bigquery_read_failed", err);
    res.status(400).json({
      error: "bigquery_read_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200),
      allowed_tables: Array.from(BQ_ALLOWLIST.values()).sort()
    });
  }
});

exports.assistantQuery = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const operator = await requireFirebaseOperator(req, res);
    if (!operator) return;
    if (!ensureEndpointRole(res, operator, "assistantQuery")) return;

    const provider = normalizeProvider(
      req.body && (req.body.assistant || req.body.provider || "claude")
    );
    const model = asString(req.body && req.body.model, "").trim();
    const prompt = asString(req.body && req.body.prompt, "").trim();
    const threadId = asString(req.body && req.body.thread_id, "").trim() ||
      makeId("thread", [operator.uid, provider, new Date().toISOString().slice(0, 16)]);
    const temperature = asNumber(req.body && req.body.temperature, 0.2);
    const includeMemory = req.body && req.body.include_memory !== false;
    const includeSqlContext = req.body && req.body.include_sql_context === true;
    const memoryLimit = Math.min(Math.max(asNumber(req.body && req.body.memory_limit, 12), 0), 40);

    if (!prompt) {
      res.status(400).json({ error: "prompt is required" });
      return;
    }

    const system = asString(req.body && req.body.system, "").trim() || [
      "You are a MAROON internal assistant.",
      "Primary builder is Claude; Gemini and DeepSeek are assistant lanes.",
      "Respect governance constraints, SQL safety, and ontology boundaries.",
      "Give concrete actions and avoid speculative claims."
    ].join(" ");

    let memoryBlock = "";
    if (includeMemory && memoryLimit > 0) {
      try {
        const memSnap = await db
          .collection("assistant_threads")
          .doc(threadId)
          .collection("messages")
          .orderBy("created_at", "desc")
          .limit(memoryLimit)
          .get();
        const lines = [];
        const ordered = [];
        memSnap.forEach((doc) => ordered.push(doc.data() || {}));
        ordered.reverse().forEach((msg) => {
          const role = asString(msg.role, "assistant");
          const text = clip(asString(msg.text, ""), 500);
          if (text) {
            lines.push(`- [${role}] ${text}`);
          }
        });
        if (lines.length > 0) {
          memoryBlock = `Recent thread memory:\\n${lines.join("\\n")}\\n`;
        }
      } catch (err) {
        logger.warn("assistant_memory_read_failed", {
          thread_id: threadId,
          detail: clip(err && err.message ? err.message : String(err), 500)
        });
      }
    }

    let sqlContextBlock = "";
    if (includeSqlContext) {
      const table = sanitizeIdentifier(asString(req.body && req.body.sql_table, "").trim());
      if (!table) {
        throw new Error("sql_table is required when include_sql_context=true");
      }
      if (!ensureTableRole(operator.role, table)) {
        throw new Error(`role ${operator.role} cannot read table ${table}`);
      }
      const limit = Math.min(Math.max(asNumber(req.body && req.body.sql_limit, 10), 1), 50);
      const result = await runBigQuery(`SELECT * FROM ${getQualifiedTable(table)} LIMIT @limit`, { limit });
      const rows = Array.isArray(result.rows) ? result.rows : [];
      sqlContextBlock = [
        `SQL context table: ${table}`,
        `SQL context rows (${rows.length}):`,
        clip(JSON.stringify(rows), 5000)
      ].join("\n");
    }

    const outboundPrompt = [
      memoryBlock,
      sqlContextBlock,
      "Current request:",
      prompt
    ].filter(Boolean).join("\n\n");

    const result = await callProvider({
      provider,
      prompt: outboundPrompt,
      system,
      model,
      temperature
    });

    const threadRef = db.collection("assistant_threads").doc(threadId);
    await threadRef.set({
      thread_id: threadId,
      owner_uid: operator.uid,
      owner_email: operator.email,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      last_provider: result.provider,
      last_model: result.model
    }, { merge: true });

    await threadRef.collection("messages").add({
      role: "user",
      provider: "client",
      model: "n/a",
      text: redactSensitive(prompt),
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await threadRef.collection("messages").add({
      role: "assistant",
      provider: result.provider,
      model: result.model,
      text: result.text,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await logArtifact({
      type: "assistant_query",
      thread_id: threadId,
      provider: result.provider,
      model: result.model,
      operator_uid: operator.uid,
      operator_email: operator.email,
      prompt_preview: clip(prompt, 220),
      response_preview: clip(result.text, 260)
    });

    res.status(200).json({
      status: "ok",
      thread_id: threadId,
      provider: result.provider,
      model: result.model,
      text: result.text
    });
  } catch (err) {
    logger.error("assistant_query_failed", err);
    res.status(500).json({
      error: "assistant_query_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200)
    });
  }
});

exports.getOperatorProfile = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "GET" && req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const operator = await requireFirebaseOperator(req, res);
    if (!operator) return;
    if (!ensureEndpointRole(res, operator, "getOperatorProfile")) return;

    const user = await admin.auth().getUser(operator.uid);
    const claims = user.customClaims || {};
    const role = normalizeOperatorRole(claims.maroon_role || claims.role || operator.role, DEFAULT_OPERATOR_ROLE);
    const roles = extractOperatorRoles({
      maroon_role: claims.maroon_role || claims.role || role,
      maroon_roles: claims.maroon_roles
    });
    res.status(200).json({
      status: "ok",
      uid: user.uid,
      email: user.email || "",
      role,
      roles,
      email_verified: user.emailVerified === true,
      claims
    });
  } catch (err) {
    logger.error("get_operator_profile_failed", err);
    res.status(500).json({
      error: "get_operator_profile_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200)
    });
  }
});

exports.setOperatorRoleClaim = onRequest(async (req, res) => {
  if (setCors(req, res)) return;
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const uid = asString(req.body && req.body.uid, "").trim();
    const email = asString(req.body && req.body.email, "").trim().toLowerCase();
    const roleInput = asString(req.body && req.body.role, "").trim().toLowerCase();
    const role = normalizeOperatorRole(roleInput, "");

    if (!role || !OPERATOR_ROLE_VALUES.has(role)) {
      res.status(400).json({
        error: "invalid_role",
        detail: "role must be one of founder, counsel, engineer"
      });
      return;
    }
    if (!uid && !email) {
      res.status(400).json({
        error: "missing_target",
        detail: "Provide uid or email."
      });
      return;
    }

    const bootstrapAuthorized = hasRoleBootstrapKey(req);
    let actor = null;
    let bootstrapSelfPromotion = false;
    if (!bootstrapAuthorized) {
      actor = await requireFirebaseOperator(req, res);
      if (!actor) return;
      if (!ensureEndpointRole(res, actor, "setOperatorRoleClaim")) {
        const founderExists = await hasFounderClaim();
        const targetIsActor = (uid && uid === actor.uid) || (!uid && email && email === actor.email);
        const canBootstrapSelf =
          !founderExists &&
          targetIsActor &&
          role === "founder";
        if (!canBootstrapSelf) {
          return;
        }
        bootstrapSelfPromotion = true;
      }
    }

    let userRecord = null;
    if (uid) {
      userRecord = await admin.auth().getUser(uid);
    } else {
      userRecord = await admin.auth().getUserByEmail(email);
    }

    const existingClaims = userRecord.customClaims || {};
    const nextClaims = {
      ...existingClaims,
      maroon_role: role,
      maroon_roles: [role],
      maroon_role_updated_at: new Date().toISOString()
    };
    await admin.auth().setCustomUserClaims(userRecord.uid, nextClaims);

    await logArtifact({
      type: "set_operator_role_claim",
      target_uid: userRecord.uid,
      target_email: userRecord.email || "",
      role,
      authorized_via: bootstrapAuthorized
        ? "bootstrap_key"
        : (bootstrapSelfPromotion ? "self_bootstrap_first_founder" : "founder_claim"),
      actor_uid: actor && actor.uid ? actor.uid : "bootstrap_key",
      actor_email: actor && actor.email ? actor.email : "bootstrap_key"
    });

    res.status(200).json({
      status: "ok",
      uid: userRecord.uid,
      email: userRecord.email || "",
      role,
      authorized_via: bootstrapAuthorized
        ? "bootstrap_key"
        : (bootstrapSelfPromotion ? "self_bootstrap_first_founder" : "founder_claim"),
      note: "Role updated. Target user should refresh ID token (sign out/in)."
    });
  } catch (err) {
    logger.error("set_operator_role_claim_failed", err);
    res.status(500).json({
      error: "set_operator_role_claim_failed",
      detail: clip(err && err.message ? err.message : String(err), 1200)
    });
  }
});
