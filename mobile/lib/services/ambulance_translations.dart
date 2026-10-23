/// Multi-language localization service for the Rakshak-AI Ambulance Pilot & Paramedic Cockpit.
/// Supports 7 major Indian languages tailored for quick, low-cognitive-load emergency operations:
/// - English (en)
/// - Hindi (hi - हिन्दी)
/// - Kannada (kn - ಕನ್ನಡ) [Primary Karnataka/Bengaluru hub]
/// - Tamil (ta - தமிழ்)
/// - Telugu (te - తెలుగు)
/// - Malayalam (ml - മലയാളം)
/// - Marathi (mr - मराठी)
class AmbulanceTranslations {
  AmbulanceTranslations._();

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी'},
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'RAKSHAK ResQ PILOT',
      'cockpit_sub': 'EMS Tactical Cockpit',
      'citizen_app': 'Citizen App',
      // Statuses
      'status_available': 'DISPATCH READY',
      'status_en_route': 'EN ROUTE TO SCENE',
      'status_on_scene': 'ON SCENE',
      'status_transporting': 'IN TRANSIT TO HOSPITAL',
      'status_standby': 'STANDBY',
      'auto_sync': 'AUTOMATIC EMS SYNC',
      'c_v2x_banner': '5.9 GHz DSRC Online • Dynamic Green Corridor Armed',
      'c_v2x_spec': 'SAE J2735 / NTCIP 1202',
      // Tabs
      'tab_radar': 'Dispatch Radar',
      'tab_trauma': 'Trauma Bays',
      'tab_tools': 'Paramedic Tools',
      // Radar Header
      'gps_radar': 'GPS RADAR',
      'in_range': 'IN RANGE',
      'active_incidents': 'ACTIVE INCIDENTS IN DISPATCH RADIUS',
      'radius': 'Radius',
      // Card details
      'critical_severity': 'CRITICAL SEVERITY',
      'high_priority': 'HIGH PRIORITY',
      'away': 'away',
      'est_time': 'Est.',
      'min': 'min',
      'victim': 'VICTIM',
      'blood_group': 'BLOOD GROUP',
      'peak_impact': 'PEAK IMPACT',
      'coordinates': 'Coordinates',
      'claim_btn': 'CLAIM & ENGAGE C-V2X GREEN CORRIDOR',
      // Trauma Bays
      'trauma_title': 'LEVEL-1 TRAUMA HUBS • DIRECT PARAMEDIC HOTLINES',
      'dial_trauma': 'Dial Trauma Bay',
      'call_connecting': 'Trauma Hotline Initialized: Dialing',
      // Paramedic Tools
      'tools_title': 'RAPID RESPONSE PARAMEDIC SUITE',
      'abha_decryptor': 'ABHA Medical Vault Decryptor',
      'abha_desc': 'Instantly extract verified victim blood group, critical anaphylaxis drug allergies, and chronic medical history under Ayushman Bharat Digital Mission (ABDM).',
      'abha_btn': 'Decrypt Patient ABHA Record',
      'signal_force': 'C-V2X Green Corridor Signal Force',
      'signal_force_desc': 'Transmits emergency preemption requests (SRM) to next 3 municipal traffic controllers to lock solid green phases along vehicle vector.',
      'signal_force_btn': 'FORCE PREEMPT NEXT SIGNALS (GREEN WAVE)',
      'vitals_streamer': 'Live Pre-Arrival Vitals Streamer',
      'vitals_desc': 'Synchronizes real-time patient heart rate, blood pressure, SpO2, and Glasgow Coma Scale directly with receiving trauma surgeons.',
      // Language Selector
      'change_language': 'Language / भाषा / ಭಾಷೆ',
      'select_language': 'Select Ambulance Pilot Language',
      'active_language': 'Active Language',
      'close': 'Close',
      // Demo / Simulator
      'sim_title': 'Paramedic Simulation Injector (Demo Mode)',
      'sim_desc': 'Allows evaluators to simulate claiming and executing real-world emergency missions even when no physical crash is broadcasting.',
      'sim_btn_1': 'Simulate Silk Board Rollover',
      'sim_btn_2': 'Simulate Highway Watchdog',
    },
    'hi': {
      'app_title': 'RAKSHAK ResQ PILOT',
      'cockpit_sub': 'ईएमएस सामरिक कॉकपिट',
      'citizen_app': 'नागरिक ऐप',
      // Statuses
      'status_available': 'तैनात / तैयार',
      'status_en_route': 'घटना स्थल की ओर',
      'status_on_scene': 'घटना स्थल पर उपस्थित',
      'status_transporting': 'अस्पताल की ओर रवाना',
      'status_standby': 'प्रतीक्षा में',
      'auto_sync': 'स्वचालित ईएमएस सिंक',
      'c_v2x_banner': '5.9 GHz DSRC Online • स्वचालित ग्रीन कॉरिडोर सक्रिय',
      'c_v2x_spec': 'SAE J2735 / NTCIP 1202',
      // Tabs
      'tab_radar': 'डिस्पैच रडार',
      'tab_trauma': 'ट्रॉमा अस्पताल',
      'tab_tools': 'पैरामेडिक टूल्स',
      // Radar Header
      'gps_radar': 'जीपीएस रडार',
      'in_range': 'सीमा में',
      'active_incidents': 'आसपास की सक्रिय आपातकालीन घटनाएं',
      'radius': 'त्रिज्या',
      // Card details
      'critical_severity': '🚨 गंभीर आपातकाल',
      'high_priority': '⚠️ उच्च प्राथमिकता',
      'away': 'दूर',
      'est_time': 'अनुमानित',
      'min': 'मिनट',
      'victim': 'पीड़ित (मरीज़)',
      'blood_group': 'रक्त समूह',
      'peak_impact': 'प्रभाव तीव्रता',
      'coordinates': 'स्थान निर्देशांक',
      'claim_btn': 'स्वीकारें और ग्रीन कॉरिडोर शुरू करें',
      // Trauma Bays
      'trauma_title': 'लेवल-1 ट्रॉमा अस्पताल • आपातकालीन हॉटलाइन',
      'dial_trauma': 'ट्रॉमा सेंटर को कॉल करें',
      'call_connecting': 'ट्रॉमा हॉटलाइन जोड़ी जा रही है: कॉल',
      // Paramedic Tools
      'tools_title': 'त्वरित प्रतिक्रिया पैरामेडिक सुइट',
      'abha_decryptor': 'आभा मेडिकल रिकॉर्ड डिक्रिप्टर',
      'abha_desc': 'आयुष्मान भारत डिजिटल मिशन (ABDM) के तहत मरीज़ का ब्लड ग्रुप, एलर्जी और मेडिकल रिकॉर्ड तुरंत प्राप्त करें।',
      'abha_btn': 'मरीज़ का आभा रिकॉर्ड देखें',
      'signal_force': 'C-V2X ग्रीन कॉरिडोर सिग्नल प्रीएम्प्शन',
      'signal_force_desc': 'एम्बुलेंस के रास्ते के अगले 3 ट्रैफिक सिग्नलों को तुरंत ग्रीन करने का सिग्नल भेजें।',
      'signal_force_btn': 'अगले सिग्नल ग्रीन करें (ग्रीन वेव)',
      'vitals_streamer': 'लाइव विटल्स टेलीमेट्री स्ट्रीमर',
      'vitals_desc': 'मरीज़ का हार्ट रेट, ब्लड प्रेशर और ऑक्सीजन सीधे अस्पताल के डॉक्टरों को लाइव भेजें।',
      // Language Selector
      'change_language': 'भाषा / Language',
      'select_language': 'पायलट भाषा चुनें',
      'active_language': 'सक्रिय भाषा',
      'close': 'बंद करें',
      // Demo / Simulator
      'sim_title': 'पैरामेडिक सिमुलेटर (डेमो मोड)',
      'sim_desc': 'डेमो और परीक्षण के लिए आपातकालीन मिशन का सिमुलेशन करें।',
      'sim_btn_1': 'सिल्क बोर्ड दुर्घटना सिमुलेट करें',
      'sim_btn_2': 'हाईवे वॉचडॉग सिमुलेट करें',
    },
    'kn': {
      'app_title': 'RAKSHAK ResQ PILOT',
      'cockpit_sub': 'ಇಎಂಎಸ್ ತುರ್ತು ಕಾಕ್‌ಪಿಟ್',
      'citizen_app': 'ನಾಗರಿಕ ಆ್ಯಪ್',
      // Statuses
      'status_available': 'ನಿಯೋಜನೆಗೆ ಸಿದ್ಧ',
      'status_en_route': 'ಸ್ಥಳಕ್ಕೆ ತೆರಳಲಾಗುತ್ತಿದೆ',
      'status_on_scene': 'ಘಟನಾ ಸ್ಥಳದಲ್ಲಿದ್ದಾರೆ',
      'status_transporting': 'ಆಸ್ಪತ್ರೆಗೆ ಕರೆದೊಯ್ಯಲಾಗುತ್ತಿದೆ',
      'status_standby': 'ಸಿದ್ಧತೆಯಲ್ಲಿದೆ',
      'auto_sync': 'ಸ್ವಯಂಚಾಲಿತ ಇಎಂಎಸ್ ಸಿಂಕ್',
      'c_v2x_banner': '5.9 GHz DSRC Online • ಡೈನಾಮಿಕ್ ಗ್ರೀನ್ ಕಾರಿಡಾರ್ ಸಕ್ರಿಯ',
      'c_v2x_spec': 'SAE J2735 / NTCIP 1202',
      // Tabs
      'tab_radar': 'ಡಿಸ್ಪ್ಯಾಚ್ ರಾಡಾರ್',
      'tab_trauma': 'ಟ್ರಾಮಾ ಆಸ್ಪತ್ರೆಗಳು',
      'tab_tools': 'ಪ್ಯಾರಾಮೆಡಿಕ್ ಪರಿಕರಗಳು',
      // Radar Header
      'gps_radar': 'ಜಿಪಿಎಸ್ ರಾಡಾರ್',
      'in_range': 'ವ್ಯಾಪ್ತಿಯಲ್ಲಿ',
      'active_incidents': 'ವ್ಯಾಪ್ತಿಯಲ್ಲಿರುವ ಸಕ್ರಿಯ ಅಪಘಾತ ತುರ್ತುಸ್ಥಿತಿಗಳು',
      'radius': 'ವ್ಯಾಪ್ತಿ',
      // Card details
      'critical_severity': '🚨 ತೀವ್ರ ತುರ್ತುಸ್ಥಿತಿ',
      'high_priority': '⚠️ ಹೆಚ್ಚಿನ ಆದ್ಯತೆ',
      'away': 'ದೂರ',
      'est_time': 'ಅಂದಾಜು',
      'min': 'ನಿಮಿಷ',
      'victim': 'ಸಂತ್ರಸ್ತ (ರೋಗಿ)',
      'blood_group': 'ರಕ್ತದ ಗುಂಪು',
      'peak_impact': 'ಅಪ್ಪಳಿಸುವಿಕೆಯ ತೀವ್ರತೆ',
      'coordinates': 'ನಿರ್ದೇಶಾಂಕಗಳು',
      'claim_btn': 'ಸ್ವೀಕರಿಸಿ & ಗ್ರೀನ್ ಕಾರಿಡಾರ್ ಸಕ್ರಿಯಗೊಳಿಸಿ',
      // Trauma Bays
      'trauma_title': 'ಲೆವೆಲ್-1 ಟ್ರಾಮಾ ಆಸ್ಪತ್ರೆಗಳು • ನೇರ ಹಾಟ್‌ಲೈನ್',
      'dial_trauma': 'ಟ್ರಾಮಾ ವಿಭಾಗಕ್ಕೆ ಕರೆ ಮಾಡಿ',
      'call_connecting': 'ಟ್ರಾಮಾ ಹಾಟ್‌ಲೈನ್‌ಗೆ ಕರೆ ಮಾಡಲಾಗುತ್ತಿದೆ: ',
      // Paramedic Tools
      'tools_title': 'ತ್ವರಿತ ಪ್ರತಿಕ್ರಿಯೆ ಪ್ಯಾರಾಮೆಡಿಕ್ ಸೂಟ್',
      'abha_decryptor': 'ಆಭಾ ಮೆಡಿಕಲ್ ವಾಲ್ಟ್ ಡಿಕ್ರಿಪ್ಟರ್',
      'abha_desc': 'ಆಯುಷ್ಮಾನ್ ಭಾರತ್ ಡಿಜಿಟಲ್ ಮಿಷನ್ ಮೂಲಕ ರೋಗಿಯ ರಕ್ತದ ಗುಂಪು ಮತ್ತು ಅಲೆರ್ಜಿ ವಿವರಗಳನ್ನು ತಕ್ಷಣ ಪರಿಶೀಲಿಸಿ.',
      'abha_btn': 'ರೋಗಿಯ ಆಭಾ ದಾಖಲೆ ಪರಿಶೀಲಿಸಿ',
      'signal_force': 'C-V2X ಸಿಗ್ನಲ್ ಗ್ರೀನ್ ಕಾರಿಡಾರ್',
      'signal_force_desc': 'ಆಂಬ್ಯುಲೆನ್ಸ್‌ಗೆ ದಾರಿ ಮಾಡಿಕೊಡಲು ಮುಂದಿನ 3 ಟ್ರಾಫಿಕ್ ಸಿಗ್ನಲ್‌ಗಳನ್ನು ತಕ್ಷಣ ಗ್ರೀನ್ ಮಾಡಿ.',
      'signal_force_btn': 'ಮುಂದಿನ ಸಿಗ್ನಲ್ ಗ್ರೀನ್ ಮಾಡಿ (ಗ್ರೀನ್ ವೇವ್)',
      'vitals_streamer': 'ಲೈವ್ ಜೀವಚಿಹ್ನೆಗಳ ಸ್ಟ್ರೀಮರ್',
      'vitals_desc': 'ಹೃದಯ ಬಡಿತ ಮತ್ತು ರಕ್ತದೊತ್ತಡವನ್ನು ಆಸ್ಪತ್ರೆ ವೈದ್ಯರಿಗೆ ಲೈವ್ ಆಗಿ ರವಾನಿಸಿ.',
      // Language Selector
      'change_language': 'ಭಾಷೆ / Language',
      'select_language': 'ಆಂಬ್ಯುಲೆನ್ಸ್ ಪೈಲಟ್ ಭಾಷೆ ಆಯ್ಕೆಮಾಡಿ',
      'active_language': 'ಸಕ್ರಿಯ ಭಾಷೆ',
      'close': 'ಮುಚ್ಚಿ',
      // Demo / Simulator
      'sim_title': 'ಪ್ಯಾರಾಮೆಡಿಕ್ ಸಿಮ್ಯುಲೇಶನ್ (ಡೆಮೋ ಮೋಡ್)',
      'sim_desc': 'ಪರೀಕ್ಷೆಗಾಗಿ ತುರ್ತು ಘಟನೆಯನ್ನು ಸಿಮ್ಯುಲೇಟ್ ಮಾಡಿ.',
      'sim_btn_1': 'ಸಿಲ್ಕ್ ಬೋರ್ಡ್ ಅಪಘಾತ ಸಿಮ್ಯುಲೇಟ್',
      'sim_btn_2': 'ಹೈವೇ ವಾಚ್‌ಡಾಗ್ ಸಿಮ್ಯುಲೇಟ್',
    },
    'ta': {
      'app_title': 'RAKSHAK ResQ PILOT',
      'cockpit_sub': 'இஎம்எஸ் அவசர காக்பிட்',
      'citizen_app': 'பொதுமக்கள் செயலி',
      // Statuses
      'status_available': 'பணிக்கு தயார்',
      'status_en_route': 'விபத்து இடத்திற்கு செல்கிறது',
      'status_on_scene': 'விபத்து இடத்தில் உள்ளார்',
      'status_transporting': 'மருத்துவமனைக்கு செல்கிறது',
      'status_standby': 'காத்திருப்பில்',
      'auto_sync': 'தானியங்கி இஎம்எஸ் ஒத்திசைவு',
      'c_v2x_banner': '5.9 GHz DSRC Online • கிரீன் காரிடார் இயக்கத்தில் உள்ளது',
      'c_v2x_spec': 'SAE J2735 / NTCIP 1202',
      // Tabs
      'tab_radar': 'டிஸ்பாட்ச் ரேடார்',
      'tab_trauma': 'அவசர சிகிச்சை மையங்கள்',
      'tab_tools': 'பராமரிப்பு கருவிகள்',
      // Radar Header
      'gps_radar': 'ஜிபிஎஸ் ரேடார்',
      'in_range': 'எல்லைக்குள்',
      'active_incidents': 'எல்லைக்குள் உள்ள அவசர சம்பவங்கள்',
      'radius': 'ஆரம்',
      // Card details
      'critical_severity': '🚨 தீவிர அவசரநிலை',
      'high_priority': '⚠️ முன்னுரிமை',
      'away': 'தொலைவில்',
      'est_time': 'மதிப்பீடு',
      'min': 'நிமிடம்',
      'victim': 'பாதிக்கப்பட்டவர்',
      'blood_group': 'இரத்த வகை',
      'peak_impact': 'தாக்க அளவு',
      'coordinates': 'இருப்பிடம்',
      'claim_btn': 'ஏற்றுக்கொள் & கிரீன் காரிடார் தொடங்கு',
      // Trauma Bays
      'trauma_title': 'லெவல்-1 அவசர சிகிச்சை மையங்கள் • நேரடி ஹாட்லைன்',
      'dial_trauma': 'மருத்துவமனைக்கு அழைக்கவும்',
      'call_connecting': 'அவசர அழைப்பு இணைக்கப்படுகிறது: ',
      // Paramedic Tools
      'tools_title': 'விரைவு அவசர சிகிச்சை பிரிவு',
      'abha_decryptor': 'ஆபா மருத்துவ பெட்டகம்',
      'abha_desc': 'ஆயுஷ்மான் பாரத் மூலம் நோயாளியின் இரத்த வகை மற்றும் மருந்து ஒவ்வாமை விவரங்களைப் பெறுக.',
      'abha_btn': 'நோயாளி ஆபா தகவலைப் பெறுக',
      'signal_force': 'C-V2X சிக்னல் முன்கூட்டியே மாற்றுதல்',
      'signal_force_desc': 'அடுத்து வரும் 3 போக்குவரத்து சிக்னல்களை உடனடியாக பச்சையாக மாற்றவும்.',
      'signal_force_btn': 'சிக்னல்களை பச்சையாக்கு (கிரீன் வேவ்)',
      'vitals_streamer': 'நேரடி நோயாளி கண்காணிப்பு',
      'vitals_desc': 'இதய துடிப்பு மற்றும் இரத்த அழுத்தத்தை மருத்துவர்களுக்கு நேரடியாக அனுப்பவும்.',
      // Language Selector
      'change_language': 'மொழி / Language',
      'select_language': 'பைலட் மொழியைத் தேர்ந்தெடுக்கவும்',
      'active_language': 'தற்போதைய மொழி',
      'close': 'மூடு',
      // Demo / Simulator
      'sim_title': 'மாதிரி பரிசோதனை (டெமோ)',
      'sim_desc': 'மாதிரி அவசர சம்பவங்களை சோதிக்க.',
      'sim_btn_1': 'சில்க் போர்டு விபத்து மாதிரி',
      'sim_btn_2': 'நெடுஞ்சாலை விபத்து மாதிரி',
    },
    'te': {
      'app_title': 'RAKSHAK ResQ PILOT',
      'cockpit_sub': 'ఈఎంఎస్ ఎమర్జెన్సీ కాక్‌పిట్',
      'citizen_app': 'సిటిజన్ యాప్',
      // Statuses
      'status_available': 'విధికి సిద్ధం',
      'status_en_route': 'సంఘటన స్థలానికి వెళ్తున్నారు',
      'status_on_scene': 'ఘటనా స్థలంలో ఉన్నారు',
      'status_transporting': 'ఆసుపత్రికి తరలిస్తున్నారు',
      'status_standby': 'సిద్ధంగా ఉన్నారు',
      'auto_sync': 'ఆటోమేటిక్ ఈఎంఎస్ సింక్',
      'c_v2x_banner': '5.9 GHz DSRC Online • గ్రీన్ కారిడార్ సిద్ధంగా ఉంది',
      'c_v2x_spec': 'SAE J2735 / NTCIP 1202',
      // Tabs
      'tab_radar': 'డిస్పాచ్ రాడార్',
      'tab_trauma': 'ట్రామా ఆసుపత్రులు',
      'tab_tools': 'పారామెడిక్ టూల్స్',
      // Radar Header
      'gps_radar': 'జీపీఎస్ రాడార్',
      'in_range': 'పరిధిలో',
      'active_incidents': 'పరిధిలోని అత్యవసర సంఘటనలు',
      'radius': 'పరిధి',
      // Card details
      'critical_severity': '🚨 తీవ్ర అత్యవసరం',
      'high_priority': '⚠️ అధిక ప్రాధాన్యత',
      'away': 'దూరంలో',
      'est_time': 'అంచనా',
      'min': 'నిమిషాలు',
      'victim': 'బాధితుడు',
      'blood_group': 'రక్త వర్గం',
      'peak_impact': 'ప్రభావ తీవ్రత',
      'coordinates': 'కోఆర్డినేట్లు',
      'claim_btn': 'స్వీకరించండి & గ్రీన్ కారిడార్ ప్రారంభించండి',
      // Trauma Bays
      'trauma_title': 'లెవల్-1 ట్రామా ఆసుపత్రులు • హాట్‌లైన్',
      'dial_trauma': 'ట్రామా విభాగానికి కాల్ చేయండి',
      'call_connecting': 'కాల్ కలుపుతున్నారు: ',
      // Paramedic Tools
      'tools_title': 'త్వరిత అత్యవసర సేవా విభాగం',
      'abha_decryptor': 'ఆభా మెడికల్ వాల్ట్ డీక్రిప్టర్',
      'abha_desc': 'ఆయుష్మాన్ భారత్ ద్వారా బాధితుడి రక్త వర్గం మరియు ఆరోగ్య వివరాలను పొందండి.',
      'abha_btn': 'ఆభా రికార్డును పరిశీలించండి',
      'signal_force': 'C-V2X సిగ్నల్ క్లియరెన్స్',
      'signal_force_desc': 'అంబులెన్స్ ప్రయాణ మార్గంలోని తదుపరి 3 ట్రాఫిక్ సిగ్నల్స్‌ను గ్రీన్‌గా మార్చండి.',
      'signal_force_btn': 'సిగ్నల్స్ గ్రీన్ చేయండి (గ్రీన్ వేవ్)',
      'vitals_streamer': 'ప్రత్యక్ష ఆరోగ్య కొలతల ప్రసారం',
      'vitals_desc': 'హార్ట్ రేట్ మరియు బీపీని నేరుగా ఆసుపత్రి డాక్టర్లకు ప్రసారం చేయండి.',
      // Language Selector
      'change_language': 'భాష / Language',
      'select_language': 'భాషను ఎంచుకోండి',
      'active_language': 'ప్రస్తుత భాష',
      'close': 'మూసివేయి',
      // Demo / Simulator
      'sim_title': 'డెమో సిమ్యులేటర్',
      'sim_desc': 'అత్యవసర సంఘటనలను పరీక్షించండి.',
      'sim_btn_1': 'సిల్క్ బోర్డ్ ప్రమాదం సిమ్యులేట్',
      'sim_btn_2': 'హైవే వాచ్‌డాగ్ సిమ్యులేట్',
    },
    'ml': {
      'app_title': 'RAKSHAK ResQ PILOT',
      'cockpit_sub': 'ഇഎംഎസ് എമർജൻസി കോക്പിറ്റ്',
      'citizen_app': 'സിറ്റിസൻ ആപ്പ്',
      // Statuses
      'status_available': 'സജ്ജമാണ്',
      'status_en_route': 'സ്ഥലത്തേക്ക് പോകുന്നു',
      'status_on_scene': 'സ്ഥലത്തെത്തി',
      'status_transporting': 'ആശുപത്രിയിലേക്ക് പോകുന്നു',
      'status_standby': 'സ്റ്റാൻഡ്‌ബൈ',
      'auto_sync': 'ഓട്ടോമാറ്റിക് ഇഎംഎസ് സിങ്ക്',
      'c_v2x_banner': '5.9 GHz DSRC Online • ഗ്രീൻ കോറിഡോർ പ്രവർത്തനക്ഷമമാണ്',
      'c_v2x_spec': 'SAE J2735 / NTCIP 1202',
      // Tabs
      'tab_radar': 'ഡിസ്പാച്ച് റഡാർ',
      'tab_trauma': 'ട്രോമ സെന്ററുകൾ',
      'tab_tools': 'പാരാമെഡിക് ടൂളുകൾ',
      // Radar Header
      'gps_radar': 'ജിപിഎസ് റഡാർ',
      'in_range': 'പരിധിയിൽ',
      'active_incidents': 'പരിധിയിലെ അടിയന്തിര സംഭവങ്ങൾ',
      'radius': 'പരിധി',
      // Card details
      'critical_severity': '🚨 ഗുരുതര അടിയന്തരാവസ്ഥ',
      'high_priority': '⚠️ ഉയർന്ന മുൻഗണന',
      'away': 'അകലെ',
      'est_time': 'ഏകദേശം',
      'min': 'മിനിറ്റ്',
      'victim': 'രോഗി / ഇര',
      'blood_group': 'രക്തഗ്രൂപ്പ്',
      'peak_impact': 'ആഘാത തീവ്രത',
      'coordinates': 'സ്ഥാനം',
      'claim_btn': 'സ്വീകരിക്കുക & ഗ്രീൻ കോറിഡോർ ആരംഭിക്കുക',
      // Trauma Bays
      'trauma_title': 'ലെവൽ-1 ട്രോമ സെന്ററുകൾ • നേരിട്ടുള്ള ഹോട്ട്‌ലൈൻ',
      'dial_trauma': 'ട്രോമ സെന്ററിലേക്ക് വിളിക്കുക',
      'call_connecting': 'ഹോട്ട്‌ലൈനിലേക്ക് ബന്ധിപ്പിക്കുന്നു: ',
      // Paramedic Tools
      'tools_title': 'ദ്രുത പ്രതികരണ പാരാമെഡിക് സ്യൂട്ട്',
      'abha_decryptor': 'ആഭാ മെഡിക്കൽ റെക്കോർഡ്',
      'abha_desc': 'ആയുഷ്മാൻ ഭാരത് വഴി രോഗിയുടെ രക്തഗ്രൂപ്പും അലർജി വിവരങ്ങളും ഉടൻ പരിശോധിക്കുക.',
      'abha_btn': 'ആഭാ റെക്കോർഡ് പരിശോധിക്കുക',
      'signal_force': 'C-V2X സിഗ്നൽ പ്രീഎംപ്ഷൻ',
      'signal_force_desc': 'ആംബുലൻസിനായി അടുത്ത 3 ട്രാഫിക് സിഗ്നലുകൾ പച്ചയാക്കുക.',
      'signal_force_btn': 'സിഗ്നലുകൾ പച്ചയാക്കുക (ഗ്രീൻ വേവ്)',
      'vitals_streamer': 'തത്സമയ വിവര കൈമാറ്റം',
      'vitals_desc': 'രോഗിയുടെ ഹൃദയമിടിപ്പും രക്തസമ്മർദ്ദവും ഡോക്ടർമാർക്ക് തത്സമയം നൽകുക.',
      // Language Selector
      'change_language': 'ഭാഷ / Language',
      'select_language': 'പൈലറ്റ് ഭാഷ തിരഞ്ഞെടുക്കുക',
      'active_language': 'നിലവിലെ ഭാഷ',
      'close': 'അടയ്ക്കുക',
      // Demo / Simulator
      'sim_title': 'പാരാമെഡിക് സിമുലേറ്റർ (ഡെമോ)',
      'sim_desc': 'ടെസ്റ്റിംഗിനായി അടിയന്തിര സംഭവം സിമുലേറ്റ് ചെയ്യുക.',
      'sim_btn_1': 'സിൽക്ക് ബോർഡ് സിമുലേഷൻ',
      'sim_btn_2': 'ഹൈവേ വാച്ച്‌ഡോഗ് സിമുലേഷൻ',
    },
    'mr': {
      'app_title': 'RAKSHAK ResQ PILOT',
      'cockpit_sub': 'ईएमएस आपत्कालीन कॉकपिट',
      'citizen_app': 'नागरिक ॲप',
      // Statuses
      'status_available': 'तैनात / सज्ज',
      'status_en_route': 'घटनास्थळाकडे रवाना',
      'status_on_scene': 'घटनास्थळी पोहोचले',
      'status_transporting': 'रुग्णालयाकडे रवाना',
      'status_standby': 'प्रतीक्षेत',
      'auto_sync': 'स्वयंचलित ईएमएस सिंक',
      'c_v2x_banner': '5.9 GHz DSRC Online • ग्रीन कॉरिडोअर सक्रिय',
      'c_v2x_spec': 'SAE J2735 / NTCIP 1202',
      // Tabs
      'tab_radar': 'डिस्पॅच रडार',
      'tab_trauma': 'ट्रॉमा रुग्णालये',
      'tab_tools': 'पॅरामेडिक टूल्स',
      // Radar Header
      'gps_radar': 'जीपीएस रडार',
      'in_range': 'मर्यादेत',
      'active_incidents': 'परिसरातील सक्रिय आपत्कालीन घटना',
      'radius': 'त्रिज्या',
      // Card details
      'critical_severity': '🚨 अतिगंभीर आपत्कालीन',
      'high_priority': '⚠️ उच्च प्राधान्य',
      'away': 'दूर',
      'est_time': 'अंदाजे',
      'min': 'मिनिटे',
      'victim': 'बाधित व्यक्ती (रुग्ण)',
      'blood_group': 'रक्तगट',
      'peak_impact': 'आघात तीव्रता',
      'coordinates': 'स्थान निर्देशक',
      'claim_btn': 'स्वीकारा आणि ग्रीन कॉरिडोअर सुरू करा',
      // Trauma Bays
      'trauma_title': 'लेव्हल-१ ट्रॉमा रुग्णालये • थेट हॉटलाइन',
      'dial_trauma': 'ट्रॉमा सेंटरला कॉल करा',
      'call_connecting': 'ट्रॉमा हॉटलाइनशी संपर्क होत आहे: ',
      // Paramedic Tools
      'tools_title': 'त्वरित प्रतिसाद पॅरामेडिक संच',
      'abha_decryptor': 'आभा मेडिकल व्हॉल्ट डिक्रिप्टर',
      'abha_desc': 'आयुष्मान भारत डिजिटल मिशन अंतर्गत रुग्णाचा रक्तगट आणि औषध ॲलर्जी लगेच तपासा.',
      'abha_btn': 'रुग्णाचा आभा रेकॉर्ड तपासा',
      'signal_force': 'C-V2X ग्रीन कॉरिडोअर सिग्नल प्रीएम्प्शन',
      'signal_force_desc': 'ॲम्ब्युलन्ससाठी पुढील ३ ट्रॅफिक सिग्नल त्वरित हिरवे करा.',
      'signal_force_btn': 'पुढील सिग्नल हिरवे करा (ग्रीन वेव्ह)',
      'vitals_streamer': 'थेट आरोग्य निर्देशक ट्रान्समीटर',
      'vitals_desc': 'हार्ट रेट आणि रक्तदाब थेट रुग्णालयातील डॉक्टरांना पाठवा.',
      // Language Selector
      'change_language': 'भाषा / Language',
      'select_language': 'पायलट भाषा निवडा',
      'active_language': 'सक्रिय भाषा',
      'close': 'बंद करा',
      // Demo / Simulator
      'sim_title': 'पॅरामेडिक सिम्युलेटर (डेमो मोड)',
      'sim_desc': 'चाचणीसाठी आपत्कालीन परिस्थितीचे सिम्युलेशन करा.',
      'sim_btn_1': 'सिल्क बोर्ड अपघात सिम्युलेट',
      'sim_btn_2': 'हायवे वॉचडॉग सिम्युलेट',
    },
  };

  /// Translate a given key for a specified language code (defaulting to English)
  static String tr(String key, {String langCode = 'en'}) {
    final langMap = _localizedValues[langCode] ?? _localizedValues['en']!;
    return langMap[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
