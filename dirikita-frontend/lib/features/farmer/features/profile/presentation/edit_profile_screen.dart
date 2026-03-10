import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/user/data/dialect_repository.dart';
import 'package:duruha/features/farmer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/farmer/features/profile/domain/profile_model.dart';
import 'package:duruha/shared/user/data/location_repository.dart';
import 'package:duruha/features/consumer/features/tx/data/transaction_repository.dart';
import 'package:duruha/shared/user/domain/user_address_model.dart';
import 'package:duruha/supabase_config.dart';
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
  final _txRepo = TransactionRepository();

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

  // ── State ─────────────────────────────────────────────────────────────────
  late List<String> _selectedDialect;
  late String _accessibility;
  late List<String> _waterSources;
  late List<String> _operatingDays;
  late String _deliveryWindow;

  bool _isLoading = false;

  // ── Address state ─────────────────────────────────────────────────────────
  List<UserAddress> _addresses = [];
  bool _addressesLoading = true;
  String? _activeAddressId;
  // Which address is being edited inline (null = none / "new" = add form)
  String? _editingAddressId;
  final _addrFormKey = GlobalKey<FormState>();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  double? _editLat;
  double? _editLng;
  bool _isLocating = false;
  bool _isSavingAddr = false;
  bool _setAsMain = false;

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
    _selectedDialect = List.from(widget.profile.dialect);
    _accessibility = widget.profile.accessibilityType.isNotEmpty
        ? widget.profile.accessibilityType
        : _accessibilityOptions.first;
    _waterSources = List.from(widget.profile.waterSources);
    _operatingDays = List.from(widget.profile.operatingDays);
    _deliveryWindow = widget.profile.deliveryWindow.isNotEmpty
        ? widget.profile.deliveryWindow
        : _deliveryWindowOptions.first;
    _activeAddressId = widget.profile.addressId;

    _initDialect();
    _loadDialectOptions();
    _loadAddresses();
  }

  Future<void> _initDialect() async {
    if (_selectedDialect.isEmpty) {
      final saved = await SessionService.getUserDialects();
      if (mounted && saved.isNotEmpty) setState(() => _selectedDialect = saved);
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

  Future<void> _loadAddresses() async {
    setState(() => _addressesLoading = true);
    try {
      final list = await _txRepo.fetchAllUserAddresses();
      if (mounted) {
        setState(() {
          // Exclude the virtual 'profile' fallback address — we manage real rows only
          _addresses = list.where((a) => a.addressId != 'profile').toList();
          _addressesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _addressesLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _farmAliasController.dispose();
    _landAreaController.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _landmarkCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<String> _toggled(List<String> current, String item) =>
      current.contains(item)
      ? current.where((v) => v != item).toList()
      : [...current, item];

  // ── Address edit form helpers ─────────────────────────────────────────────

  void _startEditing(UserAddress addr) {
    _line1Ctrl.text = addr.addressLine1 ?? '';
    _line2Ctrl.text = addr.addressLine2 ?? '';
    _cityCtrl.text = addr.city ?? '';
    _provinceCtrl.text = addr.province ?? '';
    _landmarkCtrl.text = addr.landmark ?? '';
    _postalCtrl.text = addr.postalCode ?? '';
    _editLat = addr.latitude;
    _editLng = addr.longitude;
    _setAsMain = addr.addressId == _activeAddressId;
    setState(() => _editingAddressId = addr.addressId);
  }

  void _startAddNew() {
    _line1Ctrl.clear();
    _line2Ctrl.clear();
    _cityCtrl.clear();
    _provinceCtrl.clear();
    _landmarkCtrl.clear();
    _postalCtrl.clear();
    _editLat = null;
    _editLng = null;
    _setAsMain = true; // Default to true for new addresses if user wants
    setState(() => _editingAddressId = 'new');
  }

  void _cancelEdit() => setState(() => _editingAddressId = null);

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      final pos = await determinePosition();
      if (mounted && pos != null) {
        setState(() {
          _editLat = pos.latitude;
          _editLng = pos.longitude;
        });
        if (mounted) DuruhaSnackBar.showSuccess(context, 'Location captured!');
      }
    } catch (e) {
      if (mounted) DuruhaSnackBar.showError(context, 'Location error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_addrFormKey.currentState!.validate()) return;
    setState(() => _isSavingAddr = true);
    try {
      final isNew = _editingAddressId == 'new';

      if (isNew) {
        // Insert new row in users_addresses
        final created = await _txRepo.createUserAddress(
          UserAddress(
            addressId: 'new',
            createdAt: DateTime.now(),
            addressLine1: _line1Ctrl.text.trim(),
            addressLine2: _line2Ctrl.text.trim(),
            city: _cityCtrl.text.trim(),
            province: _provinceCtrl.text.trim(),
            landmark: _landmarkCtrl.text.trim(),
            postalCode: _postalCtrl.text.trim(),
            latitude: _editLat,
            longitude: _editLng,
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
        // Update the existing address row via manage_profile update mode
        final userId = await SessionService.getUserId();
        if (userId == null) return;
        // Build a minimal profile copy with only address fields + the address_id
        final profileWithAddr = widget.profile.copyWith(
          addressId: _editingAddressId,
          addressLine1: _line1Ctrl.text.trim(),
          addressLine2: _line2Ctrl.text.trim(),
          city: _cityCtrl.text.trim(),
          province: _provinceCtrl.text.trim(),
          landmark: _landmarkCtrl.text.trim(),
          postalCode: _postalCtrl.text.trim(),
          latitude: _editLat,
          longitude: _editLng,
        );
        await _repo.updateProfile(profileWithAddr);
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

  Future<void> _reloadAndMaybeActivate(String? addressId) async {
    await _loadAddresses();
    // If user has no active address yet, auto-activate this one
    if (_activeAddressId == null && addressId != null) {
      await _setActiveAddress(addressId);
    }
  }

  Future<void> _setActiveAddress(String addressId) async {
    final userId = await SessionService.getUserId();
    if (userId == null) return;
    // Update users.address_id via manage_profile (address fields omitted → only address_id written)
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
      final newActiveId = await _repo.deleteAddress(userId, addr.addressId);
      if (mounted) {
        // Update cached address_id in shared prefs
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

  // ── Save profile (non-address fields) ────────────────────────────────────
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
        dialect: _selectedDialect,
        accessibilityType: _accessibility,
        waterSources: _waterSources,
        operatingDays: _operatingDays,
        deliveryWindow: _deliveryWindow,
        addressId: _activeAddressId,
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
                    onToggle: (val) => setState(
                      () => _selectedDialect = _toggled(_selectedDialect, val),
                    ),
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
                      if (v == null || v.isEmpty) return null;
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
                    onToggle: (val) => setState(
                      () => _waterSources = _toggled(_waterSources, val),
                    ),
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
                    onToggle: (val) => setState(
                      () => _operatingDays = _toggled(_operatingDays, val),
                    ),
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

              // ── Addresses ─────────────────────────────────────────────────
              _AddressSection(
                addresses: _addresses,
                isLoading: _addressesLoading,
                activeAddressId: _activeAddressId,
                editingAddressId: _editingAddressId,
                addrFormKey: _addrFormKey,
                line1Ctrl: _line1Ctrl,
                line2Ctrl: _line2Ctrl,
                cityCtrl: _cityCtrl,
                provinceCtrl: _provinceCtrl,
                landmarkCtrl: _landmarkCtrl,
                postalCtrl: _postalCtrl,
                editLat: _editLat,
                editLng: _editLng,
                isLocating: _isLocating,
                isSavingAddr: _isSavingAddr,
                onSetActive: _setActiveAddress,
                onStartEdit: _startEditing,
                onStartAddNew: _startAddNew,
                onCancelEdit: _cancelEdit,
                onSaveAddress: _saveAddress,
                onDeleteAddress: _deleteAddress,
                onCaptureLocation: _captureLocation,
                setAsMain: _setAsMain,
                onToggleMain: (v) => setState(() => _setAsMain = v),
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

// ─── Address Section ──────────────────────────────────────────────────────────

class _AddressSection extends StatelessWidget {
  final List<UserAddress> addresses;
  final bool isLoading;
  final String? activeAddressId;
  final String? editingAddressId;
  final GlobalKey<FormState> addrFormKey;
  final TextEditingController line1Ctrl;
  final TextEditingController line2Ctrl;
  final TextEditingController cityCtrl;
  final TextEditingController provinceCtrl;
  final TextEditingController landmarkCtrl;
  final TextEditingController postalCtrl;
  final double? editLat;
  final double? editLng;
  final bool isLocating;
  final bool isSavingAddr;
  final Future<void> Function(String) onSetActive;
  final void Function(UserAddress) onStartEdit;
  final VoidCallback onStartAddNew;
  final VoidCallback onCancelEdit;
  final Future<void> Function() onSaveAddress;
  final Future<void> Function(UserAddress) onDeleteAddress;
  final Future<void> Function() onCaptureLocation;

  const _AddressSection({
    required this.addresses,
    required this.isLoading,
    required this.activeAddressId,
    required this.editingAddressId,
    required this.addrFormKey,
    required this.line1Ctrl,
    required this.line2Ctrl,
    required this.cityCtrl,
    required this.provinceCtrl,
    required this.landmarkCtrl,
    required this.postalCtrl,
    required this.editLat,
    required this.editLng,
    required this.isLocating,
    required this.isSavingAddr,
    required this.onSetActive,
    required this.onStartEdit,
    required this.onStartAddNew,
    required this.onCancelEdit,
    required this.onSaveAddress,
    required this.onDeleteAddress,
    required this.onCaptureLocation,
    required this.setAsMain,
    required this.onToggleMain,
  });

  final bool setAsMain;
  final ValueChanged<bool> onToggleMain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DuruhaSectionContainer(
      title: 'Addresses',
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          // ── Address cards ──────────────────────────────────────────────
          ...addresses.map((addr) {
            final isActive = addr.addressId == activeAddressId;
            final isEditing = addr.addressId == editingAddressId;

            return Column(
              key: ValueKey(addr.addressId),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card header row
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive ? scheme.primary : scheme.outlineVariant,
                      width: isActive ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isActive
                        ? scheme.primary.withValues(alpha: 0.05)
                        : scheme.surface,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                        leading: Icon(
                          isActive
                              ? Icons.location_on
                              : Icons.location_on_outlined,
                          color: isActive
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        title: Text(
                          addr.fullAddress.isNotEmpty
                              ? addr.fullAddress
                              : 'No address details',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                            addr.landmark != null && addr.landmark!.isNotEmpty
                            ? Text(
                                addr.landmark!,
                                style: theme.textTheme.bodySmall,
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit
                            IconButton(
                              icon: Icon(
                                isEditing ? Icons.close : Icons.edit_outlined,
                                size: 18,
                              ),
                              tooltip: isEditing ? 'Cancel' : 'Edit',
                              onPressed: isEditing
                                  ? onCancelEdit
                                  : () => onStartEdit(addr),
                            ),
                            // Delete
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              tooltip: 'Delete',
                              onPressed: () => onDeleteAddress(addr),
                            ),
                          ],
                        ),
                      ),
                      // Set as active button
                      if (!isActive)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => onSetActive(addr.addressId),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 14,
                              ),
                              label: const Text('Set as active'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                textStyle: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                        ),
                      if (isActive)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              label: const Text('Active'),
                              labelStyle: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                              ),
                              backgroundColor: scheme.primary,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Inline edit form
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

          // ── Add new address ────────────────────────────────────────────
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
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add New Address'),
            ),
        ],
      ],
    );
  }
}

// ─── Address Edit Form ────────────────────────────────────────────────────────

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

  final bool setAsMain;
  final ValueChanged<bool> onToggleMain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasLocation = latitude != null && longitude != null;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DuruhaTextField(
            controller: line1Ctrl,
            label: 'Address Line 1',
            icon: Icons.location_on_outlined,
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          DuruhaTextField(
            controller: line2Ctrl,
            label: 'Address Line 2 (optional)',
            icon: Icons.location_on_outlined,
          ),
          DuruhaTextField(
            controller: provinceCtrl,
            label: 'Province',
            icon: Icons.map_rounded,
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          DuruhaTextField(
            controller: cityCtrl,
            label: 'City / Municipality',
            icon: Icons.location_city_rounded,
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          DuruhaTextField(
            controller: landmarkCtrl,
            label: 'Landmark / Street',
            icon: Icons.place_rounded,
          ),
          DuruhaTextField(
            controller: postalCtrl,
            label: 'Postal Code',
            icon: Icons.markunread_mailbox_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: setAsMain,
            onChanged: (v) => onToggleMain(v ?? false),
            title: Text(
              'Set as Main Address',
              style: theme.textTheme.bodyMedium,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: scheme.primary,
          ),
          const SizedBox(height: 8),
          // GPS row
          Row(
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
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DuruhaButton(
                  text: 'Cancel',
                  isOutline: true,
                  isSmall: true,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DuruhaButton(
                  text: 'Save Address',
                  isSmall: true,
                  isLoading: isSaving,
                  onPressed: onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
