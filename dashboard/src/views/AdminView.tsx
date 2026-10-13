import React, { useState, useEffect } from 'react';
import {
  Trash2,
  RefreshCw,
  Database,
  Radio,
  Hospital,
  AlertTriangle,
  CheckCircle2,
  Zap,
  Server,
  Activity,
} from 'lucide-react';
import { getSocket } from '../services/socket';

interface SystemStats {
  total_incidents: number;
  status_counts: Record<string, number>;
  total_hospitals: number;
  redis_cached_keys: number;
  active_sentinel_sessions: number;
  timestamp: string;
}

export const AdminView: React.FC = () => {
  const [stats, setStats] = useState<SystemStats | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [actionMessage, setActionMessage] = useState<{ text: string; type: 'success' | 'error' } | null>(null);
  const [logs, setLogs] = useState<Array<{ time: string; message: string; type: string }>>([]);

  const fetchStats = async () => {
    try {
      const res = await fetch('/incidents/stats');
      if (res.ok) {
        const data = await res.json();
        setStats(data);
      }
    } catch {
      // Ignore network errors on unmounted
    }
  };

  useEffect(() => {
    fetchStats();
    const interval = setInterval(fetchStats, 3000);

    const socket = getSocket();
    const handleFeedCleared = () => {
      addLog('Broadcast event received: feed_cleared. All dashboards reset to 0.', 'warning');
      fetchStats();
    };
    const handleNewIncident = (data: { id: string }) => {
      addLog(`Broadcast event received: new_incident (${data.id})`, 'info');
      fetchStats();
    };
    const handleSuspected = (data: { id: string }) => {
      addLog(`Pre-alert received: incident_suspected (${data.id})`, 'info');
      fetchStats();
    };

    socket.on('feed_cleared', handleFeedCleared);
    socket.on('new_incident', handleNewIncident);
    socket.on('incident_suspected', handleSuspected);

    return () => {
      clearInterval(interval);
      socket.off('feed_cleared', handleFeedCleared);
      socket.off('new_incident', handleNewIncident);
      socket.off('incident_suspected', handleSuspected);
    };
  }, []);

  const addLog = (message: string, type: 'info' | 'warning' | 'success' | 'error' = 'info') => {
    const time = new Date().toLocaleTimeString();
    setLogs((prev) => [{ time, message, type }, ...prev.slice(0, 19)]);
  };

  const handleClearAllAlerts = async () => {
    if (!window.confirm('Are you sure you want to purge all active alerts? This clears the database, Redis RAM, and resets all open dashboards.')) {
      return;
    }

    setLoading(true);
    setActionMessage(null);

    try {
      const res = await fetch('/incidents', { method: 'DELETE' });
      if (res.ok) {
        setActionMessage({
          text: 'All active alerts and test incidents purged successfully. Dashboards are now 100% clean for your next test.',
          type: 'success',
        });
        addLog('ADMIN ACTION: Invoked DELETE /incidents. Database & Redis cleared.', 'success');
        await fetchStats();
      } else {
        const err = await res.json();
        setActionMessage({
          text: `Purge failed: ${err.message || 'Server error'}`,
          type: 'error',
        });
      }
    } catch (e) {
      setActionMessage({
        text: `Network error during purge: ${e instanceof Error ? e.message : 'Unknown error'}`,
        type: 'error',
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSeedDemoIncident = async () => {
    setLoading(true);
    setActionMessage(null);

    try {
      const res = await fetch('/incidents', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          latitude: 12.9716,
          longitude: 77.5946,
          victim_metadata: {
            source: 'admin_console_seed',
            deceleration_g: 8.5,
            speed_drop_kmh: 62.0,
            simulated_injury: 'Severe Impact',
            rider_unresponsive: true,
          },
        }),
      });

      if (res.ok) {
        const data = await res.json();
        setActionMessage({
          text: `Demo incident created (${data.incident?.id}). Broadcasted to ER rooms & Police.`,
          type: 'success',
        });
        addLog(`ADMIN ACTION: Seeded test incident ${data.incident?.id}`, 'success');
        await fetchStats();
      } else {
        const err = await res.json();
        setActionMessage({ text: `Failed to seed incident: ${err.message}`, type: 'error' });
      }
    } catch (e) {
      setActionMessage({ text: `Network error: ${e instanceof Error ? e.message : 'Unknown error'}`, type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleSeedBlackspotIncidents = async () => {
    setLoading(true);
    setActionMessage(null);

    try {
      // Seeds 3 incidents near Silk Board Central Junction (12.9176, 77.6238) within 200m
      const coords = [
        { lat: 12.9176, lng: 77.6238 },
        { lat: 12.9181, lng: 77.6242 },
        { lat: 12.9172, lng: 77.6234 },
      ];

      for (let i = 0; i < coords.length; i++) {
        await fetch('/incidents', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            latitude: coords[i].lat,
            longitude: coords[i].lng,
            victim_metadata: {
              source: `admin_blackspot_cluster_seed_${i + 1}`,
              deceleration_g: 9.0 + i,
              speed_drop_kmh: 55.0,
              rider_unresponsive: false,
            },
          }),
        });
      }

      setActionMessage({
        text: 'Seeded 3 repeat collisions at Silk Board Junction. PostGIS cluster active on Police Tactical Map!',
        type: 'success',
      });
      addLog('ADMIN ACTION: Seeded 3 repeat collisions in Silk Board blackspot zone.', 'success');
      await fetchStats();
    } catch (e) {
      setActionMessage({ text: `Failed to seed blackspots: ${e instanceof Error ? e.message : 'Error'}`, type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const activeCount =
    (stats?.status_counts.broadcasting || 0) +
    (stats?.status_counts.suspected || 0) +
    (stats?.status_counts.escalated || 0) +
    (stats?.status_counts.accepted || 0) +
    (stats?.status_counts.en_route || 0);

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '1.5rem 2rem' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '1rem', marginBottom: '1.5rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Server size={24} color="#dc2626" />
            <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#0f172a', margin: 0 }}>
              System Administration & Incident Reset Lab
            </h1>
          </div>
          <p style={{ margin: '0.25rem 0 0 0', color: '#64748b', fontSize: '0.875rem' }}>
            Purge active incidents across PostgreSQL, Redis RAM, and WebSockets to start fresh for testing and demonstrations.
          </p>
        </div>

        <button
          onClick={fetchStats}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.4rem',
            padding: '0.5rem 0.85rem',
            background: '#ffffff',
            border: '1px solid #cbd5e1',
            borderRadius: '0.375rem',
            color: '#475569',
            fontSize: '0.8rem',
            fontWeight: 600,
            cursor: 'pointer',
          }}
        >
          <RefreshCw size={14} />
          Refresh Metrics
        </button>
      </div>

      {/* Action Notification Alert */}
      {actionMessage && (
        <div
          style={{
            marginBottom: '1.5rem',
            padding: '1rem',
            borderRadius: '0.5rem',
            background: actionMessage.type === 'success' ? '#f0fdf4' : '#fef2f2',
            border: `1.5px solid ${actionMessage.type === 'success' ? '#86efac' : '#fca5a5'}`,
            color: actionMessage.type === 'success' ? '#166534' : '#991b1b',
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
            boxShadow: '0 2px 6px rgba(0,0,0,0.03)',
          }}
        >
          {actionMessage.type === 'success' ? <CheckCircle2 size={20} /> : <AlertTriangle size={20} />}
          <div style={{ fontSize: '0.875rem', fontWeight: 600 }}>{actionMessage.text}</div>
        </div>
      )}

      {/* Metrics Row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1.5rem' }}>
        <div style={{ background: '#ffffff', padding: '1rem', borderRadius: '0.5rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Active Incidents</span>
            <Activity size={18} color={activeCount > 0 ? '#dc2626' : '#16a34a'} />
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: activeCount > 0 ? '#dc2626' : '#16a34a', marginTop: '0.25rem' }}>
            {activeCount}
          </div>
          <div style={{ fontSize: '0.725rem', color: '#94a3b8', marginTop: '0.25rem' }}>
            Total in DB: {stats?.total_incidents ?? 0}
          </div>
        </div>

        <div style={{ background: '#ffffff', padding: '1rem', borderRadius: '0.5rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Pre-Alerts (Suspected)</span>
            <AlertTriangle size={18} color="#f59e0b" />
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#f59e0b', marginTop: '0.25rem' }}>
            {stats?.status_counts.suspected ?? 0}
          </div>
          <div style={{ fontSize: '0.725rem', color: '#94a3b8', marginTop: '0.25rem' }}>
            Police soft markers pending confirm
          </div>
        </div>

        <div style={{ background: '#ffffff', padding: '1rem', borderRadius: '0.5rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Connected Hospitals</span>
            <Hospital size={18} color="#2563eb" />
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#2563eb', marginTop: '0.25rem' }}>
            {stats?.total_hospitals ?? 5}
          </div>
          <div style={{ fontSize: '0.725rem', color: '#94a3b8', marginTop: '0.25rem' }}>
            Bengaluru verified trauma centers
          </div>
        </div>

        <div style={{ background: '#ffffff', padding: '1rem', borderRadius: '0.5rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Redis Volatile Keys</span>
            <Database size={18} color="#7c3aed" />
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#7c3aed', marginTop: '0.25rem' }}>
            {stats?.redis_cached_keys ?? 0}
          </div>
          <div style={{ fontSize: '0.725rem', color: '#94a3b8', marginTop: '0.25rem' }}>
            RAM image buffers & telemetries
          </div>
        </div>
      </div>

      {/* Main Operations Control Card */}
      <div style={{ background: '#ffffff', borderRadius: '0.75rem', border: '1.5px solid #e2e8f0', padding: '1.5rem', marginBottom: '1.5rem', boxShadow: '0 4px 12px rgba(0,0,0,0.03)' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 800, color: '#0f172a', margin: '0 0 0.5rem 0', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <Trash2 size={20} color="#dc2626" />
          Reset Incident State & Clear Test Data
        </h2>
        <p style={{ color: '#64748b', fontSize: '0.85rem', margin: '0 0 1.25rem 0', lineHeight: 1.5 }}>
          Wipes all incidents from PostgreSQL, clears active Redis image stream keys, disarms pending silent promotion watchdogs, and broadcasts a real-time <code>feed_cleared</code> signal to reset all open hospital and police browser tabs to 0.
        </p>

        <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
          <button
            onClick={handleClearAllAlerts}
            disabled={loading}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              padding: '0.75rem 1.25rem',
              background: '#dc2626',
              color: '#ffffff',
              border: 'none',
              borderRadius: '0.5rem',
              fontWeight: 700,
              fontSize: '0.9rem',
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.7 : 1,
              boxShadow: '0 2px 8px rgba(220, 38, 38, 0.3)',
              transition: 'background 0.15s ease',
            }}
          >
            <Trash2 size={18} />
            {loading ? 'Purging Active State...' : 'CLEAR ALL ACTIVE INCIDENTS (CLEAN SLATE)'}
          </button>
        </div>
      </div>

      {/* Testing Convenience Tools */}
      <div style={{ background: '#ffffff', borderRadius: '0.75rem', border: '1.5px solid #e2e8f0', padding: '1.5rem', marginBottom: '1.5rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 800, color: '#0f172a', margin: '0 0 0.5rem 0', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <Zap size={20} color="#f59e0b" />
          Rapid Test Injectors (Browser-Only Simulators)
        </h2>
        <p style={{ color: '#64748b', fontSize: '0.85rem', margin: '0 0 1.25rem 0' }}>
          Inject pre-configured crash scenarios directly into the backend without running the mobile app:
        </p>

        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
          <button
            onClick={handleSeedDemoIncident}
            disabled={loading}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              padding: '0.65rem 1rem',
              background: '#0f172a',
              color: '#ffffff',
              border: 'none',
              borderRadius: '0.375rem',
              fontWeight: 600,
              fontSize: '0.85rem',
              cursor: loading ? 'not-allowed' : 'pointer',
            }}
          >
            <Radio size={16} color="#38bdf8" />
            Inject Single Live Crash (MG Road - 8.5g)
          </button>

          <button
            onClick={handleSeedBlackspotIncidents}
            disabled={loading}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              padding: '0.65rem 1rem',
              background: '#7f1d1d',
              color: '#ffffff',
              border: 'none',
              borderRadius: '0.375rem',
              fontWeight: 600,
              fontSize: '0.85rem',
              cursor: loading ? 'not-allowed' : 'pointer',
            }}
          >
            <AlertTriangle size={16} color="#fca5a5" />
            Seed 3 Crashes at Silk Board (Trigger Blackspot Zone)
          </button>
        </div>
      </div>

      {/* Live System Activity Log */}
      <div style={{ background: '#0f172a', borderRadius: '0.75rem', padding: '1.25rem', color: '#f8fafc' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
          <span style={{ fontSize: '0.8rem', fontWeight: 700, color: '#94a3b8', letterSpacing: '0.05em', textTransform: 'uppercase' }}>
            Live System Audit & WebSocket Event Log
          </span>
          <span style={{ fontSize: '0.75rem', color: '#10b981', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <span style={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: '#10b981', display: 'inline-block' }} />
            Socket Listening
          </span>
        </div>

        <div style={{ fontFamily: 'monospace', fontSize: '0.775rem', maxHeight: '180px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
          {logs.length === 0 ? (
            <div style={{ color: '#64748b', fontStyle: 'italic' }}>No audit events logged yet in this session. Trigger an action above or from the mobile app.</div>
          ) : (
            logs.map((log, index) => (
              <div key={index} style={{ display: 'flex', gap: '0.75rem' }}>
                <span style={{ color: '#64748b' }}>[{log.time}]</span>
                <span style={{ color: log.type === 'success' ? '#86efac' : log.type === 'warning' ? '#fde047' : log.type === 'error' ? '#fca5a5' : '#93c5fd' }}>
                  {log.message}
                </span>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
