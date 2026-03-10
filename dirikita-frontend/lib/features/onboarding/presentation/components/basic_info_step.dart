import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class BasicInfoStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController telephoneController;
  final TextEditingController streetAddressController;
  final TextEditingController cityController;
  final TextEditingController provinceController;
  final TextEditingController postalCodeController;
  final TextEditingController landmarkController;

  final List<String> dialectOptions;
  final List<String> selectedDialects;
  final Function(String) onDialectToggle;

  final List<String> operatingDaysOptions;
  final List<String> selectedOperatingDays;
  final Function(String) onOperatingDayToggle;

  final List<String> deliveryWindowOptions;
  final String? selectedDeliveryWindow;
  final ValueChanged<String?> onDeliveryWindowChanged;
  final double? latitude;
  final double? longitude;
  final bool isLocating;
  final VoidCallback onCaptureLocation;

  const BasicInfoStep({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.telephoneController,
    required this.streetAddressController,
    required this.cityController,
    required this.provinceController,
    required this.postalCodeController,
    required this.landmarkController,
    required this.dialectOptions,
    required this.selectedDialects,
    required this.onDialectToggle,
    required this.operatingDaysOptions,
    required this.selectedOperatingDays,
    required this.onOperatingDayToggle,
    required this.deliveryWindowOptions,
    required this.selectedDeliveryWindow,
    required this.onDeliveryWindowChanged,
    this.latitude,
    this.longitude,
    required this.isLocating,
    required this.onCaptureLocation,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                DuruhaSectionContainer(
                  title: "Personal Details",
                  children: [
                    DuruhaTextField(
                      controller: nameController,
                      label: "Full Name",
                      icon: Icons.person_outline,
                    ),
                    DuruhaTextField(
                      controller: phoneController,
                      label: "Mobile Number",
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    DuruhaTextField(
                      controller: telephoneController,
                      label: "Telephone Number (Optional)",
                      icon: Icons.phone_in_talk_outlined,
                      keyboardType: TextInputType.phone,
                      isRequired: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                DuruhaSectionContainer(
                  title: "Address",
                  children: [
                    DuruhaTextField(
                      controller: streetAddressController,
                      label: "House No., Street Name, Subdivision",
                      icon: Icons.home_outlined,
                    ),
                    DuruhaTextField(
                      controller: cityController,
                      label: "City / Municipality",
                      icon: Icons.location_city_outlined,
                    ),
                    DuruhaTextField(
                      controller: postalCodeController,
                      label: "Postal Code",
                      icon: Icons.markunread_mailbox_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    DuruhaTextField(
                      controller: provinceController,
                      label: "Province",
                      icon: Icons.map_outlined,
                    ),
                    DuruhaTextField(
                      controller: landmarkController,
                      label: "Nearby Landmark",
                      icon: Icons.place_outlined,
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
                                latitude != null && longitude != null
                                    ? "${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}"
                                    : "Not set",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (isLocating)
                          const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          TextButton.icon(
                            onPressed: onCaptureLocation,
                            icon: Icon(
                              Icons.my_location,
                              size: 18,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            label: Text(
                              latitude != null ? "Update" : "Capture",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                DuruhaSectionContainer(
                  title: "Preferences",
                  children: [
                    DuruhaSelectionChipGroup(
                      title: "Language / Dialect",
                      isRequired: true,
                      isNumbered: true,
                      subtitle:
                          "Select in order of proficiency (1st is primary)",
                      options: dialectOptions,
                      selectedValues: selectedDialects,
                      onToggle: onDialectToggle,
                    ),
                    const SizedBox(height: 24),
                    DuruhaSelectionChipGroup(
                      title: "Active / Operating Days",
                      isRequired: true,
                      subtitle: "Days you are available for delivery/pickup",
                      options: operatingDaysOptions,
                      selectedValues: selectedOperatingDays,
                      onToggle: onOperatingDayToggle,
                    ),
                    const SizedBox(height: 24),
                    DuruhaDropdown(
                      label: "Preferred Window",
                      isRequired: true,
                      value: selectedDeliveryWindow,
                      prefixIcon: Icons.schedule_outlined,
                      items: deliveryWindowOptions,
                      onChanged: onDeliveryWindowChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 100), // Spacing for bottom bar
        ],
      ),
    );
  }
}
