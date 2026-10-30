import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Model representing an official Indian Emergency Helpline.
class EmergencyServiceInfo {
  final String id;
  final String name;
  final String number;
  final String category;
  final String authority;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color badgeBgColor;
  final bool isNationalPriority;

  const EmergencyServiceInfo({
    required this.id,
    required this.name,
    required this.number,
    required this.category,
    required this.authority,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.badgeBgColor,
    this.isNationalPriority = false,
  });
}

class IndiaEmergencyDirectoryScreen extends StatefulWidget {
  const IndiaEmergencyDirectoryScreen({super.key});

  @override
  State<IndiaEmergencyDirectoryScreen> createState() => _IndiaEmergencyDirectoryScreenState();
}

class _IndiaEmergencyDirectoryScreenState extends State<IndiaEmergencyDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  static const List<String> _categories = [
    'All',
    '🚨 Critical',
    '🛣️ Highway & Rail',
    '🛡️ Women & Child',
    '🌊 Disaster',
    '🏥 Medical & Poison',
    '🔒 Cyber & Elders',
  ];

  static const List<EmergencyServiceInfo> _services = [
    // CRITICAL / ALL-IN-ONE
    EmergencyServiceInfo(
      id: '112',
      name: 'National Emergency Helpline (ERSS)',
      number: '112',
      category: '🚨 Critical',
      authority: 'Ministry of Home Affairs (MHA), Govt. of India',
      description: 'Single emergency pan-India number integrating Police, Fire, Ambulance, and Disaster response services.',
      icon: Icons.emergency_rounded,
      primaryColor: Color(0xFFEF4444),
      badgeBgColor: Color(0xFF3B1010),
      isNationalPriority: true,
    ),
    EmergencyServiceInfo(
      id: '108',
      name: 'Emergency Medical & Ambulance (EMS)',
      number: '108',
      category: '🚨 Critical',
      authority: 'National Health Mission (NHM) & State Govts',
      description: 'Free 24/7 emergency medical trauma transport, ALS/BLS life-support ambulances for accident victims.',
      icon: Icons.local_hospital_rounded,
      primaryColor: Color(0xFFF97316),
      badgeBgColor: Color(0xFF3B1F0B),
      isNationalPriority: true,
    ),
    EmergencyServiceInfo(
      id: '102',
      name: 'Janani Shishu Suraksha (Maternity & Infant)',
      number: '102',
      category: '🚨 Critical',
      authority: 'Ministry of Health and Family Welfare (MoHFW)',
      description: 'Free ambulance service for pregnant mothers, neonatal emergencies, and infants in distress.',
      icon: Icons.child_care_rounded,
      primaryColor: Color(0xFFF59E0B),
      badgeBgColor: Color(0xFF382305),
    ),
    EmergencyServiceInfo(
      id: '100',
      name: 'Police Control Room (PCR)',
      number: '100',
      category: '🚨 Critical',
      authority: 'State Police Departments & Commissionerates',
      description: 'Immediate law enforcement response, crime reporting, public safety intervention, and highway patrolling.',
      icon: Icons.local_police_rounded,
      primaryColor: Color(0xFF3B82F6),
      badgeBgColor: Color(0xFF0F2547),
      isNationalPriority: true,
    ),
    EmergencyServiceInfo(
      id: '101',
      name: 'Fire & Rescue Services',
      number: '101',
      category: '🚨 Critical',
      authority: 'State Directorate of Fire & Emergency Services',
      description: 'Fire containment, structural collapse, gas leak hazard control, industrial rescue, and vehicle entrapment extraction.',
      icon: Icons.local_fire_department_rounded,
      primaryColor: Color(0xFFF43F5E),
      badgeBgColor: Color(0xFF380E18),
    ),

    // HIGHWAY & RAILWAY
    EmergencyServiceInfo(
      id: '1073',
      name: 'National Highway Emergency (NHAI)',
      number: '1073',
      category: '🛣️ Highway & Rail',
      authority: 'National Highways Authority of India (NHAI)',
      description: '24/7 expressway/highway accident recovery, route clearance, breakdown towing, and rapid road ambulances.',
      icon: Icons.alt_route_rounded,
      primaryColor: Color(0xFF14B8A6),
      badgeBgColor: Color(0xFF052E2B),
      isNationalPriority: true,
    ),
    EmergencyServiceInfo(
      id: '139',
      name: 'Rail Madad - Railway Emergency & Security',
      number: '139',
      category: '🛣️ Highway & Rail',
      authority: 'Indian Railways (Ministry of Railways)',
      description: 'Single integrated helpline for train medical emergencies, railway accident response, and passenger security.',
      icon: Icons.train_rounded,
      primaryColor: Color(0xFF6366F1),
      badgeBgColor: Color(0xFF181B4E),
    ),
    EmergencyServiceInfo(
      id: '1072',
      name: 'Railway Accident Emergency',
      number: '1072',
      category: '🛣️ Highway & Rail',
      authority: 'Railway Safety Commissionerate',
      description: 'Immediate dispatch and casualty coordination during major railway derailments and collisions.',
      icon: Icons.dangerous_rounded,
      primaryColor: Color(0xFF8B5CF6),
      badgeBgColor: Color(0xFF23144D),
    ),

    // WOMEN & CHILD SAFETY
    EmergencyServiceInfo(
      id: '1091',
      name: 'Women Helpline (Crime & Distress)',
      number: '1091',
      category: '🛡️ Women & Child',
      authority: 'State Police Departments & Women Safety Cell',
      description: 'Emergency rescue for women facing violence, stalking, domestic abuse, harassment, or transit distress.',
      icon: Icons.security_rounded,
      primaryColor: Color(0xFFEC4899),
      badgeBgColor: Color(0xFF3B0D23),
      isNationalPriority: true,
    ),
    EmergencyServiceInfo(
      id: '181',
      name: 'National Women Helpline (WCD)',
      number: '181',
      category: '🛡️ Women & Child',
      authority: 'Ministry of Women and Child Development',
      description: '24/7 toll-free crisis management, trauma counseling, shelter referral, and legal aid for women in distress.',
      icon: Icons.support_agent_rounded,
      primaryColor: Color(0xFFD946EF),
      badgeBgColor: Color(0xFF370E3D),
    ),
    EmergencyServiceInfo(
      id: '1098',
      name: 'Childline India (Child Protection)',
      number: '1098',
      category: '🛡️ Women & Child',
      authority: 'Childline India Foundation & MoWCD',
      description: '24/7 emergency care and rescue service for missing children, child labor, abuse, and abandoned minors.',
      icon: Icons.escalator_warning_rounded,
      primaryColor: Color(0xFF06B6D4),
      badgeBgColor: Color(0xFF052B33),
      isNationalPriority: true,
    ),
    EmergencyServiceInfo(
      id: '1094',
      name: 'Missing Children & Women Bureau',
      number: '1094',
      category: '🛡️ Women & Child',
      authority: 'Crime Branch / Missing Persons Squad',
      description: 'Specialized central tracking and immediate broadcast for missing vulnerable persons and runaway minors.',
      icon: Icons.person_search_rounded,
      primaryColor: Color(0xFF818CF8),
      badgeBgColor: Color(0xFF1A1D4E),
    ),

    // DISASTER & RESCUE
    EmergencyServiceInfo(
      id: '1070',
      name: 'State Disaster Management Authority (SDMA)',
      number: '1070',
      category: '🌊 Disaster',
      authority: 'State Disaster Control Room / NDMA',
      description: 'High-alert emergency command for floods, cyclones, landslides, cloudbursts, and earthquake disasters.',
      icon: Icons.flood_rounded,
      primaryColor: Color(0xFF0EA5E9),
      badgeBgColor: Color(0xFF062B3D),
    ),
    EmergencyServiceInfo(
      id: '1077',
      name: 'District Disaster Control Room (DDMA)',
      number: '1077',
      category: '🌊 Disaster',
      authority: 'District Collectorate / Magistrate Office',
      description: 'Ground-level district emergency relief, search and rescue coordination, and localized civic crisis.',
      icon: Icons.domain_rounded,
      primaryColor: Color(0xFF10B981),
      badgeBgColor: Color(0xFF063323),
    ),
    EmergencyServiceInfo(
      id: '1078',
      name: 'National Disaster Response Force (NDRF)',
      number: '1078',
      category: '🌊 Disaster',
      authority: 'NDRF HQ / Ministry of Home Affairs',
      description: 'Specialized multi-hazard disaster intervention, CBRN (chemical/biological) threats, and flood boat rescues.',
      icon: Icons.waves_rounded,
      primaryColor: Color(0xFF059669),
      badgeBgColor: Color(0xFF04291D),
    ),

    // MEDICAL, MENTAL HEALTH & POISON
    EmergencyServiceInfo(
      id: '14416',
      name: 'Tele-MANAS (Mental Health & Crisis)',
      number: '14416',
      category: '🏥 Medical & Poison',
      authority: 'Ministry of Health and Family Welfare (MoHFW)',
      description: '24/7 confidential psychological support, crisis counseling, and immediate suicide prevention intervention.',
      icon: Icons.psychology_rounded,
      primaryColor: Color(0xFFA855F7),
      badgeBgColor: Color(0xFF28113D),
      isNationalPriority: true,
    ),
    EmergencyServiceInfo(
      id: '1066',
      name: 'National Poison Information Centre (AIIMS)',
      number: '1066',
      category: '🏥 Medical & Poison',
      authority: 'AIIMS New Delhi / Dept. of Pharmacology',
      description: '24/7 emergency medical guidance for toxic substance ingestion, snake venom bites, pesticide, and chemical exposure.',
      icon: Icons.biotech_rounded,
      primaryColor: Color(0xFFEF4444),
      badgeBgColor: Color(0xFF3B1010),
    ),
    EmergencyServiceInfo(
      id: '1075',
      name: 'National Health Emergency (MoHFW)',
      number: '1075',
      category: '🏥 Medical & Poison',
      authority: 'Ministry of Health and Family Welfare',
      description: 'Central reporting helpline for communicable disease outbreaks, public health hazards, and biological alerts.',
      icon: Icons.medical_services_rounded,
      primaryColor: Color(0xFF38BDF8),
      badgeBgColor: Color(0xFF072B3D),
    ),

    // CYBER CRIME & SENIOR CITIZENS
    EmergencyServiceInfo(
      id: '1930',
      name: 'National Cyber Crime & Financial Fraud',
      number: '1930',
      category: '🔒 Cyber & Elders',
      authority: 'Indian Cyber Crime Coordination Centre (I4C)',
      description: 'Golden hour freeze on unauthorized bank transfers, UPI cyber scams, identity theft, and extortion.',
      icon: Icons.lock_clock_rounded,
      primaryColor: Color(0xFFF59E0B),
      badgeBgColor: Color(0xFF382305),
      isNationalPriority: true,
    ),
    EmergencyServiceInfo(
      id: '14567',
      name: 'Elderline - Senior Citizen Helpline',
      number: '14567',
      category: '🔒 Cyber & Elders',
      authority: 'Ministry of Social Justice and Empowerment',
      description: 'Rescue for abandoned or abused elderly citizens, emergency shelter, legal aid, and emotional support.',
      icon: Icons.elderly_rounded,
      primaryColor: Color(0xFF94A3B8),
      badgeBgColor: Color(0xFF1E293B),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(EmergencyServiceInfo service) async {
    final String cleanNumber = service.number.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri callUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      debugPrint('[EmergencyDirectory] Dialing ${service.name} ($cleanNumber)...');
      final bool launched = await launchUrl(
        callUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(callUri);
      }
    } catch (e) {
      debugPrint('[EmergencyDirectory] Dial error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unable to launch dialer for ${service.name} ($cleanNumber). Number copied to clipboard.',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
        Clipboard.setData(ClipboardData(text: cleanNumber));
      }
    }
  }

  void _copyNumber(EmergencyServiceInfo service) {
    Clipboard.setData(ClipboardData(text: service.number));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Copied ${service.name} (${service.number}) to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  List<EmergencyServiceInfo> get _filteredServices {
    return _services.where((service) {
      final matchesCategory = _selectedCategory == 'All' || service.category == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return matchesCategory;

      final matchesSearch = service.name.toLowerCase().contains(query) ||
          service.number.toLowerCase().contains(query) ||
          service.authority.toLowerCase().contains(query) ||
          service.description.toLowerCase().contains(query) ||
          service.category.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredServices;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF090D16),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'India Emergency Directory',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Direct 1-Tap Calling • 24/7 Toll-Free Hotlines',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. NATIONAL EMERGENCY HEROCARD (112 ONE-TAP DIAL)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFF991B1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'GOVT OF INDIA • ERSS 112',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.flash_on, color: Colors.amberAccent, size: 14),
                        SizedBox(width: 2),
                        Text(
                          'IMMEDIATE DISPATCH',
                          style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_forwarded_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DIAL 112 NATIONAL SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Police • Fire • Ambulance • Disaster',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final primary = _services.firstWhere((s) => s.id == '112');
                        _makeCall(primary);
                      },
                      icon: const Icon(Icons.call, size: 16, color: Color(0xFFDC2626)),
                      label: const Text(
                        'CALL 112',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFDC2626)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. SEARCH & FILTER BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search service, number, or keyword (e.g. 108, Police, Poison)...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1F2937)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1F2937)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, idx) {
                      final cat = _categories[idx];
                      final isSelected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFEF4444),
                        backgroundColor: const Color(0xFF111827),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF1F2937),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. SERVICE HELPLINE LIST VIEW
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 44, color: Color(0xFF475569)),
                        const SizedBox(height: 12),
                        Text(
                          'No emergency services found for "$_searchQuery"',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try searching for "Ambulance", "112", or "Police"',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final item = filtered[index];
                      return _buildServiceCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(EmergencyServiceInfo item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isNationalPriority ? item.primaryColor.withOpacity(0.4) : const Color(0xFF1F2937),
          width: item.isNationalPriority ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Icon + Name + Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: item.badgeBgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: item.primaryColor.withOpacity(0.3)),
                    ),
                    child: Icon(item.icon, color: item.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (item.isNationalPriority) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.primaryColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: item.primaryColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  'PRIORITY',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: item.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.authority,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                item.description,
                style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.3),
              ),
              const SizedBox(height: 10),

              // Divider
              const Divider(height: 1, color: Color(0xFF1F2937)),
              const SizedBox(height: 10),

              // Footer Action Row: Big Number Badge + Direct Call Button
              Row(
                children: [
                  // Phone Number Pill
                  InkWell(
                    onTap: () => _copyNumber(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dialpad, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text(
                            item.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 11, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 10, color: Color(0xFF34D399)),
                        SizedBox(width: 3),
                        Text(
                          '24/7 Toll-Free',
                          style: TextStyle(fontSize: 9.5, color: Color(0xFF34D399), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Immediate Dial Button
                  ElevatedButton.icon(
                    onPressed: () => _makeCall(item),
                    icon: const Icon(Icons.phone, size: 14, color: Colors.white),
                    label: Text(
                      'Call ${item.number}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
