# Maroon Empire Coding Standards

Use these instructions when working with the Maroon-Core codebase.

## Terminology (CRITICAL)

- **ALWAYS use "corpus"** - NEVER use "data"
- **Use "ontology"** for system architecture and meaning hierarchy
- **Use "sovereignty"** for ownership and control principles
- **Use "integrity"** for verification and truth scoring
- **Use "signals"** for raw ingestion from external sources

## Architecture Principles

1. **Reference MASTER_ONTOLOGY.md** for system design decisions
2. **Follow the four-level hierarchy**:
   - Level 1: Signal (raw corpus ingestion)
   - Level 2: Pattern (observation and analysis)
   - Level 3: Protocol (operational logic and SOPs)
   - Level 4: Ontology (governance and rules)

3. **Maintain traceability**: Every decision must link back to a specific protocol
4. **Ensure legal defensibility**: All actions must withstand scrutiny

## Code Standards

- Use **schema.org markup** for all web content
- Implement **comprehensive error handling**
- Add **integrity scores** to all corpus processing
- Document **corpus provenance** (source, timestamp, verification status)

## Documentation Requirements

- Link code to specific corpus sources in comments
- Reference protocols when implementing business logic
- Use markdown for all documentation
- Include schema.org JSON-LD in HTML files

## File Organization

- `ontology/`: Core system definitions
- `business/`: Financial and application docs
- `specs/`: Engineering requirements
- `mvp/`: Product deployments
- `analysis_outputs/`: Corpus documents

## Maroon-Specific Patterns

### Corpus Processing
```python
def process_corpus(signal):
    """
    Process raw signal corpus through ontology levels.
    
    Args:
        signal: Raw corpus from external source
    
    Returns:
        Processed corpus with integrity score
    """
    # Verify provenance
    # Calculate integrity score
    # Map to ontology level
    # Return verified corpus
```

### Schema.org Integration
```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Maroon Technologies"
}
</script>
```

## Quality Checklist

Before committing code:
- [ ] No "data" references (use "corpus")
- [ ] Schema.org markup included (if web content)
- [ ] Integrity scoring implemented (if corpus processing)
- [ ] Traceability documented (link to protocols)
- [ ] Legal defensibility ensured (audit trail)

## Resources

- Master Documentation: `MAROON.md`
- Ontology: `ontology/MASTER_ONTOLOGY.md`
- Database Schema: `ontology/DATABASE_SCHEMA.md`
- Corpus Strategy: `ontology/CORPUS_CONSOLIDATION.md`
