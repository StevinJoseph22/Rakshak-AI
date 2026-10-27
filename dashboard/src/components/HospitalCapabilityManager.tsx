/* eslint-disable react-refresh/only-export-components */
import React from 'react';
import {
  Activity,
  CheckCircle2,
  Cpu,
  Eye,
  HeartPulse,
  Microscope,
  Radio,
  Stethoscope,
  Wrench,
  Zap,
} from 'lucide-react';
import { HospitalCapabilities, CapabilityMatchResult, IncidentPayload } from '../types';

export const DEFAULT_HOSPITAL_CAPABILITIES: HospitalCapabilities = {
  ct_scan: true,
  mri: true,
  neuro_icu: true,
  blood_bank: true,
  ortho_ot: true,
  fast_ultrasound: true,
  ventilators: true,
  general_surgery: true,
};

export interface CapabilityItem {
  key: keyof HospitalCapabilities;
  label: string;
  shortDesc: string;
  icon: React.ReactNode;
  category: 'IMAGING' | 'CRITICAL_CARE' | 'SURGICAL';
  vitalFor: string;
}

export const CAPABILITY_CATALOG: CapabilityItem[] = [
  {
    key: 'ct_scan',
    label: 'CT Scan (Computed Tomography)',
    shortDesc: '256-Slice Dual-Source Neuro & Whole-Body CT',
    icon: <Cpu size={16} />,
    category: 'IMAGING',
    vitalFor: 'Head Trauma, Skull Fracture, Intracranial Hemorrhage',
  },
  {
    key: 'mri',
    label: '3.0T MRI Scanner',
    shortDesc: 'High-field neuro-vascular & spinal cord imaging',
    icon: <Radio size={16} />,
    category: 'IMAGING',
    vitalFor: 'Cervical Spine Fracture, Spinal Cord Contusion',
  },
  {
    key: 'neuro_icu',
    label: 'Neuro-ICU & On-Call Neurosurgeon',
    shortDesc: 'Dedicated neurosurgical trauma resuscitation bay',
    icon: <Activity size={16} />,
    category: 'CRITICAL_CARE',
    vitalFor: 'Traumatic Brain Injury, Craniotomy (suggested check for clinician judgment)',
  },
  {
    key: 'blood_bank',
    label: 'Emergency Blood Bank (O-Neg)',
    shortDesc: 'Rapid uncrossed O-Negative & massive transfusion pack',
    icon: <HeartPulse size={16} />,
    category: 'CRITICAL_CARE',
    vitalFor: 'Hemorrhagic Shock, Pelvic Fracture, Spleen/Liver Laceration',
  },
  {
    key: 'ortho_ot',
    label: 'Orthopedic Trauma Surgery OT',
    shortDesc: 'C-Arm fluoroscopy & compound fracture stabilization',
    icon: <Stethoscope size={16} />,
    category: 'SURGICAL',
    vitalFor: 'Compound Limb Fractures, Traumatic Amputation, Pelvic Ring',
  },
  {
    key: 'fast_ultrasound',
    label: 'Ultrasound / FAST Scan Bay',
    shortDesc: 'Focused Assessment with Sonography for Trauma (FAST)',
    icon: <Eye size={16} />,
    category: 'IMAGING',
    vitalFor: 'Hemoperitoneum, Pericardial Tamponade, Pneumothorax',
  },
  {
    key: 'ventilators',
    label: 'ICU Ventilator Bays',
    shortDesc: 'Mechanical lung-protective invasive ventilators',
    icon: <Zap size={16} />,
    category: 'CRITICAL_CARE',
    vitalFor: 'Crushed Chest, Flail Chest, Respiratory Compromise (suggested check for clinician judgment)',
  },
  {
    key: 'general_surgery',
    label: 'General Trauma OT (Laparotomy)',
    shortDesc: 'Emergency damage-control surgical laparotomy suite',
    icon: <Microscope size={16} />,
    category: 'SURGICAL',
    vitalFor: 'Penetrating Torso Trauma, Mesenteric Tear, Ruptured Spleen',
  },
];

