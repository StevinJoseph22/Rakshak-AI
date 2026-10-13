import 'package:flutter/material.dart';
import '../services/traffic_signal_service.dart';
import '../services/vehicle_obu_service.dart';

/// Interactive C-V2X Hardware Hub & Packet Diagnostics Modal
/// Allows toggling between Simulated OBU and Physical Hardware (USB/BLE/C-V2X)
class Cv2xHardwareHubDialog extends StatefulWidget {
  const Cv2xHardwareHubDialog({super.key});

  @override
  State<Cv2xHardwareHubDialog> createState() => _Cv2xHardwareHubDialogState();
}

class _Cv2xHardwareHubDialogState extends State<Cv2xHardwareHubDialog> {
  final _obuService = VehicleObuService.instance;
  final _signalService = TrafficSignalService.instance;

  @override
  Widget build(BuildContext context) {
    final activeSignals = _signalService.activeSignals;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFF0F172A), // Dark slate aerospace theme
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                  ),
                  child: const Icon(Icons.settings_input_antenna, color: Color(0xFF38BDF8), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'C-V2X / V2I HARDWARE HUB',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'SAE J2735 & NTCIP-1202 Hardware Abstraction Layer',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 24),

            // Hardware Connection Mode Selector
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OBU HARDWARE INTERFACE MODE:',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF065F46),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HARDWARE READY',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ObuConnectionMode>(
                    value: _obuService.connectionMode,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ObuConnectionMode.simulatedSoftware,
                        child: Text('🟢 Simulated Software Engine (No hardware needed)'),
                      ),
                      DropdownMenuItem(
                        value: ObuConnectionMode.serialUsbOtG,
                        child: Text('🔌 USB-OTG Serial OBU (Commsignia / Quectel AG15)'),
                      ),
                      DropdownMenuItem(
                        value: ObuConnectionMode.bluetoothBle,
                        child: Text('📡 Bluetooth Low Energy (Rakshak BLE Beacon)'),
                      ),
                      DropdownMenuItem(
                        value: ObuConnectionMode.directCv2xPc5,
                        child: Text('⚡ Qualcomm 9150 C-V2X Direct PC5 Transceiver'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        setState(() {
                          _obuService.setConnectionMode(mode);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Active Driver: ${_obuService.hardwareDeviceName}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Siren / Beacon Arming Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _obuService.sirenActive ? const Color(0xFF14532D) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _obuService.sirenActive ? const Color(0xFF22C55E) : const Color(0xFF475569),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: _obuService.sirenActive ? const Color(0xFF4ADE80) : Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EMERGENCY SIREN & BEACON SENSOR',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            _obuService.sirenActive
                                ? 'Armed: Automatic C-V2X signal preemption ENABLED'
                                : 'Standby: Preemption disarmed (Non-emergency mode)',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: _obuService.sirenActive ? const Color(0xFF86EFAC) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: _obuService.sirenActive,
                    activeThumbColor: const Color(0xFF22C55E),
                    onChanged: (val) {
                      setState(() {
                        _obuService.toggleSiren(val);
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Detected Real-World Signals Along Route
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DETECTED MUNICIPAL SIGNALS (${activeSignals.length}):',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
                Text(
                  'Source: OpenStreetMap + BTP ITMS',
                  style: TextStyle(fontSize: 9.5, color: Colors.teal.shade300),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: activeSignals.isEmpty
                ? const Center(
                    child: Text(
                      'No signal nodes on active route yet. Compute a route first.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    itemCount: activeSignals.length,
                    itemBuilder: (ctx, idx) {
                      final sig = activeSignals[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.traffic,
                              size: 16,
                              color: sig.isPreempted ? const Color(0xFF22C55E) : Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sig.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${sig.controllerId} • ${sig.distanceMeters.toStringAsFixed(0)}m away',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: sig.isPreempted ? const Color(0xFF065F46) : const Color(0xFF7F1D1D),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sig.isPreempted ? 'PREEMPTED 🟢' : 'NORMAL RED 🔴',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: sig.isPreempted ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 12),

            // Live SAE J2735 Packet Stream Inspector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LIVE SAE J2735 PACKET LOG (BSM / SRM / SSM):',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _obuService.clearLogs();
                    });
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  child: const Text('Clear', style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8))),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF030712),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: StreamBuilder<List<String>>(
                  stream: _obuService.packetLogStream,
                  initialData: _obuService.cv2xPacketLog,
                  builder: (ctx, snapshot) {
                    final logs = snapshot.data ?? [];
                    if (logs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Waiting for vehicle telemetry & preemption requests...',
                          style: TextStyle(color: Color(0xFF4B5563), fontSize: 10, fontFamily: 'monospace'),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        final isOut = log.contains('OUT');
                        final isIn = log.contains('IN');
                        final color = isOut
                            ? const Color(0xFF38BDF8)
                            : (isIn ? const Color(0xFF4ADE80) : const Color(0xFF9CA3AF));
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            log,
                            style: TextStyle(fontSize: 9.5, color: color, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
