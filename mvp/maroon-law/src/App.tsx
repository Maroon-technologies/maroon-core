import { useState } from 'react';
import './App.css';

function App() {
  const [step, setStep] = useState(1);
  const [formData, setFormData] = useState({ name: '', expertise: '', email: '' });

  const handleNext = () => setStep(step + 1);

  return (
    <div className="container">
      <header className="header">
        <h1 className="title-sovereign">MAROON LAW</h1>
        <p className="subtitle">Virtual. Volunteer. Sovereign. Defensible.</p>
      </header>

      <main className="main-content">
        {step === 1 ? (
          <section className="glass-panel animate-in">
            <h2>The "Deflection" Protocol</h2>
            <p>
              We provide the legal infrastructure for the Maroon Trust.
              Our mission is to ensure that sovereign businesses operate
              within the bounds of the law while maintaining 100% data integrity.
            </p>
            <button className="btn-primary" onClick={handleNext}>
              Join the Volunteer Firm
            </button>
          </section>
        ) : (
          <section className="glass-panel animate-in">
            <h2>Volunteer Onboarding</h2>
            <form onSubmit={(e) => { e.preventDefault(); alert('Onboarding Secured.'); }}>
              <div className="form-group">
                <label>Legal Name</label>
                <input
                  type="text"
                  placeholder="John Doe"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label>Area of Expertise</label>
                <select
                  value={formData.expertise}
                  onChange={(e) => setFormData({ ...formData, expertise: e.target.value })}
                >
                  <option>Intellectual Property</option>
                  <option>Regulatory Compliance (WA State)</option>
                  <option>Corporate Governance (NASA Standards)</option>
                </select>
              </div>
              <button className="btn-primary" type="submit">
                Submit for Security Clearance
              </button>
            </form>
          </section>
        )}
      </main>

      <footer className="footer">
        <p>© 2026 Maroon Trust | All Assets Sovereign</p>
      </footer>
    </div>
  );
}

export default App;
