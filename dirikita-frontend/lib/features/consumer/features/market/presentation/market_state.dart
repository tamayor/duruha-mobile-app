import 'package:flutter/foundation.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

enum MarketMode { plan, order }

class MarketState extends ChangeNotifier {
  // Market mode (Plan/Pre-order vs Order/Spot)
  MarketMode _marketMode = MarketMode.order;

  MarketMode get marketMode => _marketMode;

  void setMarketMode(MarketMode mode) {
    if (_marketMode != mode) {
      _marketMode = mode;
      notifyListeners();
    }
  }

  // Selected produce items (cart)
  final Map<String, Produce> _selectedProduce = {};

  // Order items with configurations
  final Map<String, OrderItemBuilder> _orderItems = {};

  // Filtering state
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  String? _selectedCategory;
  final Set<String> _favoriteProduceIds = {};

  // Getters
  String get searchQuery => _searchQuery;
  bool get showFavoritesOnly => _showFavoritesOnly;
  String? get selectedCategory => _selectedCategory;
  List<Produce> get selectedProduceList => _selectedProduce.values.toList();
  int get selectedCount => _selectedProduce.length;
  bool get hasSelectedItems => _selectedProduce.isNotEmpty;

  Map<String, OrderItemBuilder> get orderItems => _orderItems;

  // Check if a produce is selected
  bool isSelected(String produceId) {
    return _selectedProduce.containsKey(produceId);
  }

  // Favorite logic
  bool isFavorite(String produceId) {
    return _favoriteProduceIds.contains(produceId);
  }

  void toggleFavorite(String produceId) {
    if (_favoriteProduceIds.contains(produceId)) {
      _favoriteProduceIds.remove(produceId);
    } else {
      _favoriteProduceIds.add(produceId);
    }
    notifyListeners();
  }