export function evaluateTraumaReadiness(
  incident: IncidentPayload,
  capabilities: HospitalCapabilities
): CapabilityMatchResult {
  const metadata = (incident.victim_metadata || {}) as Record<string, unknown>;
  const isRollover = Boolean(metadata.rollover_suspected || metadata.rollover_detected);
  const peakG = typeof metadata.peak_g === 'number'
    ? metadata.peak_g
    : typeof metadata.deceleration_g === 'number'
    ? metadata.deceleration_g
    : 8.0;
  const speedDrop = typeof metadata.speed_drop_kmh === 'number' ? metadata.speed_drop_kmh : 60;
  const isTwoWheeler = Boolean(metadata.is_two_wheeler);
  const isUnresponsive = Boolean(metadata.rider_unresponsive);

  // Check 1: Severe Head Trauma / Traumatic Brain Injury (TBI)
  // Kinematics: Rollover, deceleration >= 7G, two-wheeler impact, or unresponsive rider
  const hasHeadTraumaRisk = isRollover || peakG >= 7.0 || isTwoWheeler || isUnresponsive;

  if (hasHeadTraumaRisk && !capabilities.ct_scan) {
    return {
      hasMismatch: true,
      severity: 'CRITICAL',
      suspectedInjuryTitle: 'Suspected Severe Head Trauma / Traumatic Brain Injury (TBI)',
      suspectedInjuryDescription: isRollover
        ? 'High-angular vehicle rollover and rotational tumbling detected (high probability of closed skull fracture / acute intracranial hematoma).'
        : `Severe deceleration (${peakG.toFixed(1)}G spike, speed drop ${speedDrop} km/h) involving ${isTwoWheeler ? 'Two-Wheeler rider' : 'unresponsive victim'}.`,
      missingEquipmentNames: ['CT Scan (Computed Tomography)'],
      advisoryText:
        'Patient presents acute head trauma risk. Non-contrast head CT is clinically mandatory within the Golden Hour to rule out expanding epidural/subdural hematoma. Your facility has CT Scan marked as OFFLINE.',
      recommendedAction:
        'Divert case to Apex Neuro Trauma Facility (NIMHANS / BMCRI) OR Confirm Acceptance under Emergency Stabilization & Inter-Facility Transfer Protocol.',
    };
  }

  // Check 2: Severe Hemorrhage & Internal Bleeding
  if ((peakG >= 10.0 || speedDrop >= 70) && !capabilities.blood_bank) {
    return {
      hasMismatch: true,
      severity: 'WARNING',
      suspectedInjuryTitle: 'Severe Kinetic Deceleration / Internal Hemorrhage Risk',
      suspectedInjuryDescription: `High-energy deceleration (${peakG.toFixed(1)}G) with elevated risk of liver/splenic laceration or pelvic fracture.`,
      missingEquipmentNames: ['Emergency Blood Bank (O-Negative & Cross-Match)'],
      advisoryText:
        'Polytrauma victim requires immediate uncrossed blood availability. Your Blood Bank is marked OFFLINE or LOW STOCK.',
      recommendedAction:
        'Divert to trauma center with active blood bank OR request immediate blood courier from Red Cross central bank.',
    };
  }

  // Check 3: Spinal Cord Injury & Rollover
  if (isRollover && !capabilities.mri && !capabilities.neuro_icu) {
    return {
      hasMismatch: true,
      severity: 'WARNING',
      suspectedInjuryTitle: 'Suspected Cervical Spine / Spinal Cord Injury',
      suspectedInjuryDescription: 'Vehicle rollover with extreme rotational axial torque on cervical spine.',
      missingEquipmentNames: ['3.0T MRI Scanner', 'Neuro-ICU Specialist'],
      advisoryText:
        'Definitive spinal cord lesion evaluation and decompression requires MRI and neurosurgical capability.',
      recommendedAction:
        'Confirm emergency cervical collar stabilization on arrival before moving patient.',
    };
  }

  // Check 4: Unresponsive / Airway Assessment
  if (isUnresponsive && !capabilities.ventilators) {
    return {
      hasMismatch: true,
      severity: 'WARNING',
      suspectedInjuryTitle: 'Victim Unresponsive / Suggested Airway Check',
      suspectedInjuryDescription: 'Victim unresponsive after impact (unvalidated sensor indicator, not a clinical assessment).',
      missingEquipmentNames: ['ICU Ventilators'],
      advisoryText: 'Patient unresponsive after impact. Suggested checks for clinician judgment regarding airway patency and ventilation support.',
      recommendedAction: 'Verify transport ambulance equipment and alert ED resuscitation team for clinical evaluation.',
    };
  }

  // Fully Matched
  return {
    hasMismatch: false,
    severity: 'MATCHED',
    suspectedInjuryTitle: hasHeadTraumaRisk ? 'Head Injury Protocol Ready' : 'Polytrauma Facility Ready',
    suspectedInjuryDescription: 'Facility possesses all required diagnostic imaging and surgical bays for incoming trauma.',
    missingEquipmentNames: [],
    advisoryText: 'All required trauma capabilities (CT Scan, Blood Bank, Neuro-ICU, Ventilators) are active and operational.',
    recommendedAction: 'Facility is fully prepared to admit and initiate Golden Hour resuscitation.',
  };
}

