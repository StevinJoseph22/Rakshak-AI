import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Navbar } from './components/Navbar';
import { HospitalView } from './views/HospitalView';
import { PoliceView } from './views/PoliceView';
import { getSocket } from './services/socket';
import { ConnectionStatus } from './types';

export const App: React.FC = () => {
  const [globalStatus, setGlobalStatus] =
    useState<ConnectionStatus>('connected');

  useEffect(() => {
    const socket = getSocket();

    const onConnect = () => setGlobalStatus('connected');
    const onDisconnect = () => setGlobalStatus('disconnected');
    const onReconnectAttempt = () => setGlobalStatus('reconnecting');
    const onConnectError = () => setGlobalStatus('reconnecting');

    if (socket.connected) {
      setGlobalStatus('connected');
    }

    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);
    socket.on('connect_error', onConnectError);
    socket.io.on('reconnect_attempt', onReconnectAttempt);

    return () => {
      socket.off('connect', onConnect);
      socket.off('disconnect', onDisconnect);
      socket.off('connect_error', onConnectError);
      socket.io.off('reconnect_attempt', onReconnectAttempt);
    };
  }, []);

  return (
    <BrowserRouter>
      <div
        style={{
          minHeight: '100vh',
          display: 'flex',
          flexDirection: 'column',
          backgroundColor: '#f8fafc',
          color: '#1e293b',
        }}
      >
        <Navbar status={globalStatus} />

        <main style={{ flex: 1 }}>
          <Routes>
            <Route path="/" element={<Navigate to="/hospital" replace />} />
            <Route path="/hospital" element={<HospitalView />} />
            <Route path="/police" element={<PoliceView />} />
            <Route path="*" element={<Navigate to="/hospital" replace />} />
          </Routes>
        </main>

        <footer
          style={{
            borderTop: '1px solid #e2e8f0',
            padding: '1rem 2rem',
            textAlign: 'center',
            fontSize: '0.8rem',
            color: '#94a3b8',
            background: '#ffffff',
          }}
        >
          Rakshak-AI Emergency Triage System &bull; Phase 5 Real-Time
          Broadcasting &bull; Connected to Express + PostGIS + Socket.io
        </footer>
      </div>
    </BrowserRouter>
  );
};

export default App;
