import 'package:flutter/material.dart';

class FormListing {
  String? listingId;
  final TextEditingController produceForm = TextEditingController();
  final TextEditingController farmerToTraderPrice = TextEditingController(
    text: '0',
  );
  final TextEditingController farmerToDuruhaPrice = TextEditingController(
    text: '0',
  );
  final TextEditingController duruhaToConsumerPrice = TextEditingController(
    text: '0',
  );
  final TextEditingController marketToConsumerPrice = TextEditingController(
    text: '0',
  );

  void dispose() {
    produceForm.dispose();
    farmerToTraderPrice.dispose();
    farmerToDuruhaPrice.dispose();
    duruhaToConsumerPrice.dispose();
    marketToConsumerPrice.dispose();
  }
}

class FormVariety {
  String? varietyId;
  final TextEditingController name = TextEditingController();
  bool isNative = false;
  String breedingType = 'OPV';
  final TextEditingController daysMin = TextEditingController();
  final TextEditingController daysMax = TextEditingController();
  final TextEditingController floodTolerance = TextEditingController();
  final TextEditingController shelfLifeDays = TextEditingController(text: '7');
  final TextEditingController handlingFragility = TextEditingController();
  final TextEditingController packagingReq = TextEditingController();
  final TextEditingController optimalTemp = TextEditingController();
  String philippineSeason = 'Year-round';
  final TextEditingController peakMonths = TextEditingController();
  final TextEditingController appearanceDesc = TextEditingController();
  final TextEditingController imageUrl = TextEditingController();

  List<FormListing> listings = [];

  void dispose() {
    name.dispose();
    daysMin.dispose();
    daysMax.dispose();
    floodTolerance.dispose();
    shelfLifeDays.dispose();
    handlingFragility.dispose();
    packagingReq.dispose();
    optimalTemp.dispose();
    peakMonths.dispose();
    appearanceDesc.dispose();
    imageUrl.dispose();
    for (var l in listings) {
      l.dispose();
    }
  }
}

class FormProduce {
  String? id;
  final TextEditingController englishName = TextEditingController();
  final TextEditingController scientificName = TextEditingController();
  final TextEditingController baseUnit = TextEditingController(text: 'kg');
  final TextEditingController imageUrl = TextEditingController();
  String category = 'Vegetable';
  String storageGroup = 'Ambient';
  String respirationRate = 'Low';
  bool isEthyleneProducer = false;
  bool isEthyleneSensitive = false;
  final TextEditingController crushWeightTolerance = TextEditingController(
    text: '5',
  );
  final TextEditingController crossContaminationRisk = TextEditingController();

  List<FormVariety> varieties = [];

  void dispose() {
    englishName.dispose();
    scientificName.dispose();
    baseUnit.dispose();
    imageUrl.dispose();
    crushWeightTolerance.dispose();
    crossContaminationRisk.dispose();
    for (var v in varieties) {
      v.dispose();
    }
  }
}
