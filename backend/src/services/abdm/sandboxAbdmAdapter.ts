import crypto from 'crypto';
import {
  IAbdmClient,
  AbdmProfile,
  AbdmHealthRecordsResult,
  AbdmVerifyStartResult,
  AbdmVerifyConfirmResult,
} from './abdmClient';
import { AbdmMode } from '../../types';

interface SandboxTxn {
  abhaAddress: string;
  gatewayTxnId: string;
  expiresAt: number;
}

interface SandboxSession {
  profile: AbdmProfile;
  records: AbdmHealthRecordsResult;
  userToken: string;
  expiresAt: number;
}

export class SandboxAbdmAdapter implements IAbdmClient {
  private gatewayBaseUrl = process.env.ABDM_GATEWAY_URL || 'https://dev.abdm.gov.in/api/hiecm/gateway/v3';
  private phrBaseUrl = process.env.ABDM_BASE_URL || 'https://abhasbx.abdm.gov.in/abha/api/v3/phr/web';
  private clientId = process.env.ABDM_CLIENT_ID || '';
  private clientSecret = process.env.ABDM_CLIENT_SECRET || '';

  private cachedGatewayToken: string | null = null;
  private gatewayTokenExpiresAt = 0;

  private txns = new Map<string, SandboxTxn>();
  private sessions = new Map<string, SandboxSession>();

  getMode(): AbdmMode {
    return 'sandbox';
  }

