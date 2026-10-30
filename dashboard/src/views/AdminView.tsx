import React, { useState, useEffect, useMemo } from 'react';
import {
  Trash2,
  RefreshCw,
  Radio,
  Hospital as HospitalIcon,
  AlertTriangle,
  CheckCircle2,
  Zap,
  Server,
  Activity,
  Search,
  Key,
  Copy,
  Check,
  MapPin,
  Phone,
  ExternalLink,
  ShieldCheck,
  Download,
  Building2,
  Eye,
  EyeOff,
  Filter,
} from 'lucide-react';
import { getSocket } from '../services/socket';
import { SEEDED_HOSPITALS } from '../config/hospitals';
import { Hospital } from '../types';

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

  // Hospital directory search and filter state
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedZone, setSelectedZone] = useState<string>('ALL');
  const [filterTraumaOnly, setFilterTraumaOnly] = useState<boolean>(false);
  const [filterIcuOnly, setFilterIcuOnly] = useState<boolean>(false);
  const [showPasswords, setShowPasswords] = useState<Record<string, boolean>>({});
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

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

  // Filtered hospitals calculation
  const filteredHospitals = useMemo(() => {
    return SEEDED_HOSPITALS.filter((h: Hospital) => {
      // 1. Text Search across name, address, phone, username, zone
      const query = searchQuery.trim().toLowerCase();
      const matchText =
        !query ||
        h.name.toLowerCase().includes(query) ||
        h.address.toLowerCase().includes(query) ||
        h.phone.toLowerCase().includes(query) ||
        (h.username && h.username.toLowerCase().includes(query)) ||
        (h.zone && h.zone.toLowerCase().includes(query));

      // 2. Zone filter
      const matchZone = selectedZone === 'ALL' || h.zone === selectedZone;

      // 3. Trauma filter
      const matchTrauma = !filterTraumaOnly || h.has_trauma_center;

      // 4. ICU filter
      const matchIcu = !filterIcuOnly || h.has_icu_capacity;

      return matchText && matchZone && matchTrauma && matchIcu;
    });
  }, [searchQuery, selectedZone, filterTraumaOnly, filterIcuOnly]);

  const copyToClipboard = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => {
      setCopiedKey(null);
    }, 2000);
  };

  const togglePasswordVisibility = (hospitalId: string) => {
    setShowPasswords((prev) => ({
      ...prev,
      [hospitalId]: !prev[hospitalId],
    }));
  };

  const handleExportCsv = () => {
    const headers = [
      'Hospital Name',
      'Portal Username',
      'Portal Password',
      'Role',
      'Emergency Hotline',
      'Trauma Tier',
      'ICU Beds',
      'Zone',
      'Latitude',
      'Longitude',
      'Full Address',
      'Hospital ID',
    ];

    const rows = SEEDED_HOSPITALS.map((h: Hospital) => [
      `"${h.name.replace(/"/g, '""')}"`,
      `"${h.username || 'unassigned'}"`,
      `"${h.password || 'hospital123'}"`,
      '"hospital_staff"',
      `"${h.phone}"`,
      `"${h.trauma_tier || (h.has_trauma_center ? 'Level-1 Trauma' : 'General Care')}"`,
      `"${h.icu_beds ?? (h.has_icu_capacity ? 4 : 0)}"`,
      `"${h.zone || 'Bengaluru'}"`,
      h.latitude,
      h.longitude,
      `"${h.address.replace(/"/g, '""')}"`,
      `"${h.id}"`,
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `rakshak_hospital_credentials_registry_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const activeCount =
    (stats?.status_counts.broadcasting || 0) +
    (stats?.status_counts.suspected || 0) +
    (stats?.status_counts.escalated || 0) +
    (stats?.status_counts.accepted || 0) +
    (stats?.status_counts.en_route || 0);

  const zones = ['ALL', 'Central', 'South', 'South-East', 'East', 'North', 'North-East', 'West', 'North-West', 'Highway Corridor'];

  return (
    <div style={{ maxWidth: '1400px', margin: '0 auto', padding: '1.5rem 2rem' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '1rem', marginBottom: '1.5rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <Server size={26} color="#dc2626" />
            <h1 style={{ fontSize: '1.6rem', fontWeight: 800, color: '#0f172a', margin: 0 }}>
              Rakshak-AI Master Administration & Hospital Credential Vault
            </h1>
          </div>
          <p style={{ margin: '0.35rem 0 0 0', color: '#64748b', fontSize: '0.875rem' }}>
            Real-time management for 81 verified hospitals, emergency casualty hotlines, PostGIS coordinates, and pre-configured staff authentication credentials.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
          <button
            onClick={handleExportCsv}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.45rem',
              padding: '0.55rem 0.95rem',
              background: '#047857',
              border: 'none',
              borderRadius: '0.375rem',
              color: '#ffffff',
              fontSize: '0.825rem',
              fontWeight: 700,
              cursor: 'pointer',
              boxShadow: '0 2px 6px rgba(4, 120, 87, 0.25)',
            }}
          >
            <Download size={15} />
            Export Credentials Manifest (CSV)
          </button>

          <button
            onClick={fetchStats}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.4rem',
              padding: '0.55rem 0.85rem',
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
            Refresh State
          </button>
        </div>
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
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: '1rem', marginBottom: '1.5rem' }}>
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
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Connected Hospitals</span>
            <HospitalIcon size={18} color="#0284c7" />
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#0284c7', marginTop: '0.25rem' }}>
            {SEEDED_HOSPITALS.length}
          </div>
          <div style={{ fontSize: '0.725rem', color: '#64748b', marginTop: '0.25rem' }}>
            All Bengaluru Zones & Corridors
          </div>
        </div>

        <div style={{ background: '#ffffff', padding: '1rem', borderRadius: '0.5rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Trauma Centers</span>
            <ShieldCheck size={18} color="#dc2626" />
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#dc2626', marginTop: '0.25rem' }}>
            {SEEDED_HOSPITALS.filter((h: Hospital) => h.has_trauma_center).length}
          </div>
          <div style={{ fontSize: '0.725rem', color: '#94a3b8', marginTop: '0.25rem' }}>
            Level-1 & Level-2 Apex Facilities
          </div>
        </div>

        <div style={{ background: '#ffffff', padding: '1rem', borderRadius: '0.5rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Total ICU Capacity</span>
            <Building2 size={18} color="#16a34a" />
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#16a34a', marginTop: '0.25rem' }}>
            {SEEDED_HOSPITALS.reduce((acc: number, h: Hospital) => acc + (h.icu_beds || 0), 0)} Beds
          </div>
          <div style={{ fontSize: '0.725rem', color: '#94a3b8', marginTop: '0.25rem' }}>
            Live tracked emergency beds
          </div>
        </div>

        <div style={{ background: '#ffffff', padding: '1rem', borderRadius: '0.5rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Staff Credentials</span>
            <Key size={18} color="#7c3aed" />
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#7c3aed', marginTop: '0.25rem' }}>
            {SEEDED_HOSPITALS.length} SSO
          </div>
          <div style={{ fontSize: '0.725rem', color: '#94a3b8', marginTop: '0.25rem' }}>
            Password: <code>hospital123</code>
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* SECTION 1: MASTER HOSPITAL DIRECTORY & CREDENTIALS VAULT                 */}
      {/* ========================================================================= */}
      <div
        style={{
          background: '#ffffff',
          borderRadius: '0.75rem',
          border: '1.5px solid #e2e8f0',
          padding: '1.5rem',
          marginBottom: '2rem',
          boxShadow: '0 4px 12px rgba(0,0,0,0.03)',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem', marginBottom: '1.25rem' }}>
          <div>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 800, color: '#0f172a', margin: '0 0 0.25rem 0', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Key size={22} color="#0284c7" />
              Hospital Network Registry, Facilities & Login Credentials Vault
            </h2>
            <p style={{ color: '#64748b', fontSize: '0.85rem', margin: 0 }}>
              Complete institutional master records. Each hospital staff account has pre-configured single-sign-on access for emergency receiving and ABHA record decryption.
            </p>
          </div>

          <div style={{ fontSize: '0.85rem', fontWeight: 700, color: '#0284c7', background: '#f0f9ff', border: '1px solid #bae6fd', padding: '0.35rem 0.75rem', borderRadius: '1rem' }}>
            Showing {filteredHospitals.length} of {SEEDED_HOSPITALS.length} Hospitals
          </div>
        </div>

        {/* Search & Filter Controls */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', marginBottom: '1.25rem' }}>
          <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
            {/* Search Input */}
            <div style={{ flex: '1 1 300px', position: 'relative' }}>
              <Search size={16} color="#94a3b8" style={{ position: 'absolute', left: '0.85rem', top: '50%', transform: 'translateY(-50%)' }} />
              <input
                type="text"
                placeholder="Search hospital by name, street address, hotline, or portal username..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{
                  width: '100%',
                  padding: '0.65rem 1rem 0.65rem 2.4rem',
                  borderRadius: '0.5rem',
                  border: '1.5px solid #cbd5e1',
                  fontSize: '0.85rem',
                  outline: 'none',
                  boxSizing: 'border-box',
                }}
              />
            </div>

            {/* Quick Filters */}
            <button
              onClick={() => setFilterTraumaOnly((p) => !p)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.4rem',
                padding: '0.55rem 0.85rem',
                background: filterTraumaOnly ? '#fee2e2' : '#f8fafc',
                border: `1.5px solid ${filterTraumaOnly ? '#ef4444' : '#cbd5e1'}`,
                color: filterTraumaOnly ? '#991b1b' : '#475569',
                borderRadius: '0.5rem',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              <ShieldCheck size={14} color={filterTraumaOnly ? '#ef4444' : '#64748b'} />
              Level-1 Trauma Bays Only
            </button>

            <button
              onClick={() => setFilterIcuOnly((p) => !p)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.4rem',
                padding: '0.55rem 0.85rem',
                background: filterIcuOnly ? '#dcfce7' : '#f8fafc',
                border: `1.5px solid ${filterIcuOnly ? '#22c55e' : '#cbd5e1'}`,
                color: filterIcuOnly ? '#166534' : '#475569',
                borderRadius: '0.5rem',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              <Building2 size={14} color={filterIcuOnly ? '#22c55e' : '#64748b'} />
              ICU Ready Only
            </button>
          </div>

          {/* Zone Selector Chips */}
          <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', marginRight: '0.25rem', display: 'flex', alignItems: 'center', gap: '0.2rem' }}>
              <Filter size={12} /> Zone:
            </span>
            {zones.map((zone) => (
              <button
                key={zone}
                onClick={() => setSelectedZone(zone)}
                style={{
                  padding: '0.3rem 0.65rem',
                  fontSize: '0.75rem',
                  borderRadius: '1rem',
                  fontWeight: selectedZone === zone ? 700 : 500,
                  background: selectedZone === zone ? '#0f172a' : '#f1f5f9',
                  color: selectedZone === zone ? '#ffffff' : '#475569',
                  border: 'none',
                  cursor: 'pointer',
                  transition: 'all 0.1s ease',
                }}
              >
                {zone === 'ALL' ? 'All Zones' : zone}
              </button>
            ))}
          </div>
        </div>

        {/* Hospital Cards Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(420px, 1fr))', gap: '1rem', maxHeight: '720px', overflowY: 'auto', paddingRight: '0.25rem' }}>
          {filteredHospitals.length === 0 ? (
            <div style={{ gridColumn: '1 / -1', padding: '3rem', textAlign: 'center', color: '#94a3b8' }}>
              <HospitalIcon size={40} style={{ margin: '0 auto 0.75rem auto', opacity: 0.5 }} />
              <div style={{ fontSize: '1rem', fontWeight: 700, color: '#475569' }}>No hospitals match your search criteria</div>
              <div style={{ fontSize: '0.825rem', marginTop: '0.25rem' }}>Try clearing your search query or switching zone filters.</div>
            </div>
          ) : (
            filteredHospitals.map((h: Hospital, idx: number) => {
              const passVisible = showPasswords[h.id] || false;
              const defaultPass = h.password || 'hospital123';
              const credText = `Username: ${h.username || 'unassigned'} | Password: ${defaultPass}`;
              const isCopied = copiedKey === h.id;

              return (
                <div
                  key={h.id}
                  style={{
                    background: '#f8fafc',
                    border: '1px solid #e2e8f0',
                    borderRadius: '0.625rem',
                    padding: '1rem',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.02)',
                    transition: 'border-color 0.15s ease',
                  }}
                >
                  <div>
                    {/* Top Row: Index + Name + Zone */}
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '0.5rem', marginBottom: '0.4rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', flex: 1 }}>
                        <span style={{ fontSize: '0.75rem', fontWeight: 800, color: '#94a3b8', background: '#ffffff', border: '1px solid #e2e8f0', padding: '0.1rem 0.35rem', borderRadius: '4px' }}>
                          #{idx + 1}
                        </span>
                        <h3 style={{ fontSize: '0.95rem', fontWeight: 800, color: '#0f172a', margin: 0, lineHeight: 1.3 }}>
                          {h.name}
                        </h3>
                      </div>
                      <span
                        style={{
                          fontSize: '0.7rem',
                          fontWeight: 700,
                          padding: '0.2rem 0.5rem',
                          borderRadius: '1rem',
                          background: '#e0f2fe',
                          color: '#0369a1',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {h.zone || 'Bengaluru'}
                      </span>
                    </div>

                    {/* Facility Tier & Badges */}
                    <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap', marginBottom: '0.6rem' }}>
                      <span
                        style={{
                          fontSize: '0.7rem',
                          fontWeight: 700,
                          padding: '0.15rem 0.45rem',
                          borderRadius: '4px',
                          background: h.has_trauma_center ? '#fee2e2' : '#f1f5f9',
                          color: h.has_trauma_center ? '#991b1b' : '#64748b',
                        }}
                      >
                        {h.trauma_tier || (h.has_trauma_center ? 'Level-1 Trauma Center' : 'Secondary Medical')}
                      </span>

                      <span
                        style={{
                          fontSize: '0.7rem',
                          fontWeight: 700,
                          padding: '0.15rem 0.45rem',
                          borderRadius: '4px',
                          background: '#dcfce7',
                          color: '#166534',
                        }}
                      >
                        {h.icu_beds ?? (h.has_icu_capacity ? 4 : 0)} ICU Beds Available
                      </span>

                      {h.ct_mri !== false && (
                        <span
                          style={{
                            fontSize: '0.7rem',
                            fontWeight: 700,
                            padding: '0.15rem 0.45rem',
                            borderRadius: '4px',
                            background: '#fef3c7',
                            color: '#92400e',
                          }}
                        >
                          24/7 CT & MRI
                        </span>
                      )}
                    </div>

                    {/* Address & Geo-Coordinates */}
                    <div style={{ fontSize: '0.775rem', color: '#475569', marginBottom: '0.4rem', display: 'flex', alignItems: 'flex-start', gap: '0.35rem' }}>
                      <MapPin size={14} color="#64748b" style={{ flexShrink: 0, marginTop: '2px' }} />
                      <span style={{ lineHeight: 1.35 }}>{h.address}</span>
                    </div>

                    <div style={{ fontSize: '0.75rem', color: '#64748b', marginBottom: '0.5rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <span>
                        GPS: <strong>{h.latitude.toFixed(4)}, {h.longitude.toFixed(4)}</strong>
                      </span>
                      <a
                        href={`https://www.google.com/maps/search/?api=1&query=${h.latitude},${h.longitude}`}
                        target="_blank"
                        rel="noreferrer"
                        style={{ color: '#0284c7', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '0.2rem', fontWeight: 600 }}
                      >
                        Open Maps <ExternalLink size={11} />
                      </a>
                    </div>

                    {/* Contact Phone Hotline */}
                    <div style={{ fontSize: '0.775rem', color: '#0f172a', marginBottom: '0.65rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: '#ffffff', padding: '0.4rem 0.6rem', borderRadius: '4px', border: '1px solid #e2e8f0' }}>
                      <span style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                        <Phone size={13} color="#059669" />
                        <strong>Hotline:</strong> {h.phone}
                      </span>
                      <button
                        onClick={() => copyToClipboard(h.phone, `phone_${h.id}`)}
                        style={{
                          background: 'none',
                          border: 'none',
                          color: copiedKey === `phone_${h.id}` ? '#059669' : '#0284c7',
                          fontSize: '0.725rem',
                          fontWeight: 600,
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '0.2rem',
                        }}
                      >
                        {copiedKey === `phone_${h.id}` ? <Check size={12} /> : <Copy size={12} />}
                        {copiedKey === `phone_${h.id}` ? 'Copied' : 'Copy'}
                      </button>
                    </div>
                  </div>

                  {/* Portal Authentication Credentials Box */}
                  <div
                    style={{
                      background: '#ffffff',
                      border: '1.5px solid #cbd5e1',
                      borderRadius: '0.5rem',
                      padding: '0.65rem 0.85rem',
                      marginTop: '0.5rem',
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.35rem' }}>
                      <span style={{ fontSize: '0.725rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                        <Key size={13} color="#7c3aed" /> Staff Portal Login Credentials
                      </span>
                      <span style={{ fontSize: '0.675rem', fontWeight: 700, color: '#059669', background: '#dcfce7', padding: '0.1rem 0.35rem', borderRadius: '3px' }}>
                        ROLE: hospital_staff
                      </span>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem', fontSize: '0.75rem', marginBottom: '0.45rem' }}>
                      <div>
                        <span style={{ color: '#64748b' }}>Username:</span>
                        <div style={{ fontWeight: 700, color: '#0f172a', fontFamily: 'monospace', fontSize: '0.8rem' }}>
                          {h.username || 'unassigned'}
                        </div>
                      </div>

                      <div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ color: '#64748b' }}>Password:</span>
                          <button
                            onClick={() => togglePasswordVisibility(h.id)}
                            style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', color: '#64748b' }}
                            title={passVisible ? 'Hide Password' : 'Show Password'}
                          >
                            {passVisible ? <EyeOff size={12} /> : <Eye size={12} />}
                          </button>
                        </div>
                        <div style={{ fontWeight: 700, color: '#0f172a', fontFamily: 'monospace', fontSize: '0.8rem' }}>
                          {passVisible ? defaultPass : '•••••••••••'}
                        </div>
                      </div>
                    </div>

                    <button
                      onClick={() => copyToClipboard(credText, h.id)}
                      style={{
                        width: '100%',
                        padding: '0.35rem 0.5rem',
                        background: isCopied ? '#dcfce7' : '#f1f5f9',
                        border: `1px solid ${isCopied ? '#86efac' : '#cbd5e1'}`,
                        borderRadius: '0.35rem',
                        color: isCopied ? '#166534' : '#334155',
                        fontSize: '0.75rem',
                        fontWeight: 700,
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        gap: '0.35rem',
                        transition: 'all 0.15s ease',
                      }}
                    >
                      {isCopied ? <Check size={13} color="#166534" /> : <Copy size={13} />}
                      {isCopied ? 'Credentials Copied to Clipboard!' : 'Copy Portal Credentials'}
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* ========================================================================= */}
      {/* SECTION 2: OPERATIONS CONTROL & INCIDENT PURGE                           */}
      {/* ========================================================================= */}
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

      {/* ========================================================================= */}
      {/* SECTION 3: TESTING SCENARIO INJECTORS                                    */}
      {/* ========================================================================= */}
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

      {/* ========================================================================= */}
      {/* SECTION 4: LIVE SYSTEM WEBSOCKET AUDIT LOG                               */}
      {/* ========================================================================= */}
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
