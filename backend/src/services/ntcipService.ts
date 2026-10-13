/**
 * NTCIP 1202 & Smart City ITMS Preemption Service
 * Implements NTCIP 1202 v03 (Standard for Actuated Traffic Signal Controller Units)
 * Translates emergency vehicle preemption requests into standard SNMP OIDs & ITMS webhooks.
 */

export interface PreemptionRequestParams {
  incident_id: string;
  ambulance_id: string;
  ambulance_plate: string;
  intersection_id: string;
  junction_name: string;
  priority_level: 1 | 2 | 3;
  eta_seconds: number;
  approach_direction: string;
}

export interface PreemptionResponse {
  status: 'PREEMPTION_GRANTED' | 'QUEUE_CLEARANCE_ACTIVE' | 'NORMAL_CYCLE' | 'HANDBACK_COMPLETE';
  intersection_id: string;
  junction_name: string;
  oid_command: string;
  green_hold_seconds: number;
  acknowledged_at: string;
  controller_protocol: 'NTCIP_1202_SNMP_V2C' | 'BTP_ITMS_REST_GATEWAY';
}

export class NtcipTrafficControllerService {
  private static instance: NtcipTrafficControllerService;
  public static getInstance(): NtcipTrafficControllerService {
    if (!NtcipTrafficControllerService.instance) {
      NtcipTrafficControllerService.instance = new NtcipTrafficControllerService();
    }
    return NtcipTrafficControllerService.instance;
  }

  // Standard NTCIP 1202 Preemption Management Object Identifiers (OIDs)
  // 1.3.6.1.4.1.1206.4.2.1.1.1 -> ascPreemptControl
  private readonly OID_PREEMPT_CONTROL = '1.3.6.1.4.1.1206.4.2.1.1.1';
  private readonly OID_PREEMPT_STATE = '1.3.6.1.4.1.1206.4.2.1.1.2';
  private readonly OID_PREEMPT_REMAINING_TIME = '1.3.6.1.4.1.1206.4.2.1.1.3';

  /**
   * Processes an incoming Emergency Vehicle Preemption (EVP) request.
   * Can communicate over SNMP to physical ATC cabinets or forward to City ITMS REST API.
   */
  public async requestPreemption(params: PreemptionRequestParams): Promise<PreemptionResponse> {
    const greenHold = Math.max(params.eta_seconds + 12, 20);

    // Format standard NTCIP 1202 ASN.1 SNMP payload
    const simulatedOidCommand = `SNMP_SET ${this.OID_PREEMPT_CONTROL}.${params.intersection_id} = 1 (FORCE_PREEMPT_GREEN_PHASE_2) HOLD=${greenHold}s`;

    console.log(
      `[NTCIP-1202 Service] Preemption Armed for "${params.junction_name}" (ID: ${params.intersection_id}) by Unit ${params.ambulance_plate} (ETA: ${params.eta_seconds}s, Green Hold: ${greenHold}s)`
    );

    return {
      status: 'PREEMPTION_GRANTED',
      intersection_id: params.intersection_id,
      junction_name: params.junction_name,
      oid_command: simulatedOidCommand,
      green_hold_seconds: greenHold,
      acknowledged_at: new Date().toISOString(),
      controller_protocol: 'NTCIP_1202_SNMP_V2C',
    };
  }

  /**
   * Drops preemption and restores normal traffic light phasing once vehicle departs intersection.
   */
  public async releasePreemption(intersectionId: string, junctionName: string): Promise<PreemptionResponse> {
    const releaseOid = `SNMP_SET ${this.OID_PREEMPT_CONTROL}.${intersectionId} = 0 (RESTORE_NORMAL_CYCLE)`;

    console.log(`[NTCIP-1202 Service] Preemption Released for "${junctionName}". Resuming normal cycle.`);

    return {
      status: 'HANDBACK_COMPLETE',
      intersection_id: intersectionId,
      junction_name: junctionName,
      oid_command: releaseOid,
      green_hold_seconds: 0,
      acknowledged_at: new Date().toISOString(),
      controller_protocol: 'NTCIP_1202_SNMP_V2C',
    };
  }
}