  /**
   * Acquires or reuses a Gateway session token using client credentials.
   * Tokens are held only in short-lived memory and never logged.
   */
  private async getGatewaySessionToken(): Promise<string> {
    if (this.cachedGatewayToken && Date.now() < this.gatewayTokenExpiresAt - 60000) {
      return this.cachedGatewayToken;
    }

    if (!this.clientId || !this.clientSecret) {
      throw new Error('ABDM_CLIENT_ID or ABDM_CLIENT_SECRET not configured');
    }

    const res = await fetch(`${this.gatewayBaseUrl}/sessions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'REQUEST-ID': crypto.randomUUID(),
        TIMESTAMP: new Date().toISOString(),
      },
      body: JSON.stringify({
        clientId: this.clientId,
        clientSecret: this.clientSecret,
        grantType: 'client_credentials',
      }),
    });

    if (!res.ok) {
      throw new Error(`ABDM Gateway session acquisition failed: HTTP ${res.status}`);
    }

    const data = (await res.json()) as { accessToken?: string; token?: string; expiresIn?: number };
    const token = data.accessToken || data.token;
    if (!token) {
      throw new Error('No access token returned from ABDM Gateway');
    }

    this.cachedGatewayToken = token;
    const expiresIn = data.expiresIn || 1200;
    this.gatewayTokenExpiresAt = Date.now() + expiresIn * 1000;
    return token;
  }

  async startVerification(abhaAddress: string): Promise<AbdmVerifyStartResult> {
    try {
      const cleanAddress = abhaAddress.trim().toLowerCase();
      const gatewayToken = await this.getGatewaySessionToken();

      const res = await fetch(`${this.phrBaseUrl}/login/abha/request/otp`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'REQUEST-ID': crypto.randomUUID(),
          TIMESTAMP: new Date().toISOString(),
          Authorization: `Bearer ${gatewayToken}`,
          'X-CM-ID': 'sbx',
        },
        body: JSON.stringify({
          scope: ['abha-address-login', 'mobile-verify'],
          loginHint: 'abha-address',
          loginId: cleanAddress,
          otpSystem: 'abdm',
        }),
      });

      if (res.status === 404) {
        return {
          status: 'NOT_FOUND',
          message: 'ABHA address not found in ABDM sandbox registry',
        };
      }

      if (!res.ok) {
        const errorText = await res.text().catch(() => '');
        if (res.status === 400 && errorText.includes('not found')) {
          return {
            status: 'NOT_FOUND',
            message: 'ABHA address not found in ABDM sandbox registry',
          };
        }
        return {
          status: 'ABDM_UNAVAILABLE',
          message: `ABDM sandbox responded with error status ${res.status}`,
        };
      }

      const data = (await res.json()) as { txnId?: string; transactionId?: string };
      const gatewayTxnId = data.txnId || data.transactionId;
      if (!gatewayTxnId) {
        return {
          status: 'ABDM_UNAVAILABLE',
          message: 'Malformed response from ABDM: missing transaction identifier',
        };
      }

      const internalTxnId = `sbx-txn-${crypto.randomUUID()}`;
      this.txns.set(internalTxnId, {
        abhaAddress: cleanAddress,
        gatewayTxnId,
        expiresAt: Date.now() + 10 * 60 * 1000,
      });

      return {
        status: 'OTP_SENT',
        txnId: internalTxnId,
        message: 'OTP dispatched via ABDM sandbox gateway',
      };
    } catch (err: unknown) {
      console.warn('[SandboxAbdmAdapter] ABDM Gateway request error:', (err as Error).message);
      return {
        status: 'ABDM_UNAVAILABLE',
        message: 'Unable to connect to ABDM sandbox gateway. Please check network connectivity or try again later.',
      };
    }
  }

  async confirmVerification(txnId: string, otp: string): Promise<AbdmVerifyConfirmResult> {
    try {
      const txn = this.txns.get(txnId);
      if (!txn || txn.expiresAt < Date.now()) {
        return {
          status: 'OTP_FAILED',
          message: 'Verification session expired. Please request a new OTP.',
        };
      }

      const gatewayToken = await this.getGatewaySessionToken();

      const verifyRes = await fetch(`${this.phrBaseUrl}/login/abha/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'REQUEST-ID': crypto.randomUUID(),
          TIMESTAMP: new Date().toISOString(),
          Authorization: `Bearer ${gatewayToken}`,
          'X-CM-ID': 'sbx',
        },
        body: JSON.stringify({
          txnId: txn.gatewayTxnId,
          otp: otp.trim(),
        }),
      });

      if (verifyRes.status === 400 || verifyRes.status === 401) {
        return {
          status: 'OTP_FAILED',
          message: 'Invalid OTP provided. Please check and retry.',
        };
      }

      if (!verifyRes.ok) {
        return {
          status: 'ABDM_UNAVAILABLE',
          message: `ABDM sandbox verify failed with HTTP ${verifyRes.status}`,
        };
      }

      const verifyData = (await verifyRes.json()) as { token?: string; 'x-token'?: string };
      const userToken = verifyData['x-token'] || verifyData.token;
      if (!userToken) {
        return {
          status: 'ABDM_UNAVAILABLE',
          message: 'No user session token returned after OTP confirmation',
        };
      }

      // Fetch user profile from sandbox using user token
      const profileRes = await fetch(`${this.phrBaseUrl}/profile`, {
        method: 'GET',
        headers: {
          'REQUEST-ID': crypto.randomUUID(),
          TIMESTAMP: new Date().toISOString(),
          Authorization: `Bearer ${gatewayToken}`,
          'X-token': `Bearer ${userToken}`,
          'X-CM-ID': 'sbx',
        },
      });

      let profile: AbdmProfile;
      if (profileRes.ok) {
        const rawProfile = (await profileRes.json()) as Record<string, unknown>;
        profile = {
          name: (rawProfile.firstName ? `${rawProfile.firstName} ${rawProfile.lastName || ''}`.trim() : rawProfile.name as string) || 'ABDM User',
          gender: (rawProfile.gender as string) || 'Unspecified',
          dateOfBirth: (rawProfile.dateOfBirth || rawProfile.dob) as string | undefined,
          abhaAddress: (rawProfile.abhaAddress || txn.abhaAddress) as string,
          abhaNumber: (rawProfile.abhaNumber as string) || undefined,
          mobile: rawProfile.mobile ? `XXXXXX${String(rawProfile.mobile).slice(-4)}` : undefined,
        };
      } else {
        // Fallback to basic verified info from login
        profile = {
          name: 'ABDM Verified Citizen',
          gender: 'Unspecified',
          abhaAddress: txn.abhaAddress,
        };
      }

      // Clean up used txn
      this.txns.delete(txnId);

      // Attempt consent-based record fetch:
      // In the ABDM sandbox, automated emergency consent artefacts require prior HIP/HIU bridge registration
      // which is unavailable without registered hospital endpoints. We report RECORDS_UNAVAILABLE honestly.
      const records: AbdmHealthRecordsResult = {
        status: 'RECORDS_UNAVAILABLE',
        reason: 'ABDM sandbox consent artefact / FHIR record flow not provisioned for emergency bypass; health records unavailable',
      };

      const sessionToken = `session-${crypto.randomUUID()}`;
      this.sessions.set(sessionToken, {
        profile,
        records,
        userToken,
        expiresAt: Date.now() + 15 * 60 * 1000,
      });

      return {
        status: 'VERIFIED',
        sessionToken,
        profile,
        records,
        message: 'ABHA address successfully verified in sandbox',
      };
    } catch (err: unknown) {
      console.warn('[SandboxAbdmAdapter] Error during OTP confirmation:', (err as Error).message);
      return {
        status: 'ABDM_UNAVAILABLE',
        message: 'Network error communicating with ABDM sandbox gateway.',
      };
    }
  }

  async getProfile(sessionToken: string): Promise<{
    status: 'VERIFIED' | 'NOT_LINKED' | 'ABDM_UNAVAILABLE';
    profile?: AbdmProfile;
    records?: AbdmHealthRecordsResult;
    message?: string;
  }> {
    const session = this.sessions.get(sessionToken);
    if (!session || session.expiresAt < Date.now()) {
      return {
        status: 'NOT_LINKED',
        message: 'No active verified ABHA session found',
      };
    }

    return {
      status: 'VERIFIED',
      profile: session.profile,
      records: session.records,
    };
  }

  async unlink(sessionToken: string): Promise<{ status: 'NOT_LINKED'; message: string }> {
    this.sessions.delete(sessionToken);
    return {
      status: 'NOT_LINKED',
      message: 'ABHA linking successfully removed and session purged',
    };
  }
}
