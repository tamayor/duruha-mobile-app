import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';

class ProducePresentationRepository {
  Future<Produce> getProduceDetails(String id) async {
    final all = await ProduceRepository().getAllProduce();
    return all.firstWhere((p) => p.id == id, orElse: () => all.first);
  }
}