  // Filtering setters
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleFavoritesFilter() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Filter produce items
  List<MarketProduceItem> filterItems(List<MarketProduceItem> items) {
    return items.where((item) {
      // 1. Filter by favorites if enabled
      if (_showFavoritesOnly && !isFavorite(item.produce.id)) {
        return false;
      }

      // 2. Filter by category if selected
      if (_selectedCategory != null &&
          item.produce.category != _selectedCategory) {
        return false;
      }

      // 3. Filter by search query if not empty
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameEn = item.produce.nameEnglish.toLowerCase();
        final namesDialect = item.produce.namesByDialect.values
            .map((v) => v.toLowerCase())
            .toList();

        final matchesEn = nameEn.contains(query);
        final matchesDialect = namesDialect.any(
          (dialect) => dialect.contains(query),
        );

        if (!matchesEn && !matchesDialect) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Add produce to selection
  void addToSelection(Produce produce) {
    if (!_selectedProduce.containsKey(produce.id)) {
      _selectedProduce[produce.id] = produce;
      _orderItems[produce.id] = OrderItemBuilder(produce: produce);
      notifyListeners();
    }
  }

  // Remove produce from selection
  void removeFromSelection(String produceId) {
    _selectedProduce.remove(produceId);
    _orderItems.remove(produceId);
    notifyListeners();
  }

  // Toggle produce selection
  void toggleSelection(Produce produce) {
    if (isSelected(produce.id)) {
      removeFromSelection(produce.id);
    } else {
      addToSelection(produce);
    }
  }

  // Update order item configuration
  void updateOrderItem(String produceId, OrderItemBuilder builder) {
    if (_orderItems.containsKey(produceId)) {
      _orderItems[produceId] = builder;
      notifyListeners();
    }
  }

  // Update quantity directly
  void updateQuantity(String produceId, double quantity) {
    if (_orderItems.containsKey(produceId)) {
      final builder = _orderItems[produceId]!;
      _orderItems[produceId] = builder.copyWith(quantityKg: quantity);
      notifyListeners();
    }
  }

  // Check if all order items are complete
  bool get allItemsComplete {
    if (_orderItems.isEmpty) return false;
    return _orderItems.values.every((item) => item.isComplete);
  }

  // Build final order items with payment option
  List<OrderItem> buildOrderItems(PaymentOption paymentOption) {
    return _orderItems.values
        .map((builder) => builder.buildWithPayment(paymentOption))
        .toList();
  }

  // Calculate total
  double get estimatedMinSubtotal {
    return _orderItems.values.fold(0.0, (sum, builder) {
      return sum + builder.minTotalPrice;
    });
  }

  double get estimatedMaxSubtotal {
    return _orderItems.values.fold(0.0, (sum, builder) {
      return sum + builder.maxTotalPrice;
    });
  }

  double get estimatedTotal {
    return _orderItems.values.fold(0.0, (sum, builder) {
      return sum + builder.totalPrice;
    });
  }

  // Clear all selections
  void clearSelections() {
    _selectedProduce.clear();
    _orderItems.clear();
    notifyListeners();
  }
}

// Builder class for OrderItem to allow partial configuration
class OrderItemBuilder {
  final Produce produce;
  final List<String>? _selectedVarieties;
  List<String> get selectedVarieties => _selectedVarieties ?? const [];
  final List<ProduceClass>? _selectedClasses;
  List<ProduceClass> get selectedClasses => _selectedClasses ?? const [];
  final double quantityKg;

  OrderItemBuilder({
    required this.produce,
    List<String>? selectedVarieties,
    List<ProduceClass>? selectedClasses,
    this.quantityKg = 0.0,
  }) : _selectedVarieties = selectedVarieties ?? const [],
       _selectedClasses = selectedClasses ?? const [];

  double get minTotalPrice {
    if (quantityKg <= 0) return 0.0;

    double minBase = produce.pricingEconomics.duruhaConsumerPrice;
    if (selectedVarieties.isNotEmpty) {
      final basePrice = produce.pricingEconomics.duruhaConsumerPrice;
      final selectedPrices = produce.availableVarieties
          .where((v) => selectedVarieties.contains(v.name))
          .map((v) => basePrice + v.priceModifier);
      if (selectedPrices.isNotEmpty) {
        minBase = selectedPrices.reduce((a, b) => a < b ? a : b);
      }
    }

    double minMultiplier = 1.0;
    if (selectedClasses.isNotEmpty) {
      minMultiplier = selectedClasses
          .map((c) => c.multiplier)
          .reduce((a, b) => a < b ? a : b);
    }
    return minBase * quantityKg * minMultiplier;
  }

  double get maxTotalPrice {
    if (quantityKg <= 0) return 0.0;

    double maxBase = produce.pricingEconomics.duruhaConsumerPrice;
    if (selectedVarieties.isNotEmpty) {
      final basePrice = produce.pricingEconomics.duruhaConsumerPrice;
      final selectedPrices = produce.availableVarieties
          .where((v) => selectedVarieties.contains(v.name))
          .map((v) => basePrice + v.priceModifier);
      if (selectedPrices.isNotEmpty) {
        maxBase = selectedPrices.reduce((a, b) => a > b ? a : b);
      }
    }

    double maxMultiplier = 1.0;
    if (selectedClasses.isNotEmpty) {
      maxMultiplier = selectedClasses
          .map((c) => c.multiplier)
          .reduce((a, b) => a > b ? a : b);
    }
    return maxBase * quantityKg * maxMultiplier;
  }

  double get totalPrice => maxTotalPrice;

  bool get isComplete {
    return selectedVarieties.isNotEmpty &&
        selectedClasses.isNotEmpty &&
        quantityKg > 0;
  }

  OrderItem buildWithPayment(PaymentOption paymentOption) {
    if (!isComplete) {
      throw Exception('OrderItem is not complete');
    }
    return OrderItem(
      produce: produce,
      selectedVarieties: selectedVarieties,
      selectedClasses: selectedClasses,
      quantityKg: quantityKg,
      paymentOption: paymentOption,
    );
  }

  OrderItemBuilder copyWith({
    List<String>? selectedVarieties,
    List<ProduceClass>? selectedClasses,
    double? quantityKg,
  }) {
    return OrderItemBuilder(
      produce: produce,
      selectedVarieties: selectedVarieties ?? this.selectedVarieties,
      selectedClasses: selectedClasses ?? this.selectedClasses,
      quantityKg: quantityKg ?? this.quantityKg,
    );
  }
}
