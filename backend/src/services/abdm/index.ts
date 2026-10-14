import { IAbdmClient } from './abdmClient';
import { MockAbdmAdapter } from './mockAbdmAdapter';
import { SandboxAbdmAdapter } from './sandboxAbdmAdapter';
import { AbdmMode } from '../../types';

let currentClient: IAbdmClient | null = null;
let forcedMode: AbdmMode | null = null;

export function getAbdmMode(): AbdmMode {
  if (forcedMode) return forcedMode;
  const envMode = process.env.ABDM_MODE?.toLowerCase();
  return envMode === 'sandbox' ? 'sandbox' : 'mock';
}

export function setAbdmMode(mode: AbdmMode | null): void {
  forcedMode = mode;
  currentClient = null; // Reset cached client instance
}

export function getAbdmClient(): IAbdmClient {
  const mode = getAbdmMode();
  if (currentClient && currentClient.getMode() === mode) {
    return currentClient;
  }

  if (mode === 'sandbox') {
    currentClient = new SandboxAbdmAdapter();
  } else {
    currentClient = new MockAbdmAdapter();
  }

  return currentClient;
}

export * from './abdmClient';
export * from './mockAbdmAdapter';
export * from './sandboxAbdmAdapter';
