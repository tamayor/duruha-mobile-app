import 'package:duruha/core/constants/consumer_options.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/profile/data/profile_repository.dart';
import 'package:duruha/features/consumer/features/profile/domain/profile_model.dart';
import 'package:duruha/features/consumer/features/tx/data/transaction_repository.dart';
import 'package:duruha/shared/user/data/dialect_repository.dart';
import 'package:duruha/shared/user/data/location_repository.dart';
import 'package:duruha/shared/user/domain/user_address_model.dart';
import 'package:duruha/supabase_config.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  final ConsumerProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ConsumerProfileRepositoryImpl();
  final _txRepo = TransactionRepository();

  // ── Text Controllers ────────────────────────────────────────────────────────
  late final _nameController = TextEditingController(text: widget.profile.name);
  late final _emailController = TextEditingController(
    text: widget.profile.email ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.profile.phone ?? '',
  );
  late final _segmentSizeController = TextEditingController(
    text: (widget.profile.segmentSize ?? 1).toString(),
  );

  // ── State ───────────────────────────────────────────────────────────────────
  late List<String> _selectedDialect;
  late String _consumerSegment;
  late String _cookingFrequency;
  String? _currentImageUrl;

  bool _isLoading = false;

  // ── Address state ───────────────────────────────────────────────────────────
  List<UserAddress> _addresses = [];
  bool _addressesLoading = true;
  String? _activeAddressId;
  String? _editingAddressId;
  final _addrFormKey = GlobalKey<FormState>();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _gpsCtrl = TextEditingController();
  double? _editLat;
  double? _editLng;
  bool _isLocating = false;
  bool _isSavingAddr = false;
  bool _setAsMain = false;

  // ── Options ─────────────────────────────────────────────────────────────────
  List<String> _dialectOptions = [
    'Bisaya',
    'Tagalog',
    'Cebuano',
    'Hiligaynon',
    'Ilocano',
  ];

  final List<String> _consumerSegmentOptions = ConsumerOptions.segments;
  final List<String> _cookingFrequencyOptions = ConsumerOptions.cookingFrequency;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedDialect = List.from(widget.profile.dialect);
    _consumerSegment = widget.profile.consumerSegment ?? 'Household';
    _cookingFrequency = widget.profile.cookingFrequency ?? 'Daily';
    _activeAddressId = widget.profile.addressId;
    _currentImageUrl = widget.profile.imageUrl;
    _loadDialectOptions();
    _loadAddresses();
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
    _segmentSizeController.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _regionCtrl.dispose();
    _countryCtrl.dispose();
    _landmarkCtrl.dispose();
    _postalCtrl.dispose();
    _gpsCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  List<String> _toggled(List<String> current, String item) =>
      current.contains(item)
          ? current.where((v) => v != item).toList()
          : [...current, item];

  // ── Address edit helpers ─────────────────────────────────────────────────────

  void _startEditing(UserAddress addr) {
    _line1Ctrl.text = addr.addressLine1 ?? '';
    _line2Ctrl.text = addr.addressLine2 ?? '';
    _cityCtrl.text = addr.city ?? '';
    _provinceCtrl.text = addr.province ?? '';
    _regionCtrl.text = addr.region ?? '';
    _countryCtrl.text = addr.country ?? '';
    _landmarkCtrl.text = addr.landmark ?? '';
    _postalCtrl.text = addr.postalCode ?? '';
    _editLat = addr.latitude;
    _editLng = addr.longitude;
    _gpsCtrl.text = (_editLat != null && _editLng != null)
        ? '${_editLat!.toStringAsFixed(7)}, ${_editLng!.toStringAsFixed(7)}'
        : '';
    _setAsMain = addr.addressId == _activeAddressId;
    setState(() => _editingAddressId = addr.addressId);
  }

  void _startAddNew() {
    _line1Ctrl.clear();
    _line2Ctrl.clear();
    _cityCtrl.clear();
    _provinceCtrl.clear();
    _regionCtrl.clear();
    _countryCtrl.clear();
    _landmarkCtrl.clear();
    _postalCtrl.clear();
    _gpsCtrl.clear();
    _editLat = null;
    _editLng = null;
    _setAsMain = true;
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
          _gpsCtrl.text = '${pos.latitude.toStringAsFixed(7)}, ${pos.longitude.toStringAsFixed(7)}';
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
    
    final gpsText = _gpsCtrl.text.trim();
    if (gpsText.isNotEmpty) {
      final parts = gpsText.split(',');
      if (parts.length == 2) {
        _editLat = double.tryParse(parts[0].trim()) ?? _editLat;
        _editLng = double.tryParse(parts[1].trim()) ?? _editLng;
      }
    } else {
      _editLat = null;
      _editLng = null;
    }

    try {
      final isNew = _editingAddressId == 'new';

      final saved = await _txRepo.upsertUserAddress(
        UserAddress(
          addressId: isNew ? '' : _editingAddressId!,
          createdAt: DateTime.now(),
          addressLine1: _line1Ctrl.text.trim(),
          addressLine2: _line2Ctrl.text.trim(),
          city: _cityCtrl.text.trim(),
          province: _provinceCtrl.text.trim(),
          region: _regionCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          landmark: _landmarkCtrl.text.trim(),
          postalCode: _postalCtrl.text.trim(),
          latitude: _editLat,
          longitude: _editLng,
        ),
        setAsActive: _setAsMain,
      );

      if (saved != null && mounted) {
        if (_setAsMain) {
          await SessionService.saveAddressId(saved.addressId);
          setState(() => _activeAddressId = saved.addressId);
        } else if (_activeAddressId == null) {
          await _setActiveAddress(saved.addressId);
        }
        await _loadAddresses();
        if (!mounted) return;
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

  Future<void> _setActiveAddress(String addressId) async {
    await supabase.rpc(
      'manage_profile',
      params: {
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
      final result = await supabase.rpc(
        'manage_profile',
        params: {
          'p_mode': 'delete_address',
          'p_data': {'address_id': addr.addressId},
        },
      );
      final newActiveId = result['new_active_address_id'] as String?;
      if (mounted) {
        await SessionService.saveAddressId(newActiveId);
        setState(() {
          _activeAddressId = newActiveId;
          if (_editingAddressId == addr.addressId) _editingAddressId = null;
        });
        await _loadAddresses();
        if (mounted) DuruhaSnackBar.showSuccess(context, 'Address deleted.');
      }
    } catch (e) {
      if (mounted) DuruhaSnackBar.showError(context, 'Failed to delete: $e');
    } finally {
      if (mounted) setState(() => _isSavingAddr = false);
    }
  }

  // ── Save profile ─────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final updated = widget.profile.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        dialect: _selectedDialect,
        consumerSegment: _consumerSegment,
        segmentSize: int.tryParse(_segmentSizeController.text),
        cookingFrequency: _cookingFrequency,
        addressId: _activeAddressId,
        imageUrl: _currentImageUrl,
      );

      await _repo.updateProfile(updated);
      await SessionService.saveUser(updated);

      final userId = await SessionService.getUserId();
      if (userId != null) await SessionService.syncProfile(userId);

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

  // ── Build ─────────────────────────────────────────────────────────────────────
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
              // ── Personal Info ──────────────────────────────────────────────
              DuruhaSectionContainer(
                title: 'Personal Information',
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: DuruhaUserProfile(
                        imageUrl: _currentImageUrl,
                        userName: _nameController.text,
                        radius: 50.0,
                        allowUpload: true,
                        bucketName: 'avatars',
                        onImageUploaded: (newImageUrl) async {
                          final bustedUrl =
                              '$newImageUrl?t=${DateTime.now().millisecondsSinceEpoch}';
                          if (mounted) {
                            setState(() => _currentImageUrl = bustedUrl);
                          }
                          await _repo.updateProfile(
                            widget.profile.copyWith(imageUrl: bustedUrl),
                          );
                          await SessionService.saveUser(
                            widget.profile.copyWith(imageUrl: bustedUrl),
                          );
                        },
                      ),
                    ),
                  ),
                  DuruhaTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_rounded,
                    onChanged: (v) => setState(() {}),
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
                    isNumbered: true,
                    selectedValues: _selectedDialect,
                    onToggle: (val) => setState(
                      () => _selectedDialect = _toggled(_selectedDialect, val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Consumer Details ───────────────────────────────────────────
              DuruhaSectionContainer(
                title: 'Consumer Details',
                children: [
                  const SizedBox(height: 8),
                  DuruhaDropdown(
                    label: 'Consumer Type',
                    value: _consumerSegment,
                    items: _consumerSegmentOptions,
                    itemIcons: const {
                      'Household': Icons.home_outlined,
                      'Restaurant': Icons.restaurant,
                      'Catering': Icons.room_service_outlined,
                      'Small Business': Icons.storefront,
                    },
                    onChanged: (v) {
                      if (v != null) setState(() => _consumerSegment = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  DuruhaTextField(
                    controller: _segmentSizeController,
                    label: 'Household / Group Size',
                    icon: Icons.people_outline,
                    keyboardType: TextInputType.number,
                  ),
                  DuruhaDropdown(
                    label: 'Cooking Frequency',
                    value: _cookingFrequency,
                    items: _cookingFrequencyOptions,
                    onChanged: (v) {
                      if (v != null) setState(() => _cookingFrequency = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Addresses ──────────────────────────────────────────────────
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
                regionCtrl: _regionCtrl,
                countryCtrl: _countryCtrl,
                landmarkCtrl: _landmarkCtrl,
                postalCtrl: _postalCtrl,
                gpsCtrl: _gpsCtrl,
                isLocating: _isLocating,
                isSavingAddr: _isSavingAddr,
                setAsMain: _setAsMain,
                onSetActive: _setActiveAddress,
                onStartEdit: _startEditing,
                onStartAddNew: _startAddNew,
                onCancelEdit: _cancelEdit,
                onSaveAddress: _saveAddress,
                onDeleteAddress: _deleteAddress,
                onCaptureLocation: _captureLocation,
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

// ─── Address Section ───────────────────────────────────────────────────────────

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
  final TextEditingController regionCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController landmarkCtrl;
  final TextEditingController postalCtrl;
  final TextEditingController gpsCtrl;
  final bool isLocating;
  final bool isSavingAddr;
  final bool setAsMain;
  final Future<void> Function(String) onSetActive;
  final void Function(UserAddress) onStartEdit;
  final VoidCallback onStartAddNew;
  final VoidCallback onCancelEdit;
  final Future<void> Function() onSaveAddress;
  final Future<void> Function(UserAddress) onDeleteAddress;
  final Future<void> Function() onCaptureLocation;
  final ValueChanged<bool> onToggleMain;

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
    required this.regionCtrl,
    required this.countryCtrl,
    required this.landmarkCtrl,
    required this.postalCtrl,
    required this.gpsCtrl,
    required this.isLocating,
    required this.isSavingAddr,
    required this.setAsMain,
    required this.onSetActive,
    required this.onStartEdit,
    required this.onStartAddNew,
    required this.onCancelEdit,
    required this.onSaveAddress,
    required this.onDeleteAddress,
    required this.onCaptureLocation,
    required this.onToggleMain,
  });

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
          ...addresses.map((addr) {
            final isActive = addr.addressId == activeAddressId;
            final isEditing = addr.addressId == editingAddressId;

            return Column(
              key: ValueKey(addr.addressId),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        contentPadding:
                            const EdgeInsets.fromLTRB(12, 4, 4, 4),
                        leading: Icon(
                          isActive
                              ? Icons.location_on
                              : Icons.location_on_outlined,
                          color: isActive
                              ? scheme.onPrimary
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (addr.landmark != null && addr.landmark!.isNotEmpty)
                              Text(
                                addr.landmark!,
                                style: theme.textTheme.bodySmall,
                              ),
                            if (addr.latitude != null && addr.longitude != null)
                              Text(
                                'GPS: ${addr.latitude!.toStringAsFixed(5)}, ${addr.longitude!.toStringAsFixed(5)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSecondary,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isEditing
                                    ? Icons.close
                                    : Icons.edit_outlined,
                                size: 18,
                              ),
                              tooltip: isEditing ? 'Cancel' : 'Edit',
                              onPressed: isEditing
                                  ? onCancelEdit
                                  : () => onStartEdit(addr),
                            ),
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
                      if (!isActive)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => onSetActive(addr.addressId),
                              icon: Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: scheme.onSecondary,
                              ),
                              label: Text(
                                'Set as active',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSecondary,
                                ),
                              ),
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
                              labelStyle:
                                  theme.textTheme.labelSmall?.copyWith(
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
                if (isEditing) ...[
                  const SizedBox(height: 8),
                  _AddressEditForm(
                    formKey: addrFormKey,
                    line1Ctrl: line1Ctrl,
                    line2Ctrl: line2Ctrl,
                    cityCtrl: cityCtrl,
                    provinceCtrl: provinceCtrl,
                    regionCtrl: regionCtrl,
                    countryCtrl: countryCtrl,
                    landmarkCtrl: landmarkCtrl,
                    postalCtrl: postalCtrl,
                    gpsCtrl: gpsCtrl,
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
            Text(
              'New Address',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _AddressEditForm(
              formKey: addrFormKey,
              line1Ctrl: line1Ctrl,
              line2Ctrl: line2Ctrl,
              cityCtrl: cityCtrl,
              provinceCtrl: provinceCtrl,
              regionCtrl: regionCtrl,
              countryCtrl: countryCtrl,
              landmarkCtrl: landmarkCtrl,
              postalCtrl: postalCtrl,
              gpsCtrl: gpsCtrl,
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
                color: scheme.onSecondary,
              ),
              label: Text(
                'Add New Address',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Address Edit Form ─────────────────────────────────────────────────────────

class _AddressEditForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController line1Ctrl;
  final TextEditingController line2Ctrl;
  final TextEditingController cityCtrl;
  final TextEditingController provinceCtrl;
  final TextEditingController regionCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController landmarkCtrl;
  final TextEditingController postalCtrl;
  final TextEditingController gpsCtrl;
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
    required this.regionCtrl,
    required this.countryCtrl,
    required this.landmarkCtrl,
    required this.postalCtrl,
    required this.gpsCtrl,
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
    final scheme = theme.colorScheme;

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
            controller: regionCtrl,
            label: 'Region',
            icon: Icons.public_rounded,
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          DuruhaTextField(
            controller: countryCtrl,
            label: 'Country',
            icon: Icons.flag_rounded,
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
            label: 'Landmark',
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DuruhaTextField(
                  controller: gpsCtrl,
                  label: 'GPS Coordinates',
                  helperText: 'e.g. 14.5995, 120.9842',
                  icon: Icons.gps_fixed_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: isLocating
                    ? const SizedBox(
                        height: 48,
                        width: 48,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        onPressed: onCapture,
                        icon: Icon(Icons.my_location_rounded,
                            color: scheme.primary),
                        tooltip: 'Capture GPS',
                      ),
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
