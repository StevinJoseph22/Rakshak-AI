import React, { useState } from 'react';
import {
  Lock,
  User as UserIcon,
  ShieldAlert,
  Hospital,
  AlertCircle,
  KeyRound,
  CheckCircle2,
} from 'lucide-react';
import { login, AuthUser } from '../services/auth';
import { updateSocketAuth } from '../services/socket';

interface LoginViewProps {
  requiredRole: 'hospital_staff' | 'police';
  onLoginSuccess: (user: AuthUser) => void;
}

const DEMO_PRESETS = [
  { label: 'Manipal Hospital HAL', username: 'manipal_hal', password: 'hospital123', role: 'hospital_staff' },
  { label: 'St. John\'s Medical College', username: 'st_johns', password: 'hospital123', role: 'hospital_staff' },
  { label: 'Apollo Bannerghatta', username: 'apollo_bg', password: 'hospital123', role: 'hospital_staff' },
  { label: 'Fortis Cunningham Rd', username: 'fortis_cunningham', password: 'hospital123', role: 'hospital_staff' },
  { label: 'Police Control Room', username: 'police_control', password: 'police123', role: 'police' },
];

export const LoginView: React.FC<LoginViewProps> = ({ requiredRole, onLoginSuccess }) => {
  const [username, setUsername] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(false);

  const isHospital = requiredRole === 'hospital_staff';

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      setErrorMessage('Please enter both username and password.');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);

    try {
      const { token, user } = await login(username.trim(), password);

      if (user.role !== requiredRole) {
        throw new Error(
          `Unauthorized role: Logged in as '${user.role}', but this portal requires '${requiredRole}'.`
        );
      }

      updateSocketAuth(token);
      onLoginSuccess(user);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Invalid credentials. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const applyPreset = (preset: typeof DEMO_PRESETS[0]) => {
    setUsername(preset.username);
    setPassword(preset.password);
    setErrorMessage(null);
  };

  return (
    <div
      style={{
        minHeight: '75vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '2rem 1rem',
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: '460px',
          background: '#ffffff',
          borderRadius: '1rem',
          boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.08), 0 8px 10px -6px rgba(0, 0, 0, 0.04)',
          border: '1px solid #e2e8f0',
          overflow: 'hidden',
        }}
      >
        {/* Card Header */}
        <div
          style={{
            background: isHospital
              ? 'linear-gradient(135deg, #065f46 0%, #047857 100%)'
              : 'linear-gradient(135deg, #1e3a8a 0%, #1d4ed8 100%)',
            padding: '2rem',
            textAlign: 'center',
            color: '#ffffff',
          }}
        >
          <div
            style={{
              width: '56px',
              height: '56px',
              background: 'rgba(255, 255, 255, 0.2)',
              backdropFilter: 'blur(8px)',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              margin: '0 auto 1rem',
            }}
          >
            {isHospital ? <Hospital size={30} color="#ffffff" /> : <ShieldAlert size={30} color="#ffffff" />}
          </div>
          <h2 style={{ margin: '0 0 0.4rem', fontSize: '1.35rem', fontWeight: 800 }}>
            {isHospital ? 'Hospital ER Staff Portal' : 'Police Tactical Control'}
          </h2>
          <p style={{ margin: 0, fontSize: '0.825rem', opacity: 0.9 }}>
            {isHospital
              ? 'Role-Based Authentication for Trauma Center Triage'
              : 'Authorized City-Wide Emergency Response Access'}
          </p>
        </div>

        {/* Login Form Body */}
        <div style={{ padding: '2rem' }}>
          {errorMessage && (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                background: '#fef2f2',
                border: '1px solid #fecaca',
                color: '#991b1b',
                padding: '0.75rem 1rem',
                borderRadius: '0.5rem',
                fontSize: '0.825rem',
                marginBottom: '1.25rem',
              }}
            >
              <AlertCircle size={18} style={{ flexShrink: 0 }} />
              <span>{errorMessage}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
            <div>
              <label
                style={{
                  display: 'block',
                  fontSize: '0.8rem',
                  fontWeight: 700,
                  color: '#334155',
                  marginBottom: '0.4rem',
                }}
              >
                Username
              </label>
              <div style={{ position: 'relative' }}>
                <UserIcon
                  size={18}
                  color="#94a3b8"
                  style={{ position: 'absolute', left: '0.85rem', top: '50%', transform: 'translateY(-50%)' }}
                />
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder={isHospital ? 'e.g. manipal_hal' : 'e.g. police_control'}
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.85rem 0.65rem 2.5rem',
                    borderRadius: '0.5rem',
                    border: '1px solid #cbd5e1',
                    fontSize: '0.9rem',
                    outline: 'none',
                    boxSizing: 'border-box',
                  }}
                  required
                />
              </div>
            </div>

            <div>
              <label
                style={{
                  display: 'block',
                  fontSize: '0.8rem',
                  fontWeight: 700,
                  color: '#334155',
                  marginBottom: '0.4rem',
                }}
              >
                Password
              </label>
              <div style={{ position: 'relative' }}>
                <KeyRound
                  size={18}
                  color="#94a3b8"
                  style={{ position: 'absolute', left: '0.85rem', top: '50%', transform: 'translateY(-50%)' }}
                />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  style={{
                    width: '100%',
                    padding: '0.65rem 0.85rem 0.65rem 2.5rem',
                    borderRadius: '0.5rem',
                    border: '1px solid #cbd5e1',
                    fontSize: '0.9rem',
                    outline: 'none',
                    boxSizing: 'border-box',
                  }}
                  required
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              style={{
                marginTop: '0.5rem',
                padding: '0.75rem',
                background: isHospital ? '#059669' : '#1d4ed8',
                color: '#ffffff',
                border: 'none',
                borderRadius: '0.5rem',
                fontSize: '0.9rem',
                fontWeight: 700,
                cursor: isLoading ? 'not-allowed' : 'pointer',
                opacity: isLoading ? 0.7 : 1,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '0.5rem',
                transition: 'background 0.15s ease',
              }}
            >
              <Lock size={16} />
              {isLoading ? 'Verifying Credentials...' : 'Sign In to Command Center'}
            </button>
          </form>

          {/* Quick Demo Credentials Panel */}
          <div
            style={{
              marginTop: '1.75rem',
              paddingTop: '1.25rem',
              borderTop: '1px solid #f1f5f9',
            }}
          >
            <div
              style={{
                fontSize: '0.725rem',
                fontWeight: 700,
                color: '#64748b',
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
                marginBottom: '0.6rem',
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
              }}
            >
              <CheckCircle2 size={13} color="#10b981" />
              Quick Demo Fill ({isHospital ? 'Hospital Accounts' : 'Police Account'}):
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem' }}>
              {DEMO_PRESETS.filter((p) => p.role === requiredRole).map((preset) => (
                <button
                  key={preset.username}
                  type="button"
                  onClick={() => applyPreset(preset)}
                  style={{
                    background: '#f8fafc',
                    border: '1px solid #cbd5e1',
                    padding: '0.35rem 0.6rem',
                    borderRadius: '0.375rem',
                    fontSize: '0.75rem',
                    color: '#334155',
                    cursor: 'pointer',
                    fontWeight: 600,
                  }}
                >
                  {preset.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
