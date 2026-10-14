import crypto from 'crypto';
import {
  IAbdmClient,
  AbdmProfile,
  AbdmHealthRecordsResult,
  AbdmVerifyStartResult,
  AbdmVerifyConfirmResult,
} from './abdmClient';
import { AbdmMode } from '../../types';

interface MockTxn {
  abhaAddress: string;
  scenario: 'full' | 'no_records' | 'consent_denied' | 'wrong_otp' | 'timeout' | 'not_found';
  expiresAt: number;
}

interface MockSession {
  profile: AbdmProfile;
  records: AbdmHealthRecordsResult;
  expiresAt: number;
}

export class MockAbdmAdapter implements IAbdmClient {
  private txns = new Map<string, MockTxn>();
  private sessions = new Map<string, MockSession>();

  getMode(): AbdmMode {
    return 'mock';
  }

  private detectScenario(address: string): MockTxn['scenario'] {
    const lower = address.toLowerCase();
    if (lower.includes('timeout')) return 'timeout';
    if (lower.includes('notfound') || lower.includes('not_found') || lower.includes('nonexistent')) return 'not_found';
    if (lower.includes('wrongotp') || lower.includes('wrong_otp')) return 'wrong_otp';
    if (lower.includes('denied') || lower.includes('consent_denied')) return 'consent_denied';
    if (lower.includes('norecords') || lower.includes('no_records') || lower.includes('priya') || lower.includes('rohit')) return 'no_records';
    return 'full';
  }

  async startVerification(abhaAddress: string): Promise<AbdmVerifyStartResult> {
    const cleanAddress = abhaAddress.trim().toLowerCase();
    const scenario = this.detectScenario(cleanAddress);

    if (scenario === 'timeout') {
      return {
        status: 'ABDM_UNAVAILABLE',
        message: 'ABDM Gateway request timed out. Please retry later.',
      };
    }

    if (scenario === 'not_found') {
      return {
        status: 'NOT_FOUND',
        message: 'ABHA address not found in ABDM registry',
      };
    }

    const txnId = `mock-txn-${crypto.randomUUID()}`;
    this.txns.set(txnId, {
      abhaAddress: cleanAddress,
      scenario,
      expiresAt: Date.now() + 10 * 60 * 1000, // 10 minutes TTL
    });

    return {
      status: 'OTP_SENT',
      txnId,
      message: 'OTP sent to mobile number registered with ABHA',
    };
  }

  async confirmVerification(txnId: string, otp: string): Promise<AbdmVerifyConfirmResult> {
    const txn = this.txns.get(txnId);
    if (!txn || txn.expiresAt < Date.now()) {
      return {
        status: 'OTP_FAILED',
        message: 'Transaction expired or invalid. Please initiate a new verification.',
      };
    }

    // Deterministic scenario check
    if (txn.scenario === 'wrong_otp' || otp.trim() !== '123456') {
      return {
        status: 'OTP_FAILED',
        message: 'Invalid OTP provided. Please retry.',
      };
    }

    // Success: remove txn
    this.txns.delete(txnId);

    // Build profile and health records according to scenario
    let profile: AbdmProfile;
    let records: AbdmHealthRecordsResult;

    if (txn.scenario === 'no_records') {
      profile = {
        name: 'Priya Patel',
        gender: 'Female',
        dateOfBirth: '1995-08-22',
        age: 31,
        abhaAddress: txn.abhaAddress,
        abhaNumber: '91-5512-4411-9023',
        mobile: 'XXXXXX4321',
      };
      records = {
        status: 'RECORDS_UNAVAILABLE',
        reason: 'No health records linked in ABDM repository',
      };
    } else if (txn.scenario === 'consent_denied') {
      profile = {
        name: 'Rohan Verma',
        gender: 'Male',
        dateOfBirth: '1989-11-14',
        age: 36,
        abhaAddress: txn.abhaAddress,
        abhaNumber: '91-7731-8822-1194',
        mobile: 'XXXXXX8812',
      };
      records = {
        status: 'RECORDS_UNAVAILABLE',
        reason: 'Patient denied consent for health record access',
      };
    } else {
      // 'full' scenario (default / Aarav Sharma persona)
      profile = {
        name: 'Aarav Sharma',
        gender: 'Male',
        dateOfBirth: '1998-05-14',
        age: 28,
        abhaAddress: txn.abhaAddress,
        abhaNumber: '91-8842-9912-3401',
        mobile: 'XXXXXX1234',
      };
      records = {
        status: 'AVAILABLE',
        blood_group: 'B+ Positive',
        allergies: ['Penicillin Anaphylaxis', 'Sulfa Drugs'],
        chronic_conditions: ['Type-1 Diabetes'],
        current_medications: ['Warfarin (Blood Thinner - Severe Hemorrhage Risk)', 'Insulin Glargine'],
        organ_donor_status: 'Registered NOTTO Donor (ID: NOTTO-IND-2024-88419)',
      };
    }

    const sessionToken = `session-${crypto.randomUUID()}`;
    this.sessions.set(sessionToken, {
      profile,
      records,
      expiresAt: Date.now() + 15 * 60 * 1000, // 15 minutes TTL
    });

    return {
      status: 'VERIFIED',
      sessionToken,
      profile,
      records,
      message: 'ABHA address successfully verified',
    };
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
