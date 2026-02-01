import { useState } from 'react';
import './App.css';

const MOCK_SIGNALS = [
  { id: 1, source: 'WSDA', type: 'Regulation', status: 'Ingested', score: 0.98, text: 'SB 5605 Active' },
  { id: 2, source: 'Zillow', type: 'Market', status: 'Processing', score: 0.85, text: 'Commissary Heatmap: WA' },
  { id: 3, source: 'Maroon Law', type: 'SOP', status: 'Secured', score: 1.0, text: 'Volunteer Onboarding V2' },
];

function App() {
  const [signals, setSignals] = useState(MOCK_SIGNALS);
  const [isCollecting, setIsCollecting] = useState(false);

  const startCollection = () => {
    setIsCollecting(true);
    setTimeout(() => {
      setSignals([
        { id: signals.length + 1, source: 'Truth Teller', type: 'Prediction', status: 'Live', score: 0.92, text: '1M+ Person Analysis Initialized' },
        ...signals
      ]);
      setIsCollecting(false);
    }, 2000);
  };

  return (
    <div className="container">
      <header className="header">
        <h1 className="title-sovereign">TRUTH TELLER DASH</h1>
        <p className="subtitle">Integrity Mapping & Prediction</p>
      </header>

      <main className="dashboard">
        <section className="glass-panel stats-row">
          <div className="stat">
            <span className="label">Total Signals</span>
            <span className="value">{signals.length}</span>
          </div>
          <div className="stat">
            <span className="label">Avg Integrity</span>
            <span className="value">94.2%</span>
          </div>
          <div className="stat">
            <span className="label">Entities Mapped</span>
            <span className="value">12.4k</span>
          </div>
          <button
            className={`btn-primary ${isCollecting ? 'loading' : ''}`}
            onClick={startCollection}
          >
            {isCollecting ? 'Ingesting...' : 'Collect Data'}
          </button>
        </section>

        <section className="glass-panel signal-list">
          <h2>Active Signal Stream</h2>
          <div className="list-wrapper">
            {signals.map(signal => (
              <div key={signal.id} className="signal-item animate-in">
                <span className="tag">{signal.source}</span>
                <span className="body">{signal.text}</span>
                <span className="status">{signal.status}</span>
                <span className="score">{(signal.score * 100).toFixed(0)}%</span>
              </div>
            ))}
          </div>
        </section>
      </main>

      <footer className="footer">
        <p>© 2026 Maroon Trust | The Way Out is Our Brain</p>
      </footer>
    </div>
  );
}

export default App;
