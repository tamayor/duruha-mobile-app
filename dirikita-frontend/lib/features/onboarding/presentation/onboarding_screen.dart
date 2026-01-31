import 'package:duruha/features/onboarding/presentation/components/consumer_profile_step.dart';
import 'package:duruha/features/onboarding/presentation/components/farmer_profile_step.dart';
import 'package:duruha/features/onboarding/presentation/components/produce_selection_step.dart';
import 'package:duruha/features/onboarding/presentation/components/terms_and_conditions_step.dart';
import 'package:duruha/features/onboarding/presentation/components/role_selection_step.dart';
import 'package:duruha/features/onboarding/presentation/components/basic_info_step.dart';
import 'package:duruha/features/onboarding/presentation/components/onboarding_success_view.dart';

import 'package:duruha/main.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/data/dialects.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

  // State Variables
  String? _userRole;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _generatedId;
  bool _acceptedTerms = false;

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _landmarkController = TextEditingController();

  // Consumer Data
  String _consumerSegment = 'Household';
  String _cookingFrequency = 'Weekly';
  List<String> _qualityPreferences = ['Class A'];

  // Farmer Data
  final _farmAliasController = TextEditingController();
  final _landAreaController = TextEditingController();
  String _accessibilityType = 'Truck';
  List<String> _waterSources = [];

  // Dialect Data
  final List<String> _selectedDialects = [];
  final List<String> _dialectOptions = dialectOptions;

  // Logistics & Payment
  final List<String> _paymentMethods = [];
  String? _deliveryWindow;
  final List<String> _operatingDays = [];
  final List<String> _daysOptions = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  // Produce Data

  // Produce Data
  final Map<String, Map<String, dynamic>> _consumerDemands = {};
  final Map<String, List<String>> _farmerPledges = {};

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _telephoneController.dispose();
    _streetAddressController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  // --- Logic ---

  void _logFormData() {
    final formData = {
      'role': _userRole,
      'basicInfo': {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'telephone': _telephoneController.text,
        'streetAddress': _streetAddressController.text,
        'barangay': _barangayController.text,
        'city': _cityController.text,
        'province': _provinceController.text,
        'postalCode': _postalCodeController.text,
        'landmark': _landmarkController.text,
        'dialects': _selectedDialects,
        'paymentMethods': _paymentMethods,
        'operatingDays': _operatingDays,
        'deliveryWindow': _deliveryWindow,
      },
      if (_userRole == 'Consumer')
        'consumerProfile': {
          'segment': _consumerSegment,
          'cookingFreq': _cookingFrequency,
          'qualityPrefs': _qualityPreferences,
        },
      if (_userRole == 'Farmer')
        'farmerProfile': {
          'alias': _farmAliasController.text,
          'landArea': _landAreaController.text,
          'accessibility': _accessibilityType,
          'waterSources': _waterSources,
        },
    };

    debugPrint('🚀 [API PREP] Form Data: $formData');
  }

  void _nextPage() {
    if (_currentPage == 1) {
      if (!_formKey.currentState!.validate()) {
        _showError("Please fill in all required fields.");
        return;
      }
      // Language Validation
      if (_selectedDialects.isEmpty) {
        _showError("Please select at least one language/dialect");
        return;
      }
      if (_paymentMethods.isEmpty) {
        _showError("Please select at least one preferred payment method");
        return;
      }
      if (_operatingDays.isEmpty) {
        _showError("Please select at least one operating day");
        return;
      }
      if (_deliveryWindow == null) {
        _showError("Please select a preferred delivery window");
        return;
      }
      // Ensure terms step is respected
    }

    // Custom Validation for Profile Step
    if (_currentPage == 2) {
      if (!_formKey.currentState!.validate()) {
        _showError("Please fill in all required fields.");
        return;
      }
      if (_userRole == 'Farmer' && _waterSources.isEmpty) {
        _showError("Please select at least one water source");
        return;
      }
    }

    // Produce Validation
    if (_currentPage == 3) {
      bool hasSelection = _userRole == 'Consumer'
          ? _consumerDemands.isNotEmpty
          : _farmerPledges.isNotEmpty;

      if (!hasSelection) {
        _showError(
          _userRole == 'Consumer'
              ? "Please select at least one produce item to buy."
              : "Please pledge at least one crop to sell.",
        );
        return;
      }
    }

    // Terms & Conditions Validation
    if (_currentPage == 4) {
      if (!_acceptedTerms) {
        _showError(
          "Please read and accept the Terms and Conditions to proceed.",
        );
        return;
      }
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
      setState(() => _currentPage++);
      _submitForm();
      return;
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
      setState(() => _currentPage--);
    }
  }

  void _selectRole(String role) {
    setState(() => _userRole = role);
    Future.delayed(const Duration(milliseconds: 200), _nextPage);
  }

  void _showError(String message) {
    DuruhaSnackBar.showError(context, message, title: "Action Required");
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500)); // Faster Mock API
    setState(() {
      _isSubmitting = false;
      _generatedId = _generateUuid();
    });
    _logFormData(); // Log data after basic info
  }

  String _generateUuid() {
    return 'id-no';
  }

  // --- UI Builders ---

  String _getStepTitle() {
    // 1. Safety check: If _userRole is null, use an empty string or default
    final role = _userRole ?? "User";

    switch (_currentPage) {
      case 0:
        return "Choose Your Path";
      case 1:
        // 2. Uses String Interpolation ($) for clean formatting
        return "Nice to meet you, $role";
      case 2:
        // Bonus: You can add it here too!
        // Output: "Craft Your Consumer Profile"
        return "Craft Your $role Profile";
      case 3:
        return "Curate Your Market";
      case 4:
        return "Terms & Conditions";
      default:
        return "";
    }
  }

  Widget _buildStepIndicator() {
    if (_currentPage >= 5) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (index) {
          final bool isActive = _currentPage == index;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            // The active dot becomes a "pill" shape, inactive is a circle
            width: isActive ? 24 : 8,
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // _buildHeader removed

  // --- Page Content ---

  Widget _buildRoleSelection() {
    return RoleSelectionStep(
      selectedRole: _userRole,
      onRoleSelected: _selectRole,
    );
  }

  Widget _buildBasicInfo() {
    return BasicInfoStep(
      nameController: _nameController,
      emailController: _emailController,
      phoneController: _phoneController,
      telephoneController: _telephoneController,
      streetAddressController: _streetAddressController,
      barangayController: _barangayController,
      cityController: _cityController,
      provinceController: _provinceController,
      postalCodeController: _postalCodeController,
      landmarkController: _landmarkController,
      dialectOptions: _dialectOptions,
      selectedDialects: _selectedDialects,
      onDialectToggle: (dialect) {
        setState(() {
          if (_selectedDialects.contains(dialect)) {
            _selectedDialects.remove(dialect);
          } else {
            _selectedDialects.add(dialect);
          }
        });
      },
      paymentMethodOptions: const ['GCash', 'Bank Transfer', 'Cash'],
      selectedPaymentMethods: _paymentMethods,
      onPaymentMethodToggle: (val) {
        setState(() {
          if (_paymentMethods.contains(val)) {
            _paymentMethods.remove(val);
          } else {
            _paymentMethods.add(val);
          }
        });
      },
      operatingDaysOptions: _daysOptions,
      selectedOperatingDays: _operatingDays,
      onOperatingDayToggle: (day) {
        setState(() {
          if (_operatingDays.contains(day)) {
            _operatingDays.remove(day);
          } else {
            _operatingDays.add(day);
          }
        });
      },
      deliveryWindowOptions: const ['AM', 'PM', 'Flexible'],
      selectedDeliveryWindow: _deliveryWindow,
      onDeliveryWindowChanged: (v) => setState(() => _deliveryWindow = v),
    );
  }

  Widget _buildSpecificProfile() {
    return Column(
      children: [
        const SizedBox(height: 24), // Space
        Expanded(
          child: _userRole == 'Consumer'
              ? ConsumerProfileStep(
                  initialSegment: _consumerSegment,
                  initialCookingFreq: _cookingFrequency,
                  initialQualityPrefs: _qualityPreferences,
                  onSegmentChanged: (v) => _consumerSegment = v,
                  onCookingFreqChanged: (v) => _cookingFrequency = v,
                  onQualityChanged: (v) => _qualityPreferences = v,
                )
              : FarmerProfileStep(
                  aliasController: _farmAliasController,
                  landAreaController: _landAreaController,
                  initialAccessibility: _accessibilityType,
                  initialWaterSources: _waterSources,
                  onAccessibilityChanged: (v) => _accessibilityType = v,
                  onWaterSourcesChanged: (v) => _waterSources = v,
                ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildProduce() {
    return Column(
      children: [
        const SizedBox(height: 24), // Space
        Expanded(
          child: ProduceSelectionStep(
            userRole: _userRole ?? 'Consumer',
            consumerDemands: _consumerDemands,
            farmerPledges: _farmerPledges,
            onItemToggled: (id, isSelected) {
              setState(() {
                if (_userRole == 'Consumer') {
                  isSelected
                      ? _consumerDemands[id] = {}
                      : _consumerDemands.remove(id);
                } else {
                  isSelected
                      ? _farmerPledges[id] = []
                      : _farmerPledges.remove(id);
                }
              });
            },
            onFarmerPledgeChanged: (id, variety, isSelected) {
              setState(() {
                final list = _farmerPledges[id] ?? [];
                isSelected ? list.add(variety) : list.remove(variety);
                _farmerPledges[id] = list;
              });
            },
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTerms() {
    return Column(
      children: [
        Expanded(
          child: TermsAndConditionsStep(
            isAgreed: _acceptedTerms,
            onAgreedChanged: (v) => setState(() => _acceptedTerms = v),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return OnboardingSuccessView(
      generatedId: _generatedId,
      firstName: _nameController.text.split(' ')[0],
      userRole: _userRole ?? 'User', // Fallback just in case
      onEnterDashboard: () {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (r) => false,
          arguments: {
            'role': _userRole ?? 'Consumer',
            'name': _nameController.text.split(' ')[0],
          },
        );
      },
    );
  }

  // --- Main Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Meta Compact Header
            Container(
              height: 56, // Fixed height
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back Button (Left)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: (_currentPage > 0 && _currentPage < 5)
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            onPressed: _prevPage,
                            padding: EdgeInsets.zero,
                            color: Theme.of(context).colorScheme.onSurface,
                            constraints: const BoxConstraints(),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Title (Center)
                  if (_currentPage < 5)
                    Text(
                      _getStepTitle(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  // Action / Spacer (Right)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        final current = DuruhaApp.themeNotifier.value;
                        DuruhaApp.themeNotifier.value =
                            current == ThemeMode.light
                            ? ThemeMode.dark
                            : ThemeMode.light;
                      },
                    ),
                  ),
                ],
              ),
            ),

            _buildStepIndicator(),

            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Main Content - Fills available space
                  Form(
                    key: _formKey,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildRoleSelection(), // 0
                        _buildBasicInfo(), // 1
                        _buildSpecificProfile(), // 2
                        _buildProduce(), // 3
                        _buildTerms(), // 4
                        _buildSuccess(), // 5
                      ],
                    ),
                  ),

                  // 2. Bottom Floating Action Bar
                  if (_currentPage > 0 && _currentPage < 5)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: double.infinity,
                        height: 80,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.95),
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: DuruhaButton(
                          text: _currentPage == 4
                              ? "FINISH REGISTRATION"
                              : "CONTINUE",
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : () => _nextPage(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
