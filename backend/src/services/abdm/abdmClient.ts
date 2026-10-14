import { AbdmMode } from '../../types';

export interface AbdmProfile {
  abhaNumber?: string;
  abhaAddress: string;
  name: string;
  gender: string;
  dateOfBirth?: string;
  age?: number;
  mobile?: string;
}

export interface AbdmHealthRecordsResult {
  status: 'AVAILABLE' | 'RECORDS_UNAVAILABLE';
  reason?: string;
  blood_group?: string;
  allergies?: string[];
  chronic_conditions?: string[];
  current_medications?: string[];
  organ_donor_status?: string;
}

export interface AbdmVerifyStartResult {
  status: 'OTP_SENT' | 'NOT_FOUND' | 'ABDM_UNAVAILABLE';
  txnId?: string;
  message: string;
}

export interface AbdmVerifyConfirmResult {
  status: 'VERIFIED' | 'OTP_FAILED' | 'ABDM_UNAVAILABLE';
  sessionToken?: string;
  profile?: AbdmProfile;
  records?: AbdmHealthRecordsResult;
  message: string;
}

export interface IAbdmClient {
  getMode(): AbdmMode;
  startVerification(abhaAddress: string): Promise<AbdmVerifyStartResult>;
  confirmVerification(txnId: string, otp: string): Promise<AbdmVerifyConfirmResult>;
  getProfile(sessionToken: string): Promise<{
    status: 'VERIFIED' | 'NOT_LINKED' | 'ABDM_UNAVAILABLE';
    profile?: AbdmProfile;
    records?: AbdmHealthRecordsResult;
    message?: string;
  }>;
  unlink(sessionToken: string): Promise<{ status: 'NOT_LINKED'; message: string }>;
}
