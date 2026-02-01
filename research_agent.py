import json
import os
import subprocess

CONVERSATIONS_PATH = "/Users/user1/Desktop/d9d3a104ccffaaced25a1a39fd6973a33055cfa64e6c4c88930d8a63763868ba-2026-02-01-16-51-09-7764e05a513d4615be1125c3811d675c/conversations.json"
OUTPUT_DIR = "/Users/user1/Desktop/d9d3a104ccffaaced25a1a39fd6973a33055cfa64e6c4c88930d8a63763868ba-2026-02-01-16-51-09-7764e05a513d4615be1125c3811d675c/Maroon-Core/analysis_outputs"

os.makedirs(OUTPUT_DIR, exist_ok=True)

def query_local_llm(prompt, model='deepseek-r1:8b'):
    try:
        result = subprocess.run(
            ['ollama', 'run', model, prompt],
            capture_output=True, text=True
        )
        return result.stdout
    except Exception as e:
        return str(e)

def ingest_to_bigquery(title, content):
    """Mocks the ingestion of analyzed data into a BigQuery CLEAN dataset."""
    print(f"Ingesting to BQ: {title} (Persistence Secured)")
    # Logic for google-cloud-bigquery would go here
    pass

def process_corpus():
    with open(CONVERSATIONS_PATH, 'r') as f:
        data = json.load(f)
        
    for i, conv in enumerate(data):
        title = conv.get('title', 'Unknown')
        print(f"Analyzing: {title}")
        
        # Collaborative analysis: DeepSeek for logic, Gemma for technical structure
        if any(keyword in title.lower() for keyword in ["maroon", "ebt", "nanny", "truth", "patent", "business", "capital", "law"]):
            logic_summary = query_local_llm(f"Analyze business logic in '{title}':", model='deepseek-r1:8b')
            tech_specs = query_local_llm(f"Extract technical specs from '{title}':", model='gemma:7b')
            
            combined_analysis = f"## Logic Analysis\n{logic_summary}\n\n## Tech Specs\n{tech_specs}"
            
            # Local File Persistence
            out_path = f"{OUTPUT_DIR}/{title.replace('/', '_')}.md"
            with open(out_path, "w") as out:
                out.write(combined_analysis)
            
            # Memory/Persistence Layer (BigQuery)
            ingest_to_bigquery(title, combined_analysis)

if __name__ == "__main__":
    process_corpus()
