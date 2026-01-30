import 'package:duruha/widgets/duruha_selection_card.dart';
import 'package:flutter/material.dart';

class RoleSelectionStep extends StatelessWidget {
  final String? selectedRole;
  final ValueChanged<String> onRoleSelected;

  const RoleSelectionStep({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
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
                DuruhaSelectionCard(
                  title: "I am a Consumer",
                  subtitle: "I want fresh, farm-to-table food.",
                  icon: Icons.shopping_basket_outlined,
                  isSelected: selectedRole == "Consumer",
                  isList: true,
                  onTap: () => onRoleSelected("Consumer"),
                ),
                const SizedBox(height: 12),
                DuruhaSelectionCard(
                  title: "I am a Farmer",
                  subtitle: "I want to sell my harvest directly.",
                  icon: Icons.agriculture_outlined,
                  isSelected: selectedRole == "Farmer",
                  isList: true,
                  onTap: () => onRoleSelected("Farmer"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
