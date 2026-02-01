import { useState } from 'react';
import './App.css';

interface Product {
  id: number;
  name: string;
  price: number;
  ebt: boolean;
  integrity: number;
}

const PRODUCTS: Product[] = [
  { id: 1, name: 'Sovereign Honey', price: 12.00, ebt: true, integrity: 98 },
  { id: 2, name: 'Maroon Coffee Blend', price: 18.00, ebt: false, integrity: 95 },
  { id: 3, name: 'EBT Starter Kit', price: 45.00, ebt: true, integrity: 100 },
];

function App() {
  const [cart, setCart] = useState<Product[]>([]);
  const [checkingOut, setCheckingOut] = useState(false);

  const addToCart = (product: Product) => setCart([...cart, product]);

  const calculateSplit = () => {
    const ebtTotal = cart.filter(p => p.ebt).reduce((sum, p) => sum + p.price, 0);
    const cashTotal = cart.filter(p => !p.ebt).reduce((sum, p) => sum + p.price, 0);
    return { ebtTotal, cashTotal };
  };

  const { ebtTotal, cashTotal } = calculateSplit();

  return (
    <div className="container">
      <header className="header">
        <h1 className="title-sovereign">ONITAS MARKET</h1>
        <p className="subtitle">The Sovereign Food Marketplace</p>
      </header>

      <main className="marketplace">
        <section className="product-grid">
          {PRODUCTS.map(product => (
            <div key={product.id} className="glass-panel product-card animate-in">
              <div className="integrity-tag">Integrity: {product.integrity}%</div>
              <h3>{product.name}</h3>
              <p className="price">${product.price.toFixed(2)}</p>
              {product.ebt && <span className="ebt-badge">EBT Eligible</span>}
              <button className="btn-primary" onClick={() => addToCart(product)}>
                Add to Cart
              </button>
            </div>
          ))}
        </section>

        <aside className="cart-panel glass-panel">
          <h2>Your Cart ({cart.length})</h2>
          {cart.map((item, i) => (
            <div key={i} className="cart-item">
              <span>{item.name}</span>
              <span>${item.price.toFixed(2)}</span>
            </div>
          ))}
          <hr />
          <div className="split-summary">
            <p>EBT Share: <span className="gold">${ebtTotal.toFixed(2)}</span></p>
            <p>Cash Share: <span>${cashTotal.toFixed(2)}</span></p>
          </div>
          <button
            className="btn-primary"
            disabled={cart.length === 0}
            onClick={() => setCheckingOut(true)}
          >
            Sovereign Checkout (EBT Split)
          </button>
        </aside>
      </main>

      {checkingOut && (
        <div className="modal-overlay">
          <div className="glass-panel modal animate-in">
            <h2>EBT Split Apparatus Engaged</h2>
            <p>Processing {cart.length} items across dual-gateways...</p>
            <button className="btn-primary" onClick={() => setCheckingOut(false)}>
              Payment Secured
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
