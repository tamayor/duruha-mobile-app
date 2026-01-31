class FarmerSharedRepository {
  Future<String> getUserDialect() async {
    // Simulate API call to fetch user settings or profile
    await Future.delayed(const Duration(milliseconds: 300));

    // Return mock dialect
    return "Cebuano";
  }
}
