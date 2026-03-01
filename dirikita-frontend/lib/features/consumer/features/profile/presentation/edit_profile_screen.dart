import 'package:duruha/core/constants/quality_preferences.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/constants/consumer_options.dart';
import 'package:duruha/shared/user/data/dialect_repository.dart';
import 'package:duruha/features/consumer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/user/data/location_repository.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  final ConsumerProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _segmentSizeController;
  late TextEditingController _barangayController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _landmarkController;
  late TextEditingController _postalCodeController;

  // New State Variables
  late List<String> _selectedDialect;
  late String _consumerSegment;
  late String _cookingFrequency;
  late List<String> _qualityPreferences;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;

  bool _isLoading = false;
  List<String> _dialectOptions = [
    'Bisaya',
    'Tagalog',
    'Cebuano',
    'Hiligaynon',
    'Ilocano',
  ]; // Default mock

  final List<String> _consumerSegmentOptions = ConsumerOptions.segments;
  final List<String> _cookingFrequencyOptions =
      ConsumerOptions.cookingFrequency;
  final List<String> _qualityPreferenceOptions =
      QualityPreferences.qualityPreferences;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeState();
    _loadDialects();
  }

  Future<void> _loadDialects() async {
    try {
      final dialects = await fetchAllDialectNames();
      if (mounted && dialects.isNotEmpty) {
        setState(() {
          _dialectOptions = dialects;
        });
      }
    } catch (e) {
      debugPrint('Error loading dialects: $e');
    }
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.profile.name);
    _emailController = TextEditingController(text: widget.profile.email ?? '');
    _phoneController = TextEditingController(text: widget.profile.phone);
    _segmentSizeController = TextEditingController(
      text: (widget.profile.segmentSize ?? 1).toString(),
    );
    _barangayController = TextEditingController(text: widget.profile.barangay);
    _cityController = TextEditingController(text: widget.profile.city);
    _provinceController = TextEditingController(text: widget.profile.province);
    _landmarkController = TextEditingController(text: widget.profile.landmark);
    _postalCodeController = TextEditingController(
      text: widget.profile.postalCode,
    );
  }

  void _initializeState() {
    _selectedDialect = List.from(widget.profile.dialect);
    _consumerSegment = widget.profile.consumerSegment ?? 'Household';
    _cookingFrequency = widget.profile.cookingFrequency ?? 'Daily';
    _qualityPreferences = List.from(widget.profile.qualityPreferences);
    _latitude = widget.profile.latitude;
    _longitude = widget.profile.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _segmentSizeController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _landmarkController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _toggleSelection(
    List<String> list,
    String item,
    Function(List<String>) onUpdate,
  ) {
    final newList = List<String>.from(list);
    if (newList.contains(item)) {
      newList.remove(item);
    } else {
      newList.add(item);
    }
    onUpdate(newList);
  }

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      final position = await determinePosition();
      if (mounted && position != null) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        DuruhaSnackBar.showSuccess(context, "Location captured!");
      }
    } catch (e) {
      if (mounted) {
        DuruhaSnackBar.showError(context, "Location Error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedProfile = widget.profile.copyWith(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        barangay: _barangayController.text,
        city: _cityController.text,
        province: _provinceController.text,
        landmark: _landmarkController.text,
        postalCode: _postalCodeController.text,
        dialect: _selectedDialect,
        consumerSegment: _consumerSegment,
        segmentSize: int.tryParse(_segmentSizeController.text),
        cookingFrequency: _cookingFrequency,
        qualityPreferences: _qualityPreferences,
        latitude: _latitude,
        longitude: _longitude,
      );

      await ConsumerProfileRepositoryImpl().updateProfile(updatedProfile);

      if (mounted) {
        DuruhaSnackBar.showSuccess(context, "Profile updated successfully!");
        Navigator.pop(context, updatedProfile);
      }
    } catch (e) {
      if (mounted) {
        DuruhaSnackBar.showError(context, "Failed to update profile: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'Edit Profile',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- PERSONAL INFO ---
              DuruhaSectionContainer(
                title: "Personal Information",
                children: [
                  DuruhaTextField(
                    controller: _nameController,
                    label: "Full Name",
                    icon: Icons.person,
                    validator: (val) =>
                        val?.isEmpty == true ? "Required" : null,
                  ),
                  DuruhaTextField(
                    controller: _emailController,
                    label: "Email Address",
                    icon: Icons.email,
                  ),
                  DuruhaTextField(
                    controller: _phoneController,
                    label: "Phone Number",
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (val) =>
                        val?.isEmpty == true ? "Required" : null,
                  ),
                  DuruhaSelectionChipGroup(
                    title: 'Preferred Dialect',
                    options: _dialectOptions,
                    isNumbered: true,
                    selectedValues: _selectedDialect,
                    onToggle: (val) => _toggleSelection(
                      _selectedDialect,
                      val,
                      (newList) => setState(() => _selectedDialect = newList),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- CONSUMER DETAILS ---
              DuruhaSectionContainer(
                title: "Consumer Details",
                children: [
                  const SizedBox(height: 16),
                  DuruhaDropdown(
                    label: 'Consumer TYPE',
                    value: _consumerSegment,
                    items: _consumerSegmentOptions,
                    itemIcons: const {
                      'Household': Icons.home_outlined,
                      'Restaurant': Icons.restaurant,
                      'Catering': Icons.room_service_outlined,
                      'Small Business': Icons.storefront,
                    },
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _consumerSegment = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DuruhaTextField(
                    controller: _segmentSizeController,
                    label: "Household / Group Size",
                    icon: Icons.people_outline,
                    keyboardType: TextInputType.number,
                  ),
                  DuruhaDropdown(
                    label: 'Cooking Frequency',
                    value: _cookingFrequency,
                    items: _cookingFrequencyOptions,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _cookingFrequency = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DuruhaSelectionChipGroup(
                    title: "Quality Preferences",
                    subtitle: "What matters most to you?",
                    options: _qualityPreferenceOptions,
                    selectedValues: _qualityPreferences,
                    onToggle: (val) => _toggleSelection(
                      _qualityPreferences,
                      val,
                      (newList) =>
                          setState(() => _qualityPreferences = newList),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- ADDRESS ---
              DuruhaSectionContainer(
                title: "Address",
                children: [
                  const SizedBox(height: 16),
                  DuruhaTextField(
                    controller: _provinceController,
                    label: "Province",
                    icon: Icons.map,
                    validator: (val) =>
                        val?.isEmpty == true ? "Required" : null,
                  ),
                  DuruhaTextField(
                    controller: _cityController,
                    label: "City / Municipality",
                    icon: Icons.location_city,
                    validator: (val) =>
                        val?.isEmpty == true ? "Required" : null,
                  ),
                  DuruhaTextField(
                    controller: _barangayController,
                    label: "Barangay",
                    icon: Icons.holiday_village,
                    validator: (val) =>
                        val?.isEmpty == true ? "Required" : null,
                  ),
                  DuruhaTextField(
                    controller: _landmarkController,
                    label: "Landmark / Street",
                    icon: Icons.place,
                    validator: (val) =>
                        val?.isEmpty == true ? "Required" : null,
                  ),
                  DuruhaTextField(
                    controller: _postalCodeController,
                    label: "Postal Code",
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    validator: (val) =>
                        val?.isEmpty == true ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "GPS Coordinates",
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              _latitude != null && _longitude != null
                                  ? "${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}"
                                  : "Not set",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (_isLocating)
                        const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton.icon(
                          onPressed: _captureLocation,
                          icon: Icon(
                            Icons.my_location,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          label: Text(
                            _latitude != null ? "Update" : "Capture",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 48),
              DuruhaButton(
                text: "Save Changes",
                isLoading: _isLoading,
                onPressed: _saveProfile,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
