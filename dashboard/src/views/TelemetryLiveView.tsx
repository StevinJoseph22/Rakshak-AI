import React, { useState, useEffect, useRef } from 'react';
import {
  Activity,
  Gauge,
  Vibrate,
  AlertTriangle,
  Download,
  Wifi,
  Smartphone,
  ShieldCheck,
} from 'lucide-react';
import { getSocket } from '../services/socket';

export interface TelemetryPoint {
  device_id?: string;
  timestamp: string;
  net_g: number;
  ax: number;
  ay: number;
  az: number;
  gx?: number;
  gy?: number;
  gz?: number;
  speed_kmh: number;
  action_label: string;
  is_shake?: boolean;
  is_instant_action?: boolean;
  total_actions_recorded?: number;
}

export interface ActionAuditLog {
  id: string;
  timestamp: string;
  action_label: string;
  peak_g: number;
  speed_kmh: number;
  is_shake: boolean;
  is_impact: boolean;
}

export const TelemetryLiveView: React.FC = () => {
  const [telemetryHistory, setTelemetryHistory] = useState<TelemetryPoint[]>([]);
  const [actionLogs, setActionLogs] = useState<ActionAuditLog[]>([]);
  const [currentPoint, setCurrentPoint] = useState<TelemetryPoint>({
    timestamp: new Date().toISOString(),
    net_g: 1.0,
    ax: 0.0,
    ay: 0.0,
    az: 1.0,
    speed_kmh: 0.0,
    action_label: 'Device Ready • Waiting for Mobile Stream',
    is_shake: false,
  });

  const [peakGRecorded, setPeakGRecorded] = useState<number>(1.0);
  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [filterType, setFilterType] = useState<'ALL' | 'SHAKES' | 'IMPACTS'>('ALL');

  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  // Ingest real-time telemetry from Socket.io
  useEffect(() => {
    const socket = getSocket();

    const handleConnect = () => setIsConnected(true);
    const handleDisconnect = () => setIsConnected(false);

    if (socket.connected) {
      setIsConnected(true);
    }

    socket.on('connect', handleConnect);
    socket.on('disconnect', handleDisconnect);

    socket.on('telemetry_live_feed', (data: TelemetryPoint) => {
      setCurrentPoint(data);
      setPeakGRecorded((prev) => Math.max(prev, data.net_g));

      // Append to rolling chart points
      setTelemetryHistory((prev) => {
        const next = [...prev, data];
        return next.length > 80 ? next.slice(next.length - 80) : next;
      });

      // If this point is an identified action, log to permanent audit table
      if (
        data.is_shake ||
        data.is_instant_action ||
        data.net_g >= 4.0 ||
        data.action_label.includes('SHAKE') ||
        data.action_label.includes('IMPACT') ||
        data.action_label.includes('DROP')
      ) {
        const logItem: ActionAuditLog = {
          id: `EVT-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
          timestamp: data.timestamp,
          action_label: data.action_label,
          peak_g: data.net_g,
          speed_kmh: data.speed_kmh,
          is_shake: !!data.is_shake || data.action_label.includes('SHAKE'),
          is_impact: data.net_g >= 4.8 || data.action_label.includes('IMPACT'),
        };

        setActionLogs((prevLogs) => [logItem, ...prevLogs.slice(0, 49)]);
      }
    });

    // Request initial server buffer
    socket.emit('request_telemetry_history', (initialData: TelemetryPoint[]) => {
      if (initialData && initialData.length > 0) {
        setTelemetryHistory(initialData);
        setCurrentPoint(initialData[initialData.length - 1]);
      }
    });

    return () => {
      socket.off('connect', handleConnect);
      socket.off('disconnect', handleDisconnect);
      socket.off('telemetry_live_feed');
    };
  }, []);

  // Real-Time Canvas Oscilloscope Render
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const width = canvas.width;
    const height = canvas.height;

    // Clear background
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, width, height);

    // Draw grid lines
    ctx.strokeStyle = '#1e293b';
    ctx.lineWidth = 1;

    for (let y = 0; y < height; y += 40) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    // 1.0G Baseline (Gravity Line)
    const zeroY = height * 0.7; // 1.0G position
    ctx.strokeStyle = '#334155';
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.moveTo(0, zeroY);
    ctx.lineTo(width, zeroY);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = '#64748b';
    ctx.font = '10px monospace';
    ctx.fillText('1.0G Earth Baseline', 10, zeroY - 6);

    // 4.8G Impact Threshold Line
    const impactY = height * 0.2;
    ctx.strokeStyle = '#ef444455';
    ctx.setLineDash([6, 6]);
    ctx.beginPath();
    ctx.moveTo(0, impactY);
    ctx.lineTo(width, impactY);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = '#ef4444';
    ctx.fillText('4.8G IMPACT BREACH THRESHOLD', width - 200, impactY - 6);

    if (telemetryHistory.length < 2) return;

    // Render Net G-Force Waveform
    const step = width / Math.max(telemetryHistory.length - 1, 1);

    ctx.strokeStyle = '#38bdf8';
    ctx.lineWidth = 2.5;
    ctx.beginPath();

    telemetryHistory.forEach((pt, i) => {
      const x = i * step;
      // Scale: 1G at zeroY, 5G at impactY
      const g = pt.net_g;
      const y = zeroY - (g - 1.0) * ((zeroY - impactY) / 3.8);

      if (i === 0) {
        ctx.moveTo(x, Math.max(10, Math.min(height - 10, y)));
      } else {
        ctx.lineTo(x, Math.max(10, Math.min(height - 10, y)));
      }
    });

    ctx.stroke();

    // Draw active point glow at rightmost tip
    const lastPt = telemetryHistory[telemetryHistory.length - 1];
    const lastX = (telemetryHistory.length - 1) * step;
    const lastY = zeroY - (lastPt.net_g - 1.0) * ((zeroY - impactY) / 3.8);

    ctx.fillStyle = lastPt.is_shake ? '#f59e0b' : '#38bdf8';
    ctx.beginPath();
    ctx.arc(lastX, Math.max(10, Math.min(height - 10, lastY)), 6, 0, Math.PI * 2);
    ctx.fill();
  }, [telemetryHistory]);

  const handleSimulateShake = () => {
    const socket = getSocket();
    const mockShake: TelemetryPoint = {
      device_id: 'BROWSER-SIMULATOR',
      timestamp: new Date().toISOString(),
      net_g: 3.25,
      ax: 2.1,
      ay: -1.8,
      az: 1.4,
      speed_kmh: 0.0,
      action_label: '👋 PHONE SHAKE DETECTED (Simulated 3.25G)',
      is_shake: true,
      is_instant_action: true,
    };
    socket.emit('device_telemetry_live', mockShake);
  };

  const handleSimulateImpact = () => {
    const socket = getSocket();
    const mockImpact: TelemetryPoint = {
      device_id: 'BROWSER-SIMULATOR',
      timestamp: new Date().toISOString(),
      net_g: 6.85,
      ax: 4.8,
      ay: -3.2,
      az: 2.9,
      speed_kmh: 58.4,
      action_label: '🚨 6.85G CRASH IMPACT SPIKE (Simulated)',
      is_shake: false,
      is_instant_action: true,
    };
    socket.emit('device_telemetry_live', mockImpact);
  };

  const handleDownloadCsv = () => {
    if (actionLogs.length === 0) {
      alert('No recorded actions to export yet.');
      return;
    }
    const headers = 'ID,Timestamp,Action,Peak_G,Speed_KMH,Is_Shake,Is_Impact\n';
    const rows = actionLogs
      .map(
        (l) =>
          `"${l.id}","${l.timestamp}","${l.action_label}",${l.peak_g},${l.speed_kmh},${l.is_shake},${l.is_impact}`
      )
      .join('\n');
    const blob = new Blob([headers + rows], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `rakshak_telemetry_blackbox_${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const filteredLogs = actionLogs.filter((l) => {
    if (filterType === 'SHAKES') return l.is_shake;
    if (filterType === 'IMPACTS') return l.is_impact;
    return true;
  });

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '1.5rem 2rem' }}>
      {/* Title & Connection Header */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '1rem',
          marginBottom: '1.5rem',
        }}
      >
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <div
              style={{
                background: '#0ea5e922',
                color: '#0ea5e9',
                padding: '0.5rem',
                borderRadius: '0.5rem',
              }}
            >
              <Activity size={24} />
            </div>
            <div>
              <h2 style={{ margin: 0, fontSize: '1.4rem', fontWeight: 800, color: '#0f172a' }}>
                Live Edge Kinematics & Phone Blackbox Hub
              </h2>
              <p style={{ margin: 0, fontSize: '0.85rem', color: '#64748b' }}>
                Continuous 50Hz G-Force telemetry, user motion tracking & shake event recorder
              </p>
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              padding: '0.4rem 0.8rem',
              borderRadius: '999px',
              fontSize: '0.8rem',
              fontWeight: 600,
              background: isConnected ? '#ecfdf5' : '#fef2f2',
              color: isConnected ? '#059669' : '#dc2626',
              border: `1px solid ${isConnected ? '#a7f3d0' : '#fecaca'}`,
            }}
          >
            <Wifi size={14} />
            <span>{isConnected ? 'MOBILE LINK: ACTIVE' : 'SOCKET DISCONNECTED'}</span>
          </div>

          <button
            onClick={handleDownloadCsv}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.4rem',
              padding: '0.45rem 0.9rem',
              borderRadius: '0.375rem',
              background: '#0f172a',
              color: '#ffffff',
              border: 'none',
              fontSize: '0.8rem',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            <Download size={14} />
            <span>Export CSV</span>
          </button>
        </div>
      </div>

      {/* Top Telemetry KPI Cards */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          gap: '1rem',
          marginBottom: '1.5rem',
        }}
      >
        {/* Net G-Force Card */}
        <div
          style={{
            background: '#ffffff',
            borderRadius: '0.75rem',
            padding: '1.25rem',
            border: `1.5px solid ${currentPoint.net_g >= 4.8 ? '#ef4444' : currentPoint.is_shake ? '#f59e0b' : '#e2e8f0'}`,
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b' }}>
              NET ACCELERATION (G)
            </span>
            <Gauge size={16} color="#0ea5e9" />
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '0.4rem', marginTop: '0.5rem' }}>
            <span
              style={{
                fontSize: '2.2rem',
                fontWeight: 900,
                fontFamily: 'monospace',
                color:
                  currentPoint.net_g >= 4.8
                    ? '#ef4444'
                    : currentPoint.is_shake
                    ? '#d97706'
                    : '#0ea5e9',
              }}
            >
              {currentPoint.net_g.toFixed(2)}
            </span>
            <span style={{ fontSize: '1rem', fontWeight: 700, color: '#64748b' }}>G</span>
          </div>
          <p style={{ margin: '0.25rem 0 0 0', fontSize: '0.75rem', color: '#94a3b8' }}>
            Peak Recorded Today: <strong>{peakGRecorded.toFixed(2)}G</strong>
          </p>
        </div>

        {/* GPS Speed Card */}
        <div
          style={{
            background: '#ffffff',
            borderRadius: '0.75rem',
            padding: '1.25rem',
            border: '1px solid #e2e8f0',
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b' }}>
              GPS TRAVEL SPEED
            </span>
            <Activity size={16} color="#10b981" />
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '0.4rem', marginTop: '0.5rem' }}>
            <span
              style={{
                fontSize: '2.2rem',
                fontWeight: 900,
                fontFamily: 'monospace',
                color: '#10b981',
              }}
            >
              {currentPoint.speed_kmh.toFixed(1)}
            </span>
            <span style={{ fontSize: '0.85rem', fontWeight: 700, color: '#64748b' }}>km/h</span>
          </div>
          <p style={{ margin: '0.25rem 0 0 0', fontSize: '0.75rem', color: '#94a3b8' }}>
            {currentPoint.speed_kmh > 0 ? 'Vehicle in Transit' : 'Vehicle Stationary / Idle'}
          </p>
        </div>

        {/* Tri-Axial Breakdown Card */}
        <div
          style={{
            background: '#ffffff',
            borderRadius: '0.75rem',
            padding: '1.25rem',
            border: '1px solid #e2e8f0',
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
          }}
        >
          <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b' }}>
            TRI-AXIAL FORCES (X, Y, Z)
          </span>
          <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.6rem' }}>
            <div
              style={{
                flex: 1,
                background: '#fff7ed',
                border: '1px solid #ffedd5',
                borderRadius: '0.375rem',
                padding: '0.4rem 0.5rem',
              }}
            >
              <div style={{ fontSize: '0.65rem', fontWeight: 700, color: '#ea580c' }}>Ax (Lateral)</div>
              <div style={{ fontSize: '0.9rem', fontWeight: 800, color: '#9a3412', fontFamily: 'monospace' }}>
                {currentPoint.ax >= 0 ? '+' : ''}
                {currentPoint.ax.toFixed(2)}G
              </div>
            </div>
            <div
              style={{
                flex: 1,
                background: '#f0fdf4',
                border: '1px solid #dcfce7',
                borderRadius: '0.375rem',
                padding: '0.4rem 0.5rem',
              }}
            >
              <div style={{ fontSize: '0.65rem', fontWeight: 700, color: '#16a34a' }}>Ay (Longit)</div>
              <div style={{ fontSize: '0.9rem', fontWeight: 800, color: '#166534', fontFamily: 'monospace' }}>
                {currentPoint.ay >= 0 ? '+' : ''}
                {currentPoint.ay.toFixed(2)}G
              </div>
            </div>
            <div
              style={{
                flex: 1,
                background: '#faf5ff',
                border: '1px solid #f3e8ff',
                borderRadius: '0.375rem',
                padding: '0.4rem 0.5rem',
              }}
            >
              <div style={{ fontSize: '0.65rem', fontWeight: 700, color: '#9333ea' }}>Az (Vertical)</div>
              <div style={{ fontSize: '0.9rem', fontWeight: 800, color: '#6b21a8', fontFamily: 'monospace' }}>
                {currentPoint.az >= 0 ? '+' : ''}
                {currentPoint.az.toFixed(2)}G
              </div>
            </div>
          </div>
          <p style={{ margin: '0.35rem 0 0 0', fontSize: '0.75rem', color: '#94a3b8' }}>
            Normal 1G Earth Gravity vector resolved
          </p>
        </div>

        {/* Device Active State Card */}
        <div
          style={{
            background: '#ffffff',
            borderRadius: '0.75rem',
            padding: '1.25rem',
            border: `1.5px solid ${currentPoint.is_shake ? '#f59e0b' : '#e2e8f0'}`,
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b' }}>
              CLASSIFIED DEVICE ACTION
            </span>
            {currentPoint.is_shake ? (
              <Vibrate size={18} color="#d97706" />
            ) : (
              <Smartphone size={16} color="#64748b" />
            )}
          </div>
          <div
            style={{
              marginTop: '0.5rem',
              padding: '0.4rem 0.6rem',
              borderRadius: '0.375rem',
              background: currentPoint.is_shake
                ? '#fef3c7'
                : currentPoint.net_g >= 4.8
                ? '#fee2e2'
                : '#f1f5f9',
              color: currentPoint.is_shake
                ? '#b45309'
                : currentPoint.net_g >= 4.8
                ? '#dc2626'
                : '#334155',
              fontSize: '0.85rem',
              fontWeight: 800,
            }}
          >
            {currentPoint.action_label}
          </div>
          <p style={{ margin: '0.35rem 0 0 0', fontSize: '0.75rem', color: '#94a3b8' }}>
            Device ID: <strong>{currentPoint.device_id || 'CPH2573-MOBILE'}</strong>
          </p>
        </div>
      </div>

      {/* Real-Time Oscilloscope Waveform Canvas */}
      <div
        style={{
          background: '#0f172a',
          borderRadius: '0.75rem',
          padding: '1.25rem',
          marginBottom: '1.5rem',
          border: '1px solid #1e293b',
        }}
      >
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginBottom: '0.75rem',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <span
              style={{
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                background: '#38bdf8',
                display: 'inline-block',
              }}
            />
            <span style={{ color: '#ffffff', fontSize: '0.9rem', fontWeight: 800, letterSpacing: '0.5px' }}>
              REAL-TIME G-FORCE OSCILLOSCOPE (50Hz HIGH-FREQUENCY STREAM)
            </span>
          </div>

          <div style={{ display: 'flex', gap: '0.5rem' }}>
            <button
              onClick={handleSimulateShake}
              style={{
                background: '#f59e0b22',
                color: '#f59e0b',
                border: '1px solid #f59e0b55',
                padding: '0.35rem 0.75rem',
                borderRadius: '0.375rem',
                fontSize: '0.75rem',
                fontWeight: 700,
                cursor: 'pointer',
              }}
            >
              👋 Simulate Phone Shake
            </button>
            <button
              onClick={handleSimulateImpact}
              style={{
                background: '#ef444422',
                color: '#ef4444',
                border: '1px solid #ef444455',
                padding: '0.35rem 0.75rem',
                borderRadius: '0.375rem',
                fontSize: '0.75rem',
                fontWeight: 700,
                cursor: 'pointer',
              }}
            >
              🚨 Simulate 6.85G Crash
            </button>
          </div>
        </div>

        <canvas
          ref={canvasRef}
          width={1200}
          height={260}
          style={{ width: '100%', height: '240px', borderRadius: '0.5rem' }}
        />
      </div>

      {/* Permanent Actions Audit Table (All actions recorded since app opened) */}
      <div
        style={{
          background: '#ffffff',
          borderRadius: '0.75rem',
          padding: '1.25rem',
          border: '1px solid #e2e8f0',
          boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
        }}
      >
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            flexWrap: 'wrap',
            gap: '0.5rem',
            marginBottom: '1rem',
          }}
        >
          <div>
            <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 800, color: '#0f172a' }}>
              All Mobile Actions Recorded Since App Launch
            </h3>
            <p style={{ margin: 0, fontSize: '0.8rem', color: '#64748b' }}>
              Chronological blackbox ledger capturing phone handling, shakes, braking, and impacts
            </p>
          </div>

          <div style={{ display: 'flex', gap: '0.4rem' }}>
            <button
              onClick={() => setFilterType('ALL')}
              style={{
                padding: '0.3rem 0.7rem',
                borderRadius: '0.375rem',
                border: '1px solid #cbd5e1',
                background: filterType === 'ALL' ? '#0f172a' : '#ffffff',
                color: filterType === 'ALL' ? '#ffffff' : '#64748b',
                fontSize: '0.75rem',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              All Events ({actionLogs.length})
            </button>
            <button
              onClick={() => setFilterType('SHAKES')}
              style={{
                padding: '0.3rem 0.7rem',
                borderRadius: '0.375rem',
                border: '1px solid #f59e0b',
                background: filterType === 'SHAKES' ? '#f59e0b' : '#ffffff',
                color: filterType === 'SHAKES' ? '#ffffff' : '#d97706',
                fontSize: '0.75rem',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Shakes Only
            </button>
            <button
              onClick={() => setFilterType('IMPACTS')}
              style={{
                padding: '0.3rem 0.7rem',
                borderRadius: '0.375rem',
                border: '1px solid #ef4444',
                background: filterType === 'IMPACTS' ? '#ef4444' : '#ffffff',
                color: filterType === 'IMPACTS' ? '#ffffff' : '#dc2626',
                fontSize: '0.75rem',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Impacts Only
            </button>
          </div>
        </div>

        {filteredLogs.length === 0 ? (
          <div
            style={{
              padding: '2.5rem',
              textAlign: 'center',
              background: '#f8fafc',
              borderRadius: '0.5rem',
              color: '#94a3b8',
              fontSize: '0.875rem',
            }}
          >
            <Smartphone size={32} style={{ marginBottom: '0.5rem', opacity: 0.5 }} />
            <p style={{ margin: 0 }}>
              No actions logged yet. Open the Rakshak-AI mobile app and shake the phone to trigger
              actions!
            </p>
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
              <thead>
                <tr style={{ borderBottom: '2px solid #e2e8f0', color: '#64748b', fontSize: '0.75rem' }}>
                  <th style={{ padding: '0.6rem 0.8rem' }}>TIMESTAMP</th>
                  <th style={{ padding: '0.6rem 0.8rem' }}>ACTION CLASSIFICATION</th>
                  <th style={{ padding: '0.6rem 0.8rem' }}>PEAK G-FORCE</th>
                  <th style={{ padding: '0.6rem 0.8rem' }}>SPEED (km/h)</th>
                  <th style={{ padding: '0.6rem 0.8rem' }}>BLACKBOX VERDICT</th>
                </tr>
              </thead>
              <tbody>
                {filteredLogs.map((item) => {
                  const date = new Date(item.timestamp);
                  const timeFormatted = date.toLocaleTimeString();

                  return (
                    <tr
                      key={item.id}
                      style={{
                        borderBottom: '1px solid #f1f5f9',
                        fontSize: '0.825rem',
                        background: item.is_impact
                          ? '#fef2f2'
                          : item.is_shake
                          ? '#fffbeb'
                          : 'transparent',
                      }}
                    >
                      <td style={{ padding: '0.65rem 0.8rem', fontFamily: 'monospace', color: '#64748b' }}>
                        {timeFormatted}
                      </td>
                      <td style={{ padding: '0.65rem 0.8rem', fontWeight: 700, color: '#0f172a' }}>
                        {item.action_label}
                      </td>
                      <td style={{ padding: '0.65rem 0.8rem', fontFamily: 'monospace', fontWeight: 800 }}>
                        <span
                          style={{
                            padding: '0.2rem 0.45rem',
                            borderRadius: '0.25rem',
                            background:
                              item.peak_g >= 4.8
                                ? '#ef444422'
                                : item.is_shake
                                ? '#f59e0b22'
                                : '#e0f2fe',
                            color:
                              item.peak_g >= 4.8
                                ? '#dc2626'
                                : item.is_shake
                                ? '#b45309'
                                : '#0369a1',
                          }}
                        >
                          {item.peak_g.toFixed(2)} G
                        </span>
                      </td>
                      <td style={{ padding: '0.65rem 0.8rem', fontFamily: 'monospace', color: '#475569' }}>
                        {item.speed_kmh.toFixed(1)} km/h
                      </td>
                      <td style={{ padding: '0.65rem 0.8rem' }}>
                        {item.is_impact ? (
                          <span
                            style={{
                              color: '#dc2626',
                              fontWeight: 700,
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '0.25rem',
                            }}
                          >
                            <AlertTriangle size={14} /> High-G Collision Triggered
                          </span>
                        ) : item.is_shake ? (
                          <span
                            style={{
                              color: '#d97706',
                              fontWeight: 700,
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '0.25rem',
                            }}
                          >
                            <Vibrate size={14} /> User Agitation (Filtered)
                          </span>
                        ) : (
                          <span
                            style={{
                              color: '#16a34a',
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '0.25rem',
                            }}
                          >
                            <ShieldCheck size={14} /> Normal Kinematics
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