interface HospitalCapabilityManagerProps {
  hospitalName: string;
  capabilities: HospitalCapabilities;
  onChange: (updated: HospitalCapabilities) => void;
  isExpanded: boolean;
  onToggleExpand: () => void;
}

export const HospitalCapabilityManager: React.FC<HospitalCapabilityManagerProps> = ({
  hospitalName,
  capabilities,
  onChange,
  isExpanded,
  onToggleExpand,
}) => {
  const activeCount = Object.values(capabilities).filter(Boolean).length;
  const totalCount = Object.keys(capabilities).length;

  const handleToggle = (key: keyof HospitalCapabilities) => {
    const updated = {
      ...capabilities,
      [key]: !capabilities[key],
    };
    onChange(updated);
  };

  const handleSimulateCtDown = () => {
    const updated = {
      ...capabilities,
      ct_scan: false,
    };
    onChange(updated);
  };

  const handleResetAll = () => {
    onChange({ ...DEFAULT_HOSPITAL_CAPABILITIES });
  };

  return (
    <div
      style={{
        background: '#ffffff',
        borderRadius: '0.875rem',
        border: '1.5px solid #e2e8f0',
        boxShadow: '0 4px 12px rgba(0, 0, 0, 0.03)',
        marginBottom: '1.25rem',
        overflow: 'hidden',
        transition: 'all 0.2s ease',
      }}
    >
      {/* Header Bar */}
      <div
        style={{
          padding: '0.9rem 1.25rem',
          background: isExpanded ? '#f8fafc' : '#ffffff',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '0.75rem',
          cursor: 'pointer',
          borderBottom: isExpanded ? '1px solid #e2e8f0' : 'none',
        }}
        onClick={onToggleExpand}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div
            style={{
              padding: '0.5rem',
              borderRadius: '0.5rem',
              background: capabilities.ct_scan ? '#ecfdf5' : '#fef2f2',
              color: capabilities.ct_scan ? '#059669' : '#dc2626',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Activity size={20} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
              <span style={{ fontSize: '0.95rem', fontWeight: 800, color: '#0f172a' }}>
                Live Trauma Facility Capabilities & Equipment Readiness
              </span>
              <span style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>
                • {hospitalName}
              </span>
              <span
                style={{
                  background: activeCount === totalCount ? '#dcfce7' : '#fef3c7',
                  color: activeCount === totalCount ? '#15803d' : '#b45309',
                  padding: '0.15rem 0.55rem',
                  borderRadius: '9999px',
                  fontSize: '0.7rem',
                  fontWeight: 800,
                  letterSpacing: '0.03em',
                }}
              >
                {activeCount} / {totalCount} ACTIVE
              </span>
              {!capabilities.ct_scan && (
                <span
                  style={{
                    background: '#fee2e2',
                    color: '#991b1b',
                    padding: '0.15rem 0.55rem',
                    borderRadius: '9999px',
                    fontSize: '0.7rem',
                    fontWeight: 800,
                  }}
                >
                  ⚠️ CT SCAN OFFLINE
                </span>
              )}
            </div>
            <div style={{ fontSize: '0.75rem', color: '#64748b', marginTop: '0.15rem' }}>
              Checked capabilities are automatically cross-referenced against incoming crash injuries (e.g. Head Trauma vs CT Scanner).
            </div>
          </div>
        </div>

        {/* Quick Action Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }} onClick={(e) => e.stopPropagation()}>
          {!capabilities.ct_scan ? (
            <button
              type="button"
              onClick={handleResetAll}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.35rem 0.75rem',
                fontSize: '0.75rem',
                fontWeight: 700,
                borderRadius: '0.375rem',
                background: '#ecfdf5',
                color: '#059669',
                border: '1px solid #a7f3d0',
                cursor: 'pointer',
              }}
            >
              <CheckCircle2 size={13} />
              Restore All Equipment
            </button>
          ) : (
            <button
              type="button"
              onClick={handleSimulateCtDown}
              title="Test the automated head injury mismatch alert by taking CT Scan offline"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.35rem 0.75rem',
                fontSize: '0.75rem',
                fontWeight: 700,
                borderRadius: '0.375rem',
                background: '#fef2f2',
                color: '#dc2626',
                border: '1px solid #fecaca',
                cursor: 'pointer',
              }}
            >
              <Wrench size={13} />
              [SIMULATED] Simulate CT Scan Down
            </button>
          )}

          <button
            type="button"
            onClick={onToggleExpand}
            style={{
              padding: '0.35rem 0.7rem',
              fontSize: '0.75rem',
              fontWeight: 700,
              borderRadius: '0.375rem',
              background: '#f1f5f9',
              color: '#334155',
              border: '1px solid #cbd5e1',
              cursor: 'pointer',
            }}
          >
            {isExpanded ? 'Hide Checklist ▲' : 'Manage Checkbox Capabilities ▼'}
          </button>
        </div>
      </div>

      {/* Expandable Capabilities Checklist Grid */}
      {isExpanded && (
        <div style={{ padding: '1.25rem', background: '#ffffff' }}>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
              gap: '0.85rem',
            }}
          >
            {CAPABILITY_CATALOG.map((item) => {
              const isChecked = Boolean(capabilities[item.key]);
              return (
                <label
                  key={item.key}
                  style={{
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: '0.75rem',
                    padding: '0.85rem',
                    borderRadius: '0.625rem',
                    border: `1.5px solid ${isChecked ? '#86efac' : '#fca5a5'}`,
                    background: isChecked ? '#f0fdf4' : '#fff5f5',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={isChecked}
                    onChange={() => handleToggle(item.key)}
                    style={{
                      width: '18px',
                      height: '18px',
                      marginTop: '0.15rem',
                      cursor: 'pointer',
                      accentColor: '#16a34a',
                    }}
                  />
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.5rem' }}>
                      <span
                        style={{
                          fontSize: '0.85rem',
                          fontWeight: 800,
                          color: isChecked ? '#166534' : '#991b1b',
                        }}
                      >
                        {item.label}
                      </span>
                      <span
                        style={{
                          fontSize: '0.65rem',
                          fontWeight: 800,
                          padding: '0.1rem 0.4rem',
                          borderRadius: '0.25rem',
                          background: isChecked ? '#dcfce7' : '#fee2e2',
                          color: isChecked ? '#15803d' : '#b91c1c',
                        }}
                      >
                        {isChecked ? 'ONLINE' : 'OFFLINE'}
                      </span>
                    </div>
                    <div style={{ fontSize: '0.725rem', color: '#64748b', marginTop: '0.2rem' }}>
                      {item.shortDesc}
                    </div>
                    <div
                      style={{
                        fontSize: '0.675rem',
                        fontWeight: 700,
                        color: isChecked ? '#047857' : '#b91c1c',
                        marginTop: '0.35rem',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.3rem',
                      }}
                    >
                      <Zap size={10} /> Vital For: {item.vitalFor}
                    </div>
                  </div>
                </label>
              );
            })}
          </div>

          <div
            style={{
              marginTop: '1rem',
              padding: '0.75rem 1rem',
              background: '#f8fafc',
              borderRadius: '0.5rem',
              border: '1px solid #e2e8f0',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              fontSize: '0.75rem',
              color: '#475569',
              flexWrap: 'wrap',
              gap: '0.5rem',
            }}
          >
            <span>
              💡 <strong>Smart AI Triage Rule:</strong> If an incoming patient suffers a <strong>Head Injury / TBI</strong> while <strong>CT Scan</strong> is unchecked, Rakshak-AI automatically triggers an intelligent clinical mismatch warning with diversion recommendations.
            </span>
            <button
              type="button"
              onClick={handleResetAll}
              style={{
                background: 'transparent',
                border: 'none',
                color: '#2563eb',
                fontWeight: 700,
                cursor: 'pointer',
                textDecoration: 'underline',
              }}
            >
              Reset to Operational
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
