import React from 'react';
import { WifiOff, Loader2 } from 'lucide-react';
import { ConnectionStatus } from '../types';

interface ReconnectingBannerProps {
  status: ConnectionStatus;
  onRetry?: () => void;
}

export const ReconnectingBanner: React.FC<ReconnectingBannerProps> = ({
  status,
  onRetry,
}) => {
  if (status === 'connected') {
    return null;
  }

  const isReconnecting = status === 'reconnecting';

  return (
    <div
      role="alert"
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0.75rem 1.25rem',
        marginBottom: '1.5rem',
        borderRadius: '0.5rem',
        background: isReconnecting ? '#fffbeb' : '#fef2f2',
        border: `1px solid ${isReconnecting ? '#fcd34d' : '#fca5a5'}`,
        color: isReconnecting ? '#92400e' : '#991b1b',
        boxShadow: '0 2px 4px rgba(0,0,0,0.05)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
        {isReconnecting ? (
          <Loader2
            size={20}
            style={{
              animation: 'spin 1s linear infinite',
            }}
          />
        ) : (
          <WifiOff size={20} />
        )}
        <div>
          <span style={{ fontWeight: 600 }}>
            {isReconnecting
              ? 'Reconnecting to Emergency Dispatch Server...'
              : 'Disconnected from Emergency Network'}
          </span>
          <p style={{ margin: 0, fontSize: '0.825rem', opacity: 0.9 }}>
            {isReconnecting
              ? 'Attempting to re-establish live WebSocket stream with Rakshak-AI backend.'
              : 'Connection lost. Live telemetry and incoming trauma alerts are currently paused.'}
          </p>
        </div>
      </div>
      {onRetry && (
        <button
          onClick={onRetry}
          style={{
            padding: '0.4rem 0.85rem',
            background: isReconnecting ? '#f59e0b' : '#ef4444',
            color: '#ffffff',
            border: 'none',
            borderRadius: '0.375rem',
            fontSize: '0.8rem',
            fontWeight: 600,
            cursor: 'pointer',
          }}
        >
          Reconnect Now
        </button>
      )}
    </div>
  );
};
