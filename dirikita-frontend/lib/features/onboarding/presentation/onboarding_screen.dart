import 'package:duruha/features/onboarding/presentation/components/consumer_profile_step.dart';
import 'package:duruha/features/onboarding/presentation/components/farmer_profile_step.dart';
import 'package:duruha/features/onboarding/presentation/components/produce_selection_step.dart';
import 'package:duruha/features/auth/data/auth_repository.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/shared/user/domain/user_models.dart';
import 'package:duruha/features/onboarding/presentation/components/terms_and_conditions_step.dart';
import 'package:duruha/features/onboarding/presentation/components/role_selection_step.dart';
import 'package:duruha/features/onboarding/presentation/components/basic_info_step.dart';
import 'package:duruha/features/onboarding/presentation/components/onboarding_success_view.dart';

import 'package:duruha/main.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/data/dialects.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart'; // Import ProduceCategory
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

  // Timer for debouncing text saves
  // Timer? _debounce;
  // For now, we save on navigation as requested "every continue",
  // but let's also save on toggle interactions for robust UX.

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

  // Search Data
  String _produceSearchQuery = '';
  final _searchController = TextEditingController();
  ProduceCategory? _selectedCategory;
  bool _isSearchActive = false;

  // Define category icons mapping
  static const Map<ProduceCategory, IconData> _categoryIcons = {
    ProduceCategory.leafy: Icons.eco,
    ProduceCategory.fruitVeg: Icons.bakery_dining,
    ProduceCategory.root: Icons.grass,
    ProduceCategory.spice: Icons.flare,
    ProduceCategory.fruit: Icons.apple,
    ProduceCategory.legume: Icons.grain,
  };

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
    _searchController.dispose(); // Dispose search controller
    _streetAddressController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initPersistence();
  }

  // --- Persistence ---

  Future<void> _initPersistence() async {
    await _loadSavedState();
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // key prefix: onboarding_
      await prefs.setInt('onboarding_page', _currentPage);
      if (_userRole != null)
        await prefs.setString('onboarding_role', _userRole!);

      // Basic Info
      await prefs.setString('onboarding_name', _nameController.text);
      await prefs.setString('onboarding_email', _emailController.text);
      await prefs.setString('onboarding_phone', _phoneController.text);
      await prefs.setString('onboarding_telephone', _telephoneController.text);
      await prefs.setString('onboarding_street', _streetAddressController.text);
      await prefs.setString('onboarding_barangay', _barangayController.text);
      await prefs.setString('onboarding_city', _cityController.text);
      await prefs.setString('onboarding_province', _provinceController.text);
      await prefs.setString('onboarding_postal', _postalCodeController.text);
      await prefs.setString('onboarding_landmark', _landmarkController.text);

      await prefs.setStringList('onboarding_dialects', _selectedDialects);
      await prefs.setStringList('onboarding_payment', _paymentMethods);
      await prefs.setStringList('onboarding_days', _operatingDays);
      if (_deliveryWindow != null)
        await prefs.setString('onboarding_window', _deliveryWindow!);

      // Consumer
      await prefs.setString('onboarding_segment', _consumerSegment);
      await prefs.setString('onboarding_cooking', _cookingFrequency);
      await prefs.setStringList('onboarding_quality', _qualityPreferences);
      await prefs.setString('onboarding_demands', jsonEncode(_consumerDemands));

      // Farmer
      await prefs.setString('onboarding_alias', _farmAliasController.text);
      await prefs.setString('onboarding_land', _landAreaController.text);
      await prefs.setString('onboarding_access', _accessibilityType);
      await prefs.setStringList('onboarding_water', _waterSources);
      await prefs.setString('onboarding_pledges', jsonEncode(_farmerPledges));

      // Terms
      await prefs.setBool('onboarding_terms', _acceptedTerms);
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        setState(() {
          _currentPage = prefs.getInt('onboarding_page') ?? 0;
          _userRole = prefs.getString('onboarding_role');

          _nameController.text = prefs.getString('onboarding_name') ?? '';
          _emailController.text = prefs.getString('onboarding_email') ?? '';
          _phoneController.text = prefs.getString('onboarding_phone') ?? '';
          _telephoneController.text =
              prefs.getString('onboarding_telephone') ?? '';
          _streetAddressController.text =
              prefs.getString('onboarding_street') ?? '';
          _barangayController.text =
              prefs.getString('onboarding_barangay') ?? '';
          _cityController.text = prefs.getString('onboarding_city') ?? '';
          _provinceController.text =
              prefs.getString('onboarding_province') ?? '';
          _postalCodeController.text =
              prefs.getString('onboarding_postal') ?? '';
          _landmarkController.text =
              prefs.getString('onboarding_landmark') ?? '';

          _selectedDialects.clear();
          _selectedDialects.addAll(
            prefs.getStringList('onboarding_dialects') ?? [],
          );

          _paymentMethods.clear();
          _paymentMethods.addAll(
            prefs.getStringList('onboarding_payment') ?? [],
          );

          _operatingDays.clear();
          _operatingDays.addAll(prefs.getStringList('onboarding_days') ?? []);

          _deliveryWindow = prefs.getString('onboarding_window');

          // Consumer
          _consumerSegment =
              prefs.getString('onboarding_segment') ?? 'Household';
          _cookingFrequency = prefs.getString('onboarding_cooking') ?? 'Weekly';
          _qualityPreferences.clear();
          _qualityPreferences.addAll(
            prefs.getStringList('onboarding_quality') ?? ['Class A'],
          );

          final demandsJson = prefs.getString('onboarding_demands');
          if (demandsJson != null) {
            final decoded = jsonDecode(demandsJson) as Map<String, dynamic>;
            _consumerDemands.clear();
            decoded.forEach((key, value) {
              _consumerDemands[key] = Map<String, dynamic>.from(value as Map);
            });
          }

          // Farmer
          _farmAliasController.text = prefs.getString('onboarding_alias') ?? '';
          _landAreaController.text = prefs.getString('onboarding_land') ?? '';
          _accessibilityType = prefs.getString('onboarding_access') ?? 'Truck';

          _waterSources.clear();
          _waterSources.addAll(prefs.getStringList('onboarding_water') ?? []);

          final pledgesJson = prefs.getString('onboarding_pledges');
          if (pledgesJson != null) {
            final decoded = jsonDecode(pledgesJson) as Map<String, dynamic>;
            _farmerPledges.clear();
            decoded.forEach((key, value) {
              _farmerPledges[key] = List<String>.from(value as List);
            });
          }

          _acceptedTerms = prefs.getBool('onboarding_terms') ?? false;
        });

        // Restore page controller if we aren't on page 0
        if (_currentPage > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(_currentPage);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading state: $e');
    }
  }

  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('onboarding_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // --- Logic ---

  Map<String, dynamic> _buildSubmissionData() {
    return {
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
          'demands': _consumerDemands,
        },
      if (_userRole == 'Farmer')
        'farmerProfile': {
          'alias': _farmAliasController.text,
          'landArea': _landAreaController.text,
          'accessibility': _accessibilityType,
          'waterSources': _waterSources,
          'pledges': _farmerPledges,
        },
    };
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
      _saveState(); // Save on next page
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
      _saveState(); // Save on prev page too
    }
  }

  void _selectRole(String role) {
    setState(() => _userRole = role);
    _saveState(); // Save role immediately
    Future.delayed(const Duration(milliseconds: 200), _nextPage);
  }

  void _showError(String message) {
    DuruhaSnackBar.showError(context, message, title: "Action Required");
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);

    try {
      final submissionData = _buildSubmissionData();
      debugPrint('🚀 [ONBOARDING] Submitting Data: $submissionData');

      final authRepo = AuthRepository();

      // 1. Get current User ID (from session or args if we had them)
      // For now, let's assume we are updating the current session user
      // or creating a new profile if it's a fresh flow.
      final currentUser = await SessionService.getSavedUser();
      final userId =
          currentUser?.id ??
          'temp_new_user_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Update Profile & Persist Session
      await authRepo.updateProfile(userId, submissionData);

      // 3. Submit any extra KYC docs (simulated)
      await authRepo.submitKyc(userId, {'termsAccepted': true});

      if (!mounted) return;

      await _clearSavedState(); // Clear saved state on success

      setState(() {
        _isSubmitting = false;
        _generatedId = userId; // Show actuall User ID or a generated reference
      });
    } catch (e) {
      debugPrint("❌ [ONBOARDING] Error: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError("Failed to submit onboarding data. Please try again.");
      }
    }
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _buildFloatingSearchBar() {
    if (!_isSearchActive) return const SizedBox.shrink();

    return Positioned(
      top: 10,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(30),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search produce...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    hintStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                  onChanged: (v) => setState(() => _produceSearchQuery = v),
                ),
              ),
              DuruhaPopupMenu<ProduceCategory?>(
                selectedValue: _selectedCategory,
                tooltip: "Filter by Category",
                items: [null, ..._categoryIcons.keys],
                itemIcons: {null: Icons.grid_view, ..._categoryIcons},
                labelBuilder: (category) {
                  if (category == null) return "All";
                  final name = category.name;
                  return name.substring(0, 1).toUpperCase() + name.substring(1);
                },
                onSelected: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSearchActive = false;
                    _produceSearchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
            ],
          ),
        ),
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
          _saveState();
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
          _saveState();
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
          _saveState();
        });
      },
      deliveryWindowOptions: const ['AM', 'PM', 'Flexible'],
      selectedDeliveryWindow: _deliveryWindow,
      onDeliveryWindowChanged: (v) {
        setState(() => _deliveryWindow = v);
        _saveState();
      },
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
                  onSegmentChanged: (v) {
                    _consumerSegment = v;
                    _saveState();
                  },
                  onCookingFreqChanged: (v) {
                    _cookingFrequency = v;
                    _saveState();
                  },
                  onQualityChanged: (v) {
                    _qualityPreferences = v;
                    _saveState();
                  },
                )
              : FarmerProfileStep(
                  aliasController: _farmAliasController,
                  landAreaController: _landAreaController,
                  initialAccessibility: _accessibilityType,
                  initialWaterSources: _waterSources,
                  onAccessibilityChanged: (v) {
                    _accessibilityType = v;
                    _saveState();
                  },
                  onWaterSourcesChanged: (v) {
                    _waterSources = v;
                    _saveState();
                  },
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
            searchQuery: _produceSearchQuery,
            selectedCategory: _selectedCategory,
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
                _saveState();
              });
            },
            onFarmerPledgeChanged: (id, variety, isSelected) {
              setState(() {
                final list = _farmerPledges[id] ?? [];
                isSelected ? list.add(variety) : list.remove(variety);
                _farmerPledges[id] = list;
                _saveState();
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
      onEnterDashboard: () async {
        // Ensure session is valid/fresh before entering
        final user = await SessionService.getSavedUser();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          (user?.role == UserRole.farmer) ? '/farmer/main' : '/consumer/main',
          (r) => false,
          arguments: user,
        );
      },
    );
  }

  // --- Main Build ---

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: _currentPage < 5 ? _getStepTitle() : null,
      showBackButton: _currentPage > 0 && _currentPage < 5,
      onBackPressed: _prevPage,
      appBarActions: [
        if (_currentPage == 3 && !_isSearchActive)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isSearchActive = true),
          ),
        IconButton(
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () {
            final current = DuruhaApp.themeNotifier.value;
            DuruhaApp.themeNotifier.value = current == ThemeMode.light
                ? ThemeMode.dark
                : ThemeMode.light;
          },
        ),
      ],
      body: Stack(
        children: [
          Column(
            children: [
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
                  ],
                ),
              ),
            ],
          ),

          // Floating Search Bar - Positioned over everything
          _buildFloatingSearchBar(),

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
                  text: _currentPage == 4 ? "FINISH REGISTRATION" : "CONTINUE",
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : () => _nextPage(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
