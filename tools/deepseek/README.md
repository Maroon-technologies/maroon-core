# Maroon Corpus + DeepSeek Pipeline

This repo contains Maroon source documents plus a local DeepSeek (Ollama) pipeline to:

- scan key Markdown docs (Maroon, patents, schemas, business, systems)
- produce Harvard-grade rewrites + gap analysis
- generate a global, provider-agnostic corpus synthesis

## Quick Start

1) Install Ollama and pull the model:

```bash
ollama pull deepseek-r1:8b
```

2) Run the pipeline:

```bash
./deepseek_maroon_cleanup.sh
```

If you want to scan the entire workspace folder (parent of `Maroon-Core`) while keeping git-trackable summaries inside `Maroon-Core/runs`, run:

```bash
./run_workspace.sh
```

## Outputs

- Raw per-file outputs: `deepseek_outputs/<timestamp>/...`
- Aggregated synthesis: `deepseek_outputs/<timestamp>/_corpus/`
- Git-trackable summaries: `runs/<timestamp>/` (small copies of `_corpus/*` + `run_manifest.json`)

## Common Options

- Limit to last 24 hours:

```bash
MAROON_SINCE_HOURS=24 ./deepseek_maroon_cleanup.sh
```

- Only process a subset of files (regex on relative path):

```bash
MAROON_INCLUDE_PATH_RE='^Maroon-Core/(patents|ontology|specs)/' ./deepseek_maroon_cleanup.sh
```

- Override filename globs (comma-separated):

```bash
MAROON_GLOBS='*maroon*.md,*patent*.md,*schema*.md' ./deepseek_maroon_cleanup.sh
```

- Disable aggregation:

```bash
MAROON_NO_AGGREGATE=1 ./deepseek_maroon_cleanup.sh
```
