import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/user/data/dialect_repository.dart';
import 'package:duruha/features/farmer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/user/data/location_repository.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  final FarmerProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FarmerProfileRepositoryImpl();

  // ── Text Controllers ──────────────────────────────────────────────────────
  late final _nameController = TextEditingController(text: widget.profile.name);
  late final _emailController = TextEditingController(
    text: widget.profile.email ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.profile.phone ?? '',
  );
  late final _farmAliasController = TextEditingController(
    text: widget.profile.farmerAlias,
  );
  late final _landAreaController = TextEditingController(
    text: widget.profile.landArea == 0
        ? ''
        : widget.profile.landArea.toString(),
  );
  late final _barangayController = TextEditingController(
    text: widget.profile.barangay ?? '',
  );
  late final _cityController = TextEditingController(
    text: widget.profile.city ?? '',
  );
  late final _provinceController = TextEditingController(
    text: widget.profile.province ?? '',
  );
  late final _landmarkController = TextEditingController(
    text: widget.profile.landmark ?? '',
  );
  late final _postalCodeController = TextEditingController(
    text: widget.profile.postalCode ?? '',
  );

  // ── State ─────────────────────────────────────────────────────────────────
  late List<String> _selectedDialect;
  late String _accessibility;
  late List<String> _waterSources;
  late List<String> _operatingDays;
  late String _deliveryWindow;
  double? _latitude;
  double? _longitude;

  bool _isLoading = false;
  bool _isLocating = false;

  // ── Options ───────────────────────────────────────────────────────────────
  List<String> _dialectOptions = [
    'Bisaya',
    'Tagalog',
    'Cebuano',
    'Hiligaynon',
    'Ilocano',
  ];

  static const _waterSourceOptions = [
    'River / Stream',
    'Deep Well (Borehole)',
    'Rainwater Harvesting',
    'Irrigation Canal',
    'Public/Municipal Tap',
    'Water Tanker',
  ];

  static const _accessibilityOptions = ['Truck', 'Tricycle', 'Walk_In'];
  static const _operatingDaysOptions = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _deliveryWindowOptions = ['AM', 'PM', 'Flexible'];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Pre-fill state from profile
    _selectedDialect = List.from(widget.profile.dialect);
    _accessibility = widget.profile.accessibilityType.isNotEmpty
        ? widget.profile.accessibilityType
        : _accessibilityOptions.first;
    _waterSources = List.from(widget.profile.waterSources);
    _operatingDays = List.from(widget.profile.operatingDays);
    _deliveryWindow = widget.profile.deliveryWindow.isNotEmpty
        ? widget.profile.deliveryWindow
        : _deliveryWindowOptions.first;
    _latitude = widget.profile.latitude;
    _longitude = widget.profile.longitude;

    // If dialect list is empty, fall back to session
    _initDialect();
    _loadDialectOptions();
  }

  Future<void> _initDialect() async {
    if (_selectedDialect.isEmpty) {
      final saved = await SessionService.getUserDialects();
      if (mounted && saved.isNotEmpty) {
        setState(() => _selectedDialect = saved);
      }
    }
  }

  Future<void> _loadDialectOptions() async {
    try {
      final dialects = await fetchAllDialectNames();
      if (mounted && dialects.isNotEmpty) {
        setState(() => _dialectOptions = dialects);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _farmAliasController.dispose();
    _landAreaController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _landmarkController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<String> _toggled(List<String> current, String item) =>
      current.contains(item)
      ? current.where((v) => v != item).toList()
      : [...current, item];

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      final pos = await determinePosition();
      if (mounted && pos != null) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
        DuruhaSnackBar.showSuccess(context, 'Location captured!');
      }
    } catch (e) {
      if (mounted) DuruhaSnackBar.showError(context, 'Location error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final updated = widget.profile.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        farmerAlias: _farmAliasController.text.trim(),
        landArea:
            double.tryParse(_landAreaController.text) ??
            widget.profile.landArea,
        barangay: _barangayController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        landmark: _landmarkController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        dialect: _selectedDialect,
        accessibilityType: _accessibility,
        waterSources: _waterSources,
        operatingDays: _operatingDays,
        deliveryWindow: _deliveryWindow,
        latitude: _latitude,
        longitude: _longitude,
      );

      await _repo.updateProfile(updated);

      final userId = await SessionService.getUserId();
      if (userId != null) {
        await SessionService.syncProfile(userId);
      }

      if (mounted) {
        DuruhaSnackBar.showSuccess(context, 'Profile updated successfully!');
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) DuruhaSnackBar.showError(context, 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'Edit Profile',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Personal Info ─────────────────────────────────────────────
              DuruhaSectionContainer(
                title: 'Personal Information',
                children: [
                  DuruhaTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_rounded,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  DuruhaTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  DuruhaTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  DuruhaSelectionChipGroup(
                    title: 'Preferred Dialect',
                    options: _dialectOptions,
                    selectedValues: _selectedDialect,
                    isNumbered: true,
                    onToggle: (val) {
                      setState(() {
                        _selectedDialect = _toggled(_selectedDialect, val);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Farm Details ──────────────────────────────────────────────
              DuruhaSectionContainer(
                title: 'Farm Details',
                children: [
                  DuruhaTextField(
                    controller: _farmAliasController,
                    label: 'Farm Name / Alias (optional)',
                    icon: Icons.landscape_rounded,
                  ),
                  DuruhaTextField(
                    controller: _landAreaController,
                    label: 'Land Area (hectares)',
                    icon: Icons.square_foot_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // optional
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  DuruhaDropdown(
                    label: 'Road Accessibility',
                    value: _accessibility,
                    items: _accessibilityOptions,
                    itemIcons: const {
                      'Truck': Icons.local_shipping_outlined,
                      'Tricycle': Icons.electric_rickshaw_outlined,
                      'Walk_In': Icons.directions_walk_outlined,
                    },
                    onChanged: (v) {
                      if (v != null) setState(() => _accessibility = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  DuruhaSelectionChipGroup(
                    title: 'Water Sources',
                    subtitle: 'Select all that apply',
                    options: _waterSourceOptions,
                    selectedValues: _waterSources,
                    onToggle: (val) {
                      setState(() {
                        _waterSources = _toggled(_waterSources, val);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Operations ────────────────────────────────────────────────
              DuruhaSectionContainer(
                title: 'Operations',
                children: [
                  DuruhaSelectionChipGroup(
                    title: 'Operating Days',
                    options: _operatingDaysOptions,
                    selectedValues: _operatingDays,
                    onToggle: (val) {
                      setState(() {
                        _operatingDays = _toggled(_operatingDays, val);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DuruhaDropdown(
                    label: 'Preferred Delivery Window',
                    value: _deliveryWindowOptions.contains(_deliveryWindow)
                        ? _deliveryWindow
                        : null,
                    items: _deliveryWindowOptions,
                    onChanged: (v) {
                      if (v != null) setState(() => _deliveryWindow = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Address ───────────────────────────────────────────────────
              DuruhaSectionContainer(
                title: 'Address',
                children: [
                  DuruhaTextField(
                    controller: _provinceController,
                    label: 'Province',
                    icon: Icons.map_rounded,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  DuruhaTextField(
                    controller: _cityController,
                    label: 'City / Municipality',
                    icon: Icons.location_city_rounded,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  DuruhaTextField(
                    controller: _barangayController,
                    label: 'Barangay',
                    icon: Icons.holiday_village_rounded,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  DuruhaTextField(
                    controller: _landmarkController,
                    label: 'Landmark / Street',
                    icon: Icons.place_rounded,
                  ),
                  DuruhaTextField(
                    controller: _postalCodeController,
                    label: 'Postal Code',
                    icon: Icons.markunread_mailbox_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _LocationRow(
                    latitude: _latitude,
                    longitude: _longitude,
                    isLocating: _isLocating,
                    onCapture: _captureLocation,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              DuruhaButton(
                text: 'Save Changes',
                isLoading: _isLoading,
                onPressed: _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Location Row ─────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final bool isLocating;
  final VoidCallback onCapture;

  const _LocationRow({
    required this.latitude,
    required this.longitude,
    required this.isLocating,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasLocation = latitude != null && longitude != null;

    return Row(
      children: [
        Icon(
          Icons.gps_fixed_rounded,
          size: 18,
          color: hasLocation ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GPS Coordinates',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                hasLocation
                    ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                    : 'Not set — tap to capture',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hasLocation
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (isLocating)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.my_location_rounded, size: 16),
            label: Text(hasLocation ? 'Update' : 'Capture'),
          ),
      ],
    );
  }
}
