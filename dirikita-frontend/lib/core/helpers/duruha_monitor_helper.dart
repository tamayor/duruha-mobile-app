class MonitorDataHelper {
  static List<String> getRescheduleReasons() {
    return [
      'Weather Conditions',
      'Pest/Disease Issue',
      'Delayed Maturity',
      'Logistics Issue',
      'Personal/Labor Shortage',
    ];
  }

  static List<String> getInputCategories() {
    return [
      'Seeds',
      'Fertilizer',
      'Pesticide/Chem',
      'Labor',
      'Equipment/Tools',
      'Fuel',
      'Water/Irrigation',
      'Others',
    ];
  }

  static List<String> getPledgeStatuses() {
    return [
      'Set',
      'Cultivate',
      'Plant',
      'Grow',
      'Harvest',
      'Process',
      'Ready to Sell',
      'Sold',
    ];
  }
}
