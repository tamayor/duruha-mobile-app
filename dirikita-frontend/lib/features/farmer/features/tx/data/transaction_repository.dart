import '../../../shared/domain/pledge_model.dart';

class TransactionRepository {
  Future<bool> submitTransaction(TransactionRequest request) async {
    try {
      // ignore: avoid_print
      print(
        "🚀 [API REQUEST] Batch Transaction via TransactionRepository (${request.mode.toUpperCase()})",
      );
      print("📦 Payload: ${request.toJson()}");

      // Replace with your actual http.post or dio.post call
      await Future.delayed(const Duration(seconds: 2));

      return true; // Success
    } catch (e) {
      // ignore: avoid_print
      print("❌ [API ERROR] in TransactionRepository: $e");
      return false;
    }
  }
}
