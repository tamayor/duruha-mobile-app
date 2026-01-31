import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class BasicInfoStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController telephoneController;
  final TextEditingController streetAddressController;
  final TextEditingController barangayController;
  final TextEditingController cityController;
  final TextEditingController provinceController;
  final TextEditingController postalCodeController;
  final TextEditingController landmarkController;

  final List<String> dialectOptions;
  final List<String> selectedDialects;
  final Function(String) onDialectToggle;

  final List<String> paymentMethodOptions;
  final List<String> selectedPaymentMethods;
  final Function(String) onPaymentMethodToggle;

  final List<String> operatingDaysOptions;
  final List<String> selectedOperatingDays;
  final Function(String) onOperatingDayToggle;

  final List<String> deliveryWindowOptions;
  final String? selectedDeliveryWindow;
  final ValueChanged<String?> onDeliveryWindowChanged;

  const BasicInfoStep({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.telephoneController,
    required this.streetAddressController,
    required this.barangayController,
    required this.cityController,
    required this.provinceController,
    required this.postalCodeController,
    required this.landmarkController,
    required this.dialectOptions,
    required this.selectedDialects,
    required this.onDialectToggle,
    required this.paymentMethodOptions,
    required this.selectedPaymentMethods,
    required this.onPaymentMethodToggle,
    required this.operatingDaysOptions,
    required this.selectedOperatingDays,
    required this.onOperatingDayToggle,
    required this.deliveryWindowOptions,
    required this.selectedDeliveryWindow,
    required this.onDeliveryWindowChanged,
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
                      controller: emailController,
                      label: "Email Address (Optional)",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      isRequired: false,
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
                      controller: barangayController,
                      label: "Barangay",
                      icon: Icons.holiday_village_outlined,
                    ),
                    DuruhaTextField(
                      controller: cityController,
                      label: "City / Municipality",
                      icon: Icons.location_city_outlined,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DuruhaTextField(
                            controller: postalCodeController,
                            label: "Postal Code",
                            icon: Icons.markunread_mailbox_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DuruhaTextField(
                            controller: provinceController,
                            label: "Province",
                            icon: Icons.map_outlined,
                          ),
                        ),
                      ],
                    ),
                    DuruhaTextField(
                      controller: landmarkController,
                      label: "Nearby Landmark",
                      icon: Icons.place_outlined,
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
                      title: "Payment Method",
                      subtitle: "Select all that apply",
                      isRequired: true,
                      options: paymentMethodOptions,
                      selectedValues: selectedPaymentMethods,
                      onToggle: onPaymentMethodToggle,
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
