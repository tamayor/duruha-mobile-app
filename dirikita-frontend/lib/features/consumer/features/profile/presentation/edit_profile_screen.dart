import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/supabase_config.dart';
import 'package:duruha/core/constants/consumer_options.dart';
import 'package:duruha/shared/user/data/dialect_repository.dart';
import 'package:duruha/features/consumer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/user/data/location_repository.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/features/consumer/features/tx/data/transaction_repository.dart';
import 'package:duruha/shared/user/domain/user_address_model.dart';
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
  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _landmarkController;
  late TextEditingController _postalCodeController;

  // New State Variables
  late List<String> _selectedDialect;
  late String _consumerSegment;
  late String _cookingFrequency;
  double? _latitude;
  double? _longitude;
  String? _activeAddressId;
  String? _editingAddressId;
  bool _isLocating = false;
  bool _isSavingAddr = false;
  bool _setAsMain = false;

  bool _isLoading = false;
  bool _addressesLoading = false;
  List<UserAddress> _addresses = [];
  final _txRepo = TransactionRepository();
  final _addrFormKey = GlobalKey<FormState>();
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

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeState();
    _loadDialects();
    _loadAddresses();
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
    _addressLine1Controller = TextEditingController(
      text: widget.profile.addressLine1,
    );
    _addressLine2Controller = TextEditingController(
      text: widget.profile.addressLine2,
    );
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
    _activeAddressId = widget.profile.addressId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _segmentSizeController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _landmarkController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() => _addressesLoading = true);
    try {
      final list = await _txRepo.fetchAllUserAddresses();
      if (mounted) {
        setState(() {
          _addresses = list.where((a) => a.addressId != 'profile').toList();
          _addressesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _addressesLoading = false);
    }
  }

  void _startEditing(UserAddress addr) {
    _addressLine1Controller.text = addr.addressLine1 ?? '';
    _addressLine2Controller.text = addr.addressLine2 ?? '';
    _cityController.text = addr.city ?? '';
    _provinceController.text = addr.province ?? '';
    _landmarkController.text = addr.landmark ?? '';
    _postalCodeController.text = addr.postalCode ?? '';
    _latitude = addr.latitude;
    _longitude = addr.longitude;
    _setAsMain = addr.addressId == _activeAddressId;
    setState(() => _editingAddressId = addr.addressId);
  }

  void _startAddNew() {
    _addressLine1Controller.clear();
    _addressLine2Controller.clear();
    _cityController.clear();
    _provinceController.clear();
    _landmarkController.clear();
    _postalCodeController.clear();
    _latitude = null;
    _longitude = null;
    _setAsMain = true;
    setState(() => _editingAddressId = 'new');
  }

  void _cancelEdit() => setState(() => _editingAddressId = null);

  Future<void> _setActiveAddress(String addressId) async {
    final userId = await SessionService.getUserId();
    if (userId == null) return;
    await supabase.rpc(
      'manage_profile',
      params: {
        'p_user_id': userId,
        'p_mode': 'update',
        'p_data': {'address_id': addressId},
      },
    );
    await SessionService.saveAddressId(addressId);
    if (mounted) setState(() => _activeAddressId = addressId);
  }

  Future<void> _reloadAndMaybeActivate(String? addressId) async {
    await _loadAddresses();
    if (_activeAddressId == null && addressId != null) {
      await _setActiveAddress(addressId);
    }
  }

  Future<void> _saveAddress() async {
    if (!_addrFormKey.currentState!.validate()) return;
    setState(() => _isSavingAddr = true);
    try {
      final isNew = _editingAddressId == 'new';
      if (isNew) {
        final created = await _txRepo.createUserAddress(
          UserAddress(
            addressId: 'new',
            createdAt: DateTime.now(),
            addressLine1: _addressLine1Controller.text.trim(),
            addressLine2: _addressLine2Controller.text.trim(),
            city: _cityController.text.trim(),
            province: _provinceController.text.trim(),
            landmark: _landmarkController.text.trim(),
            postalCode: _postalCodeController.text.trim(),
            latitude: _latitude,
            longitude: _longitude,
          ),
        );
        if (created != null && mounted) {
          if (_setAsMain) {
            await _setActiveAddress(created.addressId);
            await _loadAddresses();
          } else {
            await _reloadAndMaybeActivate(created.addressId);
          }
        }
      } else {
        final userId = await SessionService.getUserId();
        if (userId == null) return;
        final profileWithAddr = widget.profile.copyWith(
          addressId: _editingAddressId,
          addressLine1: _addressLine1Controller.text.trim(),
          addressLine2: _addressLine2Controller.text.trim(),
          city: _cityController.text.trim(),
          province: _provinceController.text.trim(),
          landmark: _landmarkController.text.trim(),
          postalCode: _postalCodeController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
        );
        await ConsumerProfileRepositoryImpl().updateProfile(profileWithAddr);
        if (_setAsMain && _editingAddressId != null) {
          await _setActiveAddress(_editingAddressId!);
        }
        await _loadAddresses();
      }
      if (mounted) {
        setState(() => _editingAddressId = null);
        DuruhaSnackBar.showSuccess(
          context,
          isNew ? 'Address added!' : 'Address updated!',
        );
      }
    } catch (e) {
      if (mounted) DuruhaSnackBar.showError(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _isSavingAddr = false);
    }
  }

  Future<void> _deleteAddress(UserAddress addr) async {
    final ctx = context;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Remove "${addr.fullAddress}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSavingAddr = true);
    try {
      final userId = await SessionService.getUserId();
      if (userId == null) return;

      final newActiveId = await ConsumerProfileRepositoryImpl().deleteAddress(
        userId,
        addr.addressId,
      );

      if (mounted) {
        await SessionService.saveAddressId(newActiveId);
        setState(() => _activeAddressId = newActiveId);
        if (_editingAddressId == addr.addressId) _editingAddressId = null;
        await _loadAddresses();
        if (mounted) DuruhaSnackBar.showSuccess(context, 'Address deleted.');
      }
    } catch (e) {
      if (mounted) DuruhaSnackBar.showError(context, 'Failed to delete: $e');
    } finally {
      if (mounted) setState(() => _isSavingAddr = false);
    }
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
        addressLine1: _addressLine1Controller.text,
        addressLine2: _addressLine2Controller.text,
        city: _cityController.text,
        province: _provinceController.text,
        landmark: _landmarkController.text,
        postalCode: _postalCodeController.text,
        dialect: _selectedDialect,
        consumerSegment: _consumerSegment,
        segmentSize: int.tryParse(_segmentSizeController.text),
        cookingFrequency: _cookingFrequency,
        addressId: _activeAddressId,
      );

      await ConsumerProfileRepositoryImpl().updateProfile(updatedProfile);

      // Explicitly save to local SharedPreferences
      await SessionService.saveUser(updatedProfile);

      final userId = await SessionService.getUserId();
      if (userId != null) {
        await SessionService.syncProfile(userId);
      }

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
                ],
              ),
              const SizedBox(height: 24),

              _AddressSection(
                addresses: _addresses,
                activeAddressId: _activeAddressId,
                editingAddressId: _editingAddressId,
                addressesLoading: _addressesLoading,
                isLocating: _isLocating,
                isSavingAddr: _isSavingAddr,
                addrFormKey: _addrFormKey,
                line1Ctrl: _addressLine1Controller,
                line2Ctrl: _addressLine2Controller,
                cityCtrl: _cityController,
                provinceCtrl: _provinceController,
                landmarkCtrl: _landmarkController,
                postalCtrl: _postalCodeController,
                editLat: _latitude,
                editLng: _longitude,
                onStartEditing: _startEditing,
                onStartAddNew: _startAddNew,
                onCancelEdit: _cancelEdit,
                onSaveAddress: _saveAddress,
                onDeleteAddress: _deleteAddress,
                onCaptureLocation: _captureLocation,
                setAsMain: _setAsMain,
                onToggleMain: (v) => setState(() => _setAsMain = v),
                onActivate: _setActiveAddress,
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

// ─── Address Widgets ─────────────────────────────────────────────────────────

class _AddressSection extends StatelessWidget {
  final List<UserAddress> addresses;
  final String? activeAddressId;
  final String? editingAddressId;
  final bool addressesLoading;
  final bool isLocating;
  final bool isSavingAddr;
  final GlobalKey<FormState> addrFormKey;
  final TextEditingController line1Ctrl;
  final TextEditingController line2Ctrl;
  final TextEditingController cityCtrl;
  final TextEditingController provinceCtrl;
  final TextEditingController landmarkCtrl;
  final TextEditingController postalCtrl;
  final double? editLat;
  final double? editLng;
  final bool setAsMain;

  final void Function(UserAddress) onStartEditing;
  final VoidCallback onStartAddNew;
  final VoidCallback onCancelEdit;
  final Future<void> Function() onSaveAddress;
  final Future<void> Function(UserAddress) onDeleteAddress;
  final Future<void> Function() onCaptureLocation;
  final ValueChanged<bool> onToggleMain;
  final Future<void> Function(String) onActivate;

  const _AddressSection({
    required this.addresses,
    required this.activeAddressId,
    required this.editingAddressId,
    required this.addressesLoading,
    required this.isLocating,
    required this.isSavingAddr,
    required this.addrFormKey,
    required this.line1Ctrl,
    required this.line2Ctrl,
    required this.cityCtrl,
    required this.provinceCtrl,
    required this.landmarkCtrl,
    required this.postalCtrl,
    required this.editLat,
    required this.editLng,
    required this.setAsMain,
    required this.onStartEditing,
    required this.onStartAddNew,
    required this.onCancelEdit,
    required this.onSaveAddress,
    required this.onDeleteAddress,
    required this.onCaptureLocation,
    required this.onToggleMain,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaSectionContainer(
      title: "Saved Addresses",
      children: [
        if (addressesLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          ...addresses.map((addr) {
            final isActive = addr.addressId == activeAddressId;
            final isEditing = addr.addressId == editingAddressId;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: .2)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? theme.colorScheme.primary.withValues(alpha: .5)
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.hintColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addr.fullAddress,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (addr.landmark?.isNotEmpty == true)
                                  Text(
                                    addr.landmark!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Active',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => onDeleteAddress(addr),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                          ),
                          if (!isActive)
                            TextButton(
                              onPressed: () => onActivate(addr.addressId),
                              child: Text(
                                'Make Active',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: () => onStartEditing(addr),
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                color: theme.colorScheme.onSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 8),
                  _AddressEditForm(
                    formKey: addrFormKey,
                    line1Ctrl: line1Ctrl,
                    line2Ctrl: line2Ctrl,
                    cityCtrl: cityCtrl,
                    provinceCtrl: provinceCtrl,
                    landmarkCtrl: landmarkCtrl,
                    postalCtrl: postalCtrl,
                    latitude: editLat,
                    longitude: editLng,
                    isLocating: isLocating,
                    isSaving: isSavingAddr,
                    setAsMain: setAsMain,
                    onToggleMain: onToggleMain,
                    onCapture: onCaptureLocation,
                    onSave: onSaveAddress,
                    onCancel: onCancelEdit,
                  ),
                ],
                const SizedBox(height: 8),
              ],
            );
          }),

          if (editingAddressId == 'new') ...[
            const Divider(),
            Text('New Address', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _AddressEditForm(
              formKey: addrFormKey,
              line1Ctrl: line1Ctrl,
              line2Ctrl: line2Ctrl,
              cityCtrl: cityCtrl,
              provinceCtrl: provinceCtrl,
              landmarkCtrl: landmarkCtrl,
              postalCtrl: postalCtrl,
              latitude: editLat,
              longitude: editLng,
              isLocating: isLocating,
              isSaving: isSavingAddr,
              setAsMain: setAsMain,
              onToggleMain: onToggleMain,
              onCapture: onCaptureLocation,
              onSave: onSaveAddress,
              onCancel: onCancelEdit,
            ),
          ] else
            TextButton.icon(
              onPressed: onStartAddNew,
              icon: Icon(
                Icons.add_location_alt_outlined,
                color: theme.colorScheme.onPrimary,
              ),
              label: Text(
                'Add New Address',
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
        ],
      ],
    );
  }
}

class _AddressEditForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController line1Ctrl;
  final TextEditingController line2Ctrl;
  final TextEditingController cityCtrl;
  final TextEditingController provinceCtrl;
  final TextEditingController landmarkCtrl;
  final TextEditingController postalCtrl;
  final double? latitude;
  final double? longitude;
  final bool isLocating;
  final bool isSaving;
  final bool setAsMain;
  final ValueChanged<bool> onToggleMain;
  final Future<void> Function() onCapture;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;

  const _AddressEditForm({
    required this.formKey,
    required this.line1Ctrl,
    required this.line2Ctrl,
    required this.cityCtrl,
    required this.provinceCtrl,
    required this.landmarkCtrl,
    required this.postalCtrl,
    required this.latitude,
    required this.longitude,
    required this.isLocating,
    required this.isSaving,
    required this.setAsMain,
    required this.onToggleMain,
    required this.onCapture,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            DuruhaTextField(
              controller: line1Ctrl,
              label: "Address Line 1",
              icon: Icons.place_outlined,
              validator: (v) => v?.isEmpty == true ? "Required" : null,
            ),
            DuruhaTextField(
              controller: line2Ctrl,
              label: "Address Line 2 (optional)",
              icon: Icons.place_outlined,
            ),
            DuruhaTextField(
              controller: cityCtrl,
              label: "City",
              icon: Icons.location_city,
              validator: (v) => v?.isEmpty == true ? "Required" : null,
            ),
            DuruhaTextField(
              controller: provinceCtrl,
              label: "Province",
              icon: Icons.map,
              validator: (v) => v?.isEmpty == true ? "Required" : null,
            ),
            DuruhaTextField(
              controller: landmarkCtrl,
              label: "Landmark / Street",
              icon: Icons.place,
              validator: (v) => v?.isEmpty == true ? "Required" : null,
            ),
            DuruhaTextField(
              controller: postalCtrl,
              label: "Postal Code",
              icon: Icons.numbers,
              keyboardType: TextInputType.number,
              validator: (v) => v?.isEmpty == true ? "Required" : null,
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "GPS Coordinates",
                        style: theme.textTheme.labelSmall,
                      ),
                      Text(
                        latitude != null && longitude != null
                            ? "${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}"
                            : "Not set",
                        style: theme.textTheme.bodySmall,
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
                    icon: const Icon(Icons.my_location, size: 16),
                    label: Text(latitude != null ? "Update" : "Capture"),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            CheckboxListTile(
              value: setAsMain,
              onChanged: (v) => onToggleMain(v ?? false),
              title: const Text('Set as main address'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DuruhaButton(
                    text: "Cancel",
                    isOutline: true,
                    isSmall: true,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DuruhaButton(
                    text: "Save Address",
                    isLoading: isSaving,
                    isSmall: true,
                    onPressed: onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
