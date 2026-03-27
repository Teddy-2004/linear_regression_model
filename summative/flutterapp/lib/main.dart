import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const WBPredictorApp());

// ── Colours ───────────────────────────────────────────────────────────────────
const Color kNavy    = Color(0xFF003366); // World Bank navy
const Color kGold    = Color(0xFFFFB800); // World Bank gold
const Color kBg      = Color(0xFFF4F6FA);
const Color kSuccess = Color(0xFF1B7A4A);
const Color kWarning = Color(0xFFE07B00);
const Color kDanger  = Color(0xFFC62828);
const Color kCard    = Colors.white;

class WBPredictorApp extends StatelessWidget {
  const WBPredictorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WB Africa Cost Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(seedColor: kNavy),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCDD5E0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCDD5E0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kNavy, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kDanger)),
          labelStyle: const TextStyle(color: kNavy, fontSize: 13),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

// ── Main Prediction Page ──────────────────────────────────────────────────────
class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});
  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  // ── Replace with your Render.com URL after deployment ─────────────────────
  static const String _apiBase = 'https://wb-africa-cost.onrender.com';

  final _formKey = GlobalKey<FormState>();

  // ── Text controllers (numeric inputs) ────────────────────────────────────
  final _wbCommitCtrl     = TextEditingController();
  final _idaShareCtrl     = TextEditingController();
  final _grantShareCtrl   = TextEditingController();
  final _approvalYearCtrl = TextEditingController();
  final _durationCtrl     = TextEditingController();

  // ── Dropdown state ────────────────────────────────────────────────────────
  String _country     = 'Republic of Rwanda';
  String _subregion   = 'East Africa';
  String _sector      = 'Highways';
  String _lendingType = 'Specific Investment Loan';

  // ── Result state ──────────────────────────────────────────────────────────
  bool                  _isLoading = false;
  Map<String, dynamic>? _result;
  String?               _errorMsg;

  // ── Dropdown options ──────────────────────────────────────────────────────
  final _countries = [
    'Africa', 'Arab Republic of Egypt', 'Burkina Faso', 'Central Africa',
    'Central African Republic', 'Democratic Republic of the Congo',
    'Eastern Africa', 'Federal Democratic Republic of Ethiopia',
    'Federal Republic of Nigeria', 'Gabonese Republic',
    'Islamic Republic of Mauritania', 'Kingdom of Eswatini',
    'Kingdom of Lesotho', 'Kingdom of Morocco', 'Republic of Angola',
    'Republic of Benin', 'Republic of Botswana', 'Republic of Burundi',
    'Republic of Cabo Verde', 'Republic of Cameroon', 'Republic of Chad',
    'Republic of Congo', "Republic of Cote d'Ivoire", 'Republic of Djibouti',
    'Republic of Ghana', 'Republic of Guinea', 'Republic of Kenya',
    'Republic of Liberia', 'Republic of Madagascar', 'Republic of Malawi',
    'Republic of Mali', 'Republic of Mauritius', 'Republic of Mozambique',
    'Republic of Namibia', 'Republic of Niger', 'Republic of Rwanda',
    'Republic of Senegal', 'Republic of Sierra Leone',
    'Republic of South Africa', 'Republic of South Sudan',
    'Republic of The Gambia', 'Republic of Togo', 'Republic of Tunisia',
    'Republic of Uganda', 'Republic of Zambia', 'Republic of Zimbabwe',
    'Republic of the Sudan', 'Somali Democratic Republic', 'Southern Africa',
    'State of Eritrea', 'Union of the Comoros',
    'United Republic of Tanzania', 'Western Africa',
  ];

  final _subregions = [
    'East Africa', 'West Africa', 'Southern Africa', 'Other Africa',
  ];

  final _sectors = [
    'Agriculture adjustment', 'Basic health',
    'Central Government (Central Agencies)', 'Distribution and transmission',
    'Early Childhood Education', 'Energy Transmission and Distribution',
    'Financial sector development', 'Fisheries', 'Forestry', 'Health',
    'Highways', 'Housing Construction', 'Hydro', 'ICT Infrastructure',
    'Irrigation and Drainage', 'Law and Justice', 'Mining',
    'Non-Renewable Energy Generation', 'Oil and Gas', 'Other',
    'Other Agriculture; Fishing and Forestry', 'Other Education',
    'Other Energy and Extractives', 'Other Industry; Trade and Services',
    'Other Public Administration', 'Other Transportation',
    'Other Water Supply; Sanitation and Waste Management',
    'Ports/Waterways', 'Power', 'Primary Education', 'Railways',
    'Renewable Energy Hydro', 'Renewable Energy Solar', 'Renewable energy',
    'Roads and highways', 'Rural and Inter-Urban Roads',
    'Rural water supply and sanitation', 'Sanitation', 'Secondary Education',
    'Social Protection', 'Sub-National Government', 'Telecommunications',
    'Tertiary Education', 'Urban Transport', 'Urban water supply',
    'Vocational training', 'Waste Management', 'Water Supply',
    'Workforce Development and Vocational Education',
  ];

  final _lendingTypes = [
    'Adaptable Program Loan', 'Development Policy Lending',
    'Emergency Recovery Loan', 'Financial Intermediary Loan',
    'Investment Project Financing', 'Learning and Innovation Loan',
    'Poverty Reduction Support Credit', 'Program-for-Results Financing',
    'Sector Adjustment Loan', 'Sector Investment and Maintenance Loan',
    'Specific Investment Loan', 'Structural Adjustment Loan',
    'Technical Assistance Loan', 'Unknown',
  ];

  // ── API call ──────────────────────────────────────────────────────────────
  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _result    = null;
      _errorMsg  = null;
    });

    final body = {
      'country':                _country,
      'subregion':              _subregion,
      'sector':                 _sector,
      'lending_type':           _lendingType,
      'wb_commitment_usd':      double.parse(_wbCommitCtrl.text.trim()),
      'ida_share':              double.parse(_idaShareCtrl.text.trim()),
      'grant_share':            double.parse(_grantShareCtrl.text.trim()),
      'approval_year':          int.parse(_approvalYearCtrl.text.trim()),
      'project_duration_years': int.parse(_durationCtrl.text.trim()),
    };

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        setState(() => _result = jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        setState(() =>
            _errorMsg = 'Error ${response.statusCode}: ${err['detail'] ?? 'Unknown error'}');
      }
    } catch (e) {
      setState(() =>
          _errorMsg = 'Connection failed: $e\n\nCheck your API URL and internet connection.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _reset() {
    _formKey.currentState?.reset();
    for (final c in [
      _wbCommitCtrl, _idaShareCtrl, _grantShareCtrl,
      _approvalYearCtrl, _durationCtrl
    ]) c.clear();
    setState(() {
      _country     = 'Republic of Rwanda';
      _subregion   = 'East Africa';
      _sector      = 'Highways';
      _lendingType = 'Specific Investment Loan';
      _result      = null;
      _errorMsg    = null;
    });
  }

  // ── Widget helpers ────────────────────────────────────────────────────────
  Widget _sectionLabel(String emoji, String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kNavy)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: kNavy.withOpacity(0.2))),
        ]),
      );

  Widget _numField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required double min,
    required double max,
    bool isInt = false,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12)),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          final n = num.tryParse(v.trim());
          if (n == null) return 'Enter a valid number';
          if (n < min || n > max) return 'Must be $min – $max';
          return null;
        },
      );

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((i) => DropdownMenuItem<T>(
                value: i,
                child: Text(i.toString(),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Required' : null,
      );

  // Risk colour
  Color _riskColor(String risk) {
    if (risk.startsWith('LOW'))      return kSuccess;
    if (risk.startsWith('MEDIUM'))   return kWarning;
    if (risk.startsWith('HIGH'))     return Colors.orange.shade800;
    return kDanger;
  }

  IconData _riskIcon(String risk) {
    if (risk.startsWith('LOW'))    return Icons.check_circle_outline;
    if (risk.startsWith('MEDIUM')) return Icons.warning_amber_outlined;
    if (risk.startsWith('HIGH'))   return Icons.report_problem_outlined;
    return Icons.dangerous_outlined;
  }

  String _formatUsd(double v) {
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(2)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  void dispose() {
    for (final c in [
      _wbCommitCtrl, _idaShareCtrl, _grantShareCtrl,
      _approvalYearCtrl, _durationCtrl
    ]) c.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WB Africa Cost Predictor',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Anti-Corruption Tool · World Bank Projects',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset form',
              onPressed: _reset),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Banner ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [kNavy, Color(0xFF1A5276)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Text('🌍', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Government Oversight Tool',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(
                            'Enter project details to predict actual project cost '
                            'and detect budget anomalies.',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),

                // ── Section 1: Project Location ───────────────────────────
                _sectionLabel('📍', 'Project Location'),
                _dropdown<String>(
                    label: 'Country',
                    value: _country,
                    items: _countries,
                    onChanged: (v) => setState(() => _country = v!)),
                const SizedBox(height: 12),
                _dropdown<String>(
                    label: 'Sub-region',
                    value: _subregion,
                    items: _subregions,
                    onChanged: (v) => setState(() => _subregion = v!)),

                // ── Section 2: Project Details ────────────────────────────
                _sectionLabel('🏗️', 'Project Details'),
                _dropdown<String>(
                    label: 'Sector',
                    value: _sector,
                    items: _sectors,
                    onChanged: (v) => setState(() => _sector = v!)),
                const SizedBox(height: 12),
                _dropdown<String>(
                    label: 'Lending Type',
                    value: _lendingType,
                    items: _lendingTypes,
                    onChanged: (v) => setState(() => _lendingType = v!)),
                const SizedBox(height: 12),
                _numField(
                    ctrl: _approvalYearCtrl,
                    label: 'Approval Year',
                    hint: 'e.g. 2015',
                    min: 1970,
                    max: 2030,
                    isInt: true),
                const SizedBox(height: 12),
                _numField(
                    ctrl: _durationCtrl,
                    label: 'Project Duration (Years)',
                    hint: 'e.g. 6',
                    min: 0,
                    max: 20,
                    isInt: true),

                // ── Section 3: Financial Details ──────────────────────────
                _sectionLabel('💰', 'Financial Details'),
                _numField(
                    ctrl: _wbCommitCtrl,
                    label: 'WB Commitment Amount (USD)',
                    hint: 'e.g. 50000000',
                    min: 100000,
                    max: 5000000000),
                const SizedBox(height: 12),
                _numField(
                    ctrl: _idaShareCtrl,
                    label: 'IDA Share (0.0 – 1.0)',
                    hint: 'e.g. 1.0',
                    min: 0.0,
                    max: 1.0),
                const SizedBox(height: 12),
                _numField(
                    ctrl: _grantShareCtrl,
                    label: 'Grant Share (0.0 – 1.0)',
                    hint: 'e.g. 0.0',
                    min: 0.0,
                    max: 1.0),

                const SizedBox(height: 28),

                // ── Predict Button ────────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _predict,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kNavy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: kNavy, strokeWidth: 2.5))
                        : const Icon(Icons.auto_graph_rounded, size: 22),
                    label: Text(
                      _isLoading ? 'Predicting...' : 'Predict',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Error display ─────────────────────────────────────────
                if (_errorMsg != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: kDanger.withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: kDanger, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMsg!,
                              style: const TextStyle(
                                  color: kDanger, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // ── Result display ────────────────────────────────────────
                if (_result != null) _buildResultCard(_result!),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Result card ───────────────────────────────────────────────────────────
  Widget _buildResultCard(Map<String, dynamic> r) {
    final predicted  = (r['predicted_actual_cost_usd'] as num).toDouble();
    final committed  = (r['wb_commitment_usd'] as num).toDouble();
    final ratio      = (r['cost_ratio'] as num).toDouble();
    final risk       = r['risk_flag'] as String;
    final riskColor  = _riskColor(risk);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.45), width: 2),
        boxShadow: [
          BoxShadow(
              color: riskColor.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: riskColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              const Icon(Icons.assessment_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Prediction Result',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(r['model_used'] ?? '',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10)),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              // Cost comparison row
              Row(children: [
                Expanded(
                    child: _costTile(
                        'WB Commitment', _formatUsd(committed), kNavy)),
                const SizedBox(width: 12),
                Expanded(
                    child: _costTile(
                        'Predicted Actual Cost',
                        _formatUsd(predicted),
                        riskColor)),
              ]),
              const SizedBox(height: 14),

              // Cost ratio bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: riskColor.withOpacity(0.25)),
                ),
                child: Column(children: [
                  Text('Cost Ratio (Predicted / Committed)',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${ratio.toStringAsFixed(2)}×',
                      style: TextStyle(
                          color: riskColor,
                          fontSize: 36,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (ratio / 3.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      color: riskColor,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Risk flag
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(_riskIcon(risk), color: riskColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(risk,
                          style: TextStyle(
                              color: riskColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13))),
                ]),
              ),

              const SizedBox(height: 10),
              Text(
                'This prediction helps flag potentially inflated project '
                'costs before contract signing.',
                style:
                    TextStyle(color: Colors.grey[500], fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _costTile(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ]),
      );
}
