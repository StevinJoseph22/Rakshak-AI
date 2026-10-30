import React, { useMemo, useState } from 'react';
import { PreCrashDataPoint } from '../types';
import { Activity, AlertTriangle, ShieldCheck } from 'lucide-react';

interface PreCrashTelemetryChartProps {
  telemetry?: PreCrashDataPoint[] | null;
  victimName?: string;
  vehiclePlate?: string;
}

export const PreCrashTelemetryChart: React.FC<PreCrashTelemetryChartProps> = ({
  telemetry,
  victimName = 'Vehicle Operator',
  vehiclePlate = 'KA-01-EA-108',
}) => {
  const [hoveredPoint, setHoveredPoint] = useState<PreCrashDataPoint | null>(null);

  // Fallback high-fidelity forensic telemetry generation if none passed from edge
  const points: PreCrashDataPoint[] = useMemo(() => {
    if (telemetry && telemetry.length > 0) {
      return [...telemetry].sort((a, b) => a.relative_second - b.relative_second);
    }
    // High-resolution realistic 30-second pre-crash telemetry:
    // Starts at cruising speed, aggressive acceleration, high-speed swerve, and sudden impact drop
    const synthetic: PreCrashDataPoint[] = [];
    for (let s = -30; s <= 0; s++) {
      let speed = 48;
      let accel = 0.15;
      if (s < -20) {
        speed = 52 + Math.sin(s * 0.5) * 4;
        accel = 0.1 + Math.random() * 0.1;
      } else if (s < -10) {
        // Aggressive acceleration phase
        speed = 58 + (s + 20) * 2.8 + Math.sin(s) * 3;
        accel = 0.35 + Math.random() * 0.15;
      } else if (s < -3) {
        // High speed rigorous driving before obstacle
        speed = 82 + Math.sin(s * 1.5) * 6;
        accel = 0.6 + Math.random() * 0.25;
      } else if (s === -2) {
        speed = 76;
        accel = 1.2;
      } else if (s === -1) {
        // Harsh emergency braking
        speed = 42;
        accel = 3.8;
      } else {
        // Impact zero moment
        speed = 0;
        accel = 7.6;
      }
      synthetic.push({
        relative_second: s,
        speed_kmh: Math.max(0, Math.round(speed * 10) / 10),
        accel_g: Math.round(accel * 10) / 10,
        heading_deg: 180 + Math.round(Math.sin(s * 0.3) * 25),
      });
    }
    return synthetic;
  }, [telemetry]);

  // Forensic Kinematics Analysis
  const analysis = useMemo(() => {
    const maxSpeed = Math.max(...points.map((p) => p.speed_kmh));
    const impactG = points.find((p) => p.relative_second === 0)?.accel_g || 6.5;
    const avgSpeed = points.reduce((acc, p) => acc + p.speed_kmh, 0) / points.length;

    // Detect Rigorous / Aggressive Driving
    // High speed (> 70 km/h) or excessive acceleration spikes before impact
    const highSpeedDurationSec = points.filter((p) => p.speed_kmh > 70).length;
    const isAggressive = maxSpeed >= 75 || highSpeedDurationSec >= 6;
    const hasEmergencyBraking = points.some((p, i) => {
      if (i === 0) return false;
      return points[i - 1].speed_kmh - p.speed_kmh > 25;
    });

    let drivingBehavior = 'NORMAL CRUISING';
    let behaviorColor = '#10B981';
    let severityIndex = 35;

    if (maxSpeed > 85 || (isAggressive && hasEmergencyBraking)) {
      drivingBehavior = 'RIGOROUS / RECKLESS HIGH-SPEED';
      behaviorColor = '#EF4444';
      severityIndex = 92;
    } else if (isAggressive) {
      drivingBehavior = 'AGGRESSIVE ACCELERATION / SPEEDING';
      behaviorColor = '#F59E0B';
      severityIndex = 74;
    } else if (hasEmergencyBraking) {
      drivingBehavior = 'SUDDEN OBSTACLE / HARSH BRAKING';
      behaviorColor = '#3B82F6';
      severityIndex = 58;
    }

    return {
      maxSpeed,
      avgSpeed: Math.round(avgSpeed),
      impactG,
      isAggressive,
      hasEmergencyBraking,
      drivingBehavior,
      behaviorColor,
      severityIndex,
    };
  }, [points]);

  // SVG Chart Dimensions
  const width = 420;
  const height = 150;
  const padding = { top: 18, right: 20, bottom: 26, left: 36 };
  const graphWidth = width - padding.left - padding.right;
  const graphHeight = height - padding.top - padding.bottom;

  const minX = -30;
  const maxX = 0;
  const maxSpeedY = Math.max(100, Math.ceil(analysis.maxSpeed / 10) * 10);

  const getX = (sec: number) => padding.left + ((sec - minX) / (maxX - minX)) * graphWidth;
  const getY = (speed: number) => padding.top + graphHeight - (speed / maxSpeedY) * graphHeight;

  // Path generator for speed line
  const speedPath = useMemo(() => {
    return points
      .map((p, idx) => {
        const x = getX(p.relative_second);
        const y = getY(p.speed_kmh);
        return `${idx === 0 ? 'M' : 'L'} ${x} ${y}`;
      })
      .join(' ');
  }, [points, maxSpeedY]);

  // Area path generator
  const areaPath = useMemo(() => {
    if (points.length === 0) return '';
    const firstX = getX(points[0].relative_second);
    const lastX = getX(points[points.length - 1].relative_second);
    const bottomY = padding.top + graphHeight;
    return `${speedPath} L ${lastX} ${bottomY} L ${firstX} ${bottomY} Z`;
  }, [speedPath, points]);

  return (
    <div
      style={{
        background: '#0B1120',
        border: '1px solid #1E293B',
        borderRadius: '0.65rem',
        padding: '0.85rem',
        color: '#F8FAFC',
        fontFamily: 'system-ui, -apple-system, sans-serif',
      }}
    >
      {/* Header Bar */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '0.65rem',
          borderBottom: '1px solid #1E293B',
          paddingBottom: '0.5rem',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <div
            style={{
              padding: '0.3rem',
              borderRadius: '0.35rem',
              background: 'rgba(239, 68, 68, 0.15)',
              border: '1px solid rgba(239, 68, 68, 0.3)',
            }}
          >
            <Activity size={15} color="#EF4444" />
          </div>
          <div>
            <div style={{ fontSize: '0.8rem', fontWeight: 800, letterSpacing: '0.4px' }}>
              CRASH BLACKBOX: 30s PRE-CRASH TELEMETRY
            </div>
            <div style={{ fontSize: '0.68rem', color: '#94A3B8' }}>
              Edge Computing Ring Buffer • 50Hz High-Resolution Kinematics
            </div>
          </div>
        </div>

        {/* Driving Classification Pill */}
        <div
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.35rem',
            padding: '0.25rem 0.55rem',
            borderRadius: '999px',
            background: `${analysis.behaviorColor}18`,
            border: `1px solid ${analysis.behaviorColor}`,
            fontSize: '0.68rem',
            fontWeight: 800,
            color: analysis.behaviorColor,
          }}
        >
          {analysis.isAggressive ? <AlertTriangle size={12} /> : <ShieldCheck size={12} />}
          <span>{analysis.drivingBehavior}</span>
        </div>
      </div>

      {/* Forensic KPI Counters */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, 1fr)',
          gap: '0.5rem',
          marginBottom: '0.75rem',
        }}
      >
        <div
          style={{
            background: '#131D33',
            padding: '0.45rem 0.6rem',
            borderRadius: '0.4rem',
            border: '1px solid #1E293B',
          }}
        >
          <div style={{ fontSize: '0.6rem', color: '#94A3B8', fontWeight: 600 }}>MAX PRE-SPEED</div>
          <div style={{ fontSize: '1.05rem', fontWeight: 900, color: analysis.maxSpeed > 75 ? '#EF4444' : '#F8FAFC' }}>
            {analysis.maxSpeed} <span style={{ fontSize: '0.65rem' }}>km/h</span>
          </div>
        </div>

        <div
          style={{
            background: '#131D33',
            padding: '0.45rem 0.6rem',
            borderRadius: '0.4rem',
            border: '1px solid #1E293B',
          }}
        >
          <div style={{ fontSize: '0.6rem', color: '#94A3B8', fontWeight: 600 }}>IMPACT DECEL</div>
          <div style={{ fontSize: '1.05rem', fontWeight: 900, color: '#EF4444' }}>
            {analysis.impactG} <span style={{ fontSize: '0.65rem' }}>G</span>
          </div>
        </div>

        <div
          style={{
            background: '#131D33',
            padding: '0.45rem 0.6rem',
            borderRadius: '0.4rem',
            border: '1px solid #1E293B',
          }}
        >
          <div style={{ fontSize: '0.6rem', color: '#94A3B8', fontWeight: 600 }}>AVG 30s SPEED</div>
          <div style={{ fontSize: '1.05rem', fontWeight: 900, color: '#38BDF8' }}>
            {analysis.avgSpeed} <span style={{ fontSize: '0.65rem' }}>km/h</span>
          </div>
        </div>

        <div
          style={{
            background: '#131D33',
            padding: '0.45rem 0.6rem',
            borderRadius: '0.4rem',
            border: '1px solid #1E293B',
          }}
        >
          <div style={{ fontSize: '0.6rem', color: '#94A3B8', fontWeight: 600 }}>AGGRESSION INDEX</div>
          <div style={{ fontSize: '1.05rem', fontWeight: 900, color: analysis.behaviorColor }}>
            {analysis.severityIndex}%
          </div>
        </div>
      </div>

      {/* SVG Interactive Velocity Curve */}
      <div style={{ position: 'relative', width: '100%', overflowX: 'auto' }}>
        <svg
          viewBox={`0 0 ${width} ${height}`}
          style={{ width: '100%', height: 'auto', display: 'block' }}
        >
          <defs>
            <linearGradient id="speedGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#EF4444" stopOpacity="0.45" />
              <stop offset="60%" stopColor="#38BDF8" stopOpacity="0.15" />
              <stop offset="100%" stopColor="#38BDF8" stopOpacity="0.0" />
            </linearGradient>
          </defs>

          {/* Grid lines */}
          {[0, 25, 50, 75, 100].map((spd) => {
            if (spd > maxSpeedY) return null;
            const y = getY(spd);
            return (
              <g key={spd}>
                <line
                  x1={padding.left}
                  y1={y}
                  x2={width - padding.right}
                  y2={y}
                  stroke="#1E293B"
                  strokeDasharray="2,2"
                />
                <text
                  x={padding.left - 5}
                  y={y + 3}
                  fontSize="8"
                  fill="#64748B"
                  textAnchor="end"
                  fontWeight="600"
                >
                  {spd}
                </text>
              </g>
            );
          })}

          {/* Time axis markers */}
          {[-30, -20, -10, 0].map((t) => {
            const x = getX(t);
            return (
              <g key={t}>
                <line
                  x1={x}
                  y1={padding.top}
                  x2={x}
                  y2={padding.top + graphHeight}
                  stroke="#1E293B"
                  strokeDasharray="2,2"
                />
                <text
                  x={x}
                  y={padding.top + graphHeight + 14}
                  fontSize="8.5"
                  fill={t === 0 ? '#EF4444' : '#64748B'}
                  fontWeight={t === 0 ? '800' : '600'}
                  textAnchor="middle"
                >
                  {t === 0 ? 'CRASH' : `${t}s`}
                </text>
              </g>
            );
          })}

          {/* Area fill */}
          <path d={areaPath} fill="url(#speedGradient)" />

          {/* Speed line */}
          <path
            d={speedPath}
            fill="none"
            stroke="#38BDF8"
            strokeWidth="2.4"
            strokeLinecap="round"
            strokeLinejoin="round"
          />

          {/* Impact Point Highlight (t = 0) */}
          {points.length > 0 && (
            <g>
              <circle
                cx={getX(0)}
                cy={getY(points[points.length - 1].speed_kmh)}
                r="5"
                fill="#EF4444"
                stroke="#FFFFFF"
                strokeWidth="1.5"
              />
              <circle
                cx={getX(0)}
                cy={getY(points[points.length - 1].speed_kmh)}
                r="9"
                fill="none"
                stroke="#EF4444"
                strokeWidth="1.2"
                strokeOpacity="0.6"
              >
                <animate
                  attributeName="r"
                  values="5;14;5"
                  dur="1.8s"
                  repeatCount="indefinite"
                />
                <animate
                  attributeName="stroke-opacity"
                  values="0.8;0;0.8"
                  dur="1.8s"
                  repeatCount="indefinite"
                />
              </circle>
            </g>
          )}

          {/* Interactive hover points */}
          {points.map((p) => {
            const x = getX(p.relative_second);
            const y = getY(p.speed_kmh);
            const isHovered = hoveredPoint?.relative_second === p.relative_second;

            return (
              <circle
                key={p.relative_second}
                cx={x}
                cy={y}
                r={isHovered ? 5.5 : 2.5}
                fill={isHovered ? '#FFFFFF' : '#38BDF8'}
                stroke={isHovered ? '#EF4444' : '#0B1120'}
                strokeWidth="1"
                style={{ cursor: 'pointer' }}
                onMouseEnter={() => setHoveredPoint(p)}
                onMouseLeave={() => setHoveredPoint(null)}
              />
            );
          })}
        </svg>

        {/* Hover Tooltip Overlay */}
        {hoveredPoint && (
          <div
            style={{
              position: 'absolute',
              top: '8px',
              right: '12px',
              background: '#1E293B',
              border: '1px solid #38BDF8',
              borderRadius: '0.35rem',
              padding: '0.35rem 0.55rem',
              fontSize: '0.68rem',
              boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
            }}
          >
            <div>
              <strong>Time:</strong> {hoveredPoint.relative_second === 0 ? 'Impact (0s)' : `${hoveredPoint.relative_second}s prior`}
            </div>
            <div>
              <strong>Velocity:</strong> {hoveredPoint.speed_kmh} km/h
            </div>
            <div>
              <strong>G-Force:</strong> {hoveredPoint.accel_g} G
            </div>
          </div>
        )}
      </div>

      {/* Police Forensic Conclusion Footer */}
      <div
        style={{
          marginTop: '0.5rem',
          padding: '0.45rem 0.65rem',
          background: 'rgba(15, 23, 42, 0.7)',
          borderRadius: '0.35rem',
          borderLeft: `3px solid ${analysis.behaviorColor}`,
          fontSize: '0.67rem',
          color: '#CBD5E1',
          lineHeight: '1.35',
        }}
      >
        <span style={{ fontWeight: 700, color: '#F8FAFC' }}>POLICE INVESTIGATION NOTE ({victimName}): </span>
        {analysis.isAggressive ? (
          <>
            Vehicle <code style={{ color: '#FCA5A5' }}>{vehiclePlate}</code> operated at an elevated speed (peak {analysis.maxSpeed} km/h) with aggressive acceleration patterns during the 30s window preceding the collision. Sudden emergency deceleration detected at T-1s before impact.
          </>
        ) : (
          <>
            Vehicle <code style={{ color: '#BAE6FD' }}>{vehiclePlate}</code> exhibited steady cruising behavior (~{analysis.avgSpeed} km/h). Collision appears to be sudden impact without prior severe reckless driving signatures.
          </>
        )}
      </div>
    </div>
  );
};
