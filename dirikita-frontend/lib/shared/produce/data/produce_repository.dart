import 'package:duruha/shared/produce/domain/produce_model.dart';

class ProduceRepository {
  Future<List<Produce>> getAllProduce() async {
    // Simulate API call to fetch user settings or profile
    await Future.delayed(const Duration(milliseconds: 300));

    // Return mock dialect
    return [
      _buildTomato(),
      _buildEggplant(),
      _buildChili(),
      _buildSquash(),
      _buildOkra(),
      _buildSitaw(),
      _buildAmpalaya(),
      _buildGinger(),
      _buildGarlic(),
      _buildOnion(),
    ];
  }

  Produce _buildTomato() {
    return Produce(
      id: 'prod_001',
      nameEnglish: 'Tomato',
      nameScientific: 'Solanum lycopersicum',
      category: ProduceCategory.fruitVeg,
      namesByDialect: {
        "tagalog": "Kamatis",
        "hiligaynon": "Kamatis",
        "cebuano": "Kamatis",
      },
      tags: ["High Yield", "Standard"],
      availableVarieties: [
        ProduceVariety(
          id: 'var_tomato_1',
          name: "Diamante Max",
          isLocallyGrown: true,
          sourcingProvinces: ["Iloilo"],
          pricingModel: "Base",
          priceModifier: 10.0,
        ),
        ProduceVariety(
          id: 'var_tomato_2',
          name: "Assorted Native",
          isLocallyGrown: true,
          sourcingProvinces: ["Antique"],
          pricingModel: "Base",
          priceModifier: 0.0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1607305387299-a3d9611cd469?q=80&w=2370&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1607305387299-a3d9611cd469?q=80&w=2370&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/1202/1202125.png',
      gradeGuideUrl:
          'https://via.placeholder.com/400x600?text=Tomato+Grade+Guide',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 85.0,
        duruhaFarmerPayout: 60.0,
        marketBenchmarkRetail: 110.0,
        marketBenchmarkFarmgate: 45.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 4,
      shelfLifeDays: 7,
      requiresColdChain: true,
      standardPackType: "Crate (20kg)",
      growingCycleDays: 75,
      seasonality: Seasonality(
        peakMonths: ["January", "February"],
        leanMonths: ["June", "July"],
        offSeason: ["October"],
      ),
      yieldPerSqm: 4.5,
      priceMinHistorical: 40,
      priceMaxHistorical: 130,
    );
  }

  Produce _buildEggplant() {
    return Produce(
      id: 'prod_002',
      nameEnglish: 'Eggplant',
      nameScientific: 'Solanum melongena',
      category: ProduceCategory.fruitVeg,
      namesByDialect: {
        "hiligaynon": "Talong",
        "kinaray_a": "Tarong",
        "tagalog": "Talong",
        "cebuano": "Talong",
      },
      tags: ["Best Seller", "Fair Price"],
      availableVarieties: [
        ProduceVariety(
          id: "var_native_long",
          name: "Long Purple (Native)",
          isLocallyGrown: true,
          sourcingProvinces: ["Iloilo", "Antique", "Guimaras"],
          pricingModel: "Base",
          priceModifier: 0.00,
        ),
        ProduceVariety(
          id: "var_imported_round",
          name: "Black Beauty (Round/Imported)",
          isLocallyGrown: false,
          sourcingProvinces: ["Benguet", "Manila"],
          pricingModel: "Premium_Fixed",
          priceModifier: 25.00,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1613881553903-4543f5f2cac9?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1613881553903-4543f5f2cac9?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/765/765544.png',
      gradeGuideUrl:
          'https://via.placeholder.com/400x600?text=Eggplant+Grade+Guide',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 75.0,
        duruhaFarmerPayout: 52.5,
        marketBenchmarkRetail: 95.0,
        marketBenchmarkFarmgate: 35.0,
        priceTrendSignal: "Bullish",
      ),
      perishabilityIndex: 3,
      shelfLifeDays: 10,
      requiresColdChain: false,
      standardPackType: "Poly Bag (10kg)",
      growingCycleDays: 120,
      seasonality: Seasonality(
        peakMonths: ["November", "December"],
        leanMonths: ["May", "June"],
        offSeason: ["August"],
      ),
      yieldPerSqm: 5.2,
      gradingStandards: {
        "Class A": "Smooth skin, straight, >20cm, no borer holes",
        "Class B": "Curved, minor scratches, <15cm",
        "Class C": "Odd shapes, minor borer holes (Good for Atsara)",
      },
      gradeMultiplier: {"Class A": 1.0, "Class B": 0.75, "Class C": 0.50},
      priceMinHistorical: 30,
      priceMaxHistorical: 110,
    );
  }

  // Simplified for other items to avoid massive file size, but fulfilling requirements
  Produce _buildChili() {
    return Produce(
      id: 'prod_003',
      nameEnglish: "Bird's Eye Chili",
      nameScientific: 'Capsicum frutescens',
      category: ProduceCategory.spice,
      namesByDialect: {
        "tagalog": "Siling Labuyo",
        "hiligaynon": "Siling Labuyo",
      },
      availableVarieties: [
        ProduceVariety(
          id: 'v_chili_native',
          name: "Native (Labuyo)",
          isLocallyGrown: true,
          sourcingProvinces: ["Iloilo", "Capiz"],
          pricingModel: "Base",
          priceModifier: 0,
        ),
        ProduceVariety(
          id: 'v_chili_thai',
          name: "Thai Variant (Siling Tingala)",
          isLocallyGrown: true,
          sourcingProvinces: ["Benguet", "Iloilo"],
          pricingModel: "Market_Linked",
          priceModifier: 15.0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/685/685828.png',
      gradeGuideUrl: '',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 350.0,
        duruhaFarmerPayout: 245.0,
        marketBenchmarkRetail: 450.0,
        marketBenchmarkFarmgate: 150.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 2,
      shelfLifeDays: 14,
      requiresColdChain: false,
      standardPackType: "Nylon Bag (1kg)",
      growingCycleDays: 90,
      seasonality: Seasonality(
        peakMonths: ["March", "April", "May"],
        leanMonths: ["September", "October"],
        offSeason: ["January"],
      ),
      yieldPerSqm: 1.2,
      priceMinHistorical: 150,
      priceMaxHistorical: 800,
    );
  }

  Produce _buildSquash() {
    return Produce(
      id: 'prod_004',
      nameEnglish: "Squash",
      nameScientific: 'Cucurbita maxima',
      category: ProduceCategory.fruitVeg,
      namesByDialect: {"tagalog": "Kalabasa", "hiligaynon": "Kalabasa"},
      availableVarieties: [
        ProduceVariety(
          id: 'v_squash_suprema',
          name: "Suprema (Elite)",
          isLocallyGrown: true,
          sourcingProvinces: ["Iloilo", "Pangasinan"],
          pricingModel: "Base",
          priceModifier: 0,
        ),
        ProduceVariety(
          id: 'v_squash_native',
          name: "Assorted Native",
          isLocallyGrown: true,
          sourcingProvinces: ["Antique", "Guimaras"],
          pricingModel: "Base",
          priceModifier: -5.0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1506807803488-8eafc15316c7?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1506807803488-8eafc15316c7?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/1041/1041280.png',
      gradeGuideUrl: '',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 40.0,
        duruhaFarmerPayout: 28.0,
        marketBenchmarkRetail: 55.0,
        marketBenchmarkFarmgate: 20.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 1,
      shelfLifeDays: 60,
      requiresColdChain: false,
      standardPackType: "Bulk / Loose",
      growingCycleDays: 100,
      seasonality: Seasonality(
        peakMonths: ["April", "May", "June"],
        leanMonths: ["October", "November"],
        offSeason: ["February"],
      ),
      yieldPerSqm: 8.0,
      priceMinHistorical: 15,
      priceMaxHistorical: 65,
    );
  }

  Produce _buildOkra() {
    return Produce(
      id: 'prod_005',
      nameEnglish: "Lady's Finger",
      nameScientific: 'Abelmoschus esculentus',
      category: ProduceCategory.fruitVeg,
      namesByDialect: {"tagalog": "Okra", "hiligaynon": "Okra"},
      availableVarieties: [
        ProduceVariety(
          id: 'v_okra_smooth',
          name: "Smooth Green",
          isLocallyGrown: true,
          sourcingProvinces: ["Iloilo", "Bacolod"],
          pricingModel: "Base",
          priceModifier: 0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1594282486552-05b4d80fbb9f?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1594282486552-05b4d80fbb9f?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/6030/6030113.png',
      gradeGuideUrl: '',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 60.0,
        duruhaFarmerPayout: 42.0,
        marketBenchmarkRetail: 85.0,
        marketBenchmarkFarmgate: 30.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 4,
      shelfLifeDays: 5,
      requiresColdChain: true,
      standardPackType: "Crate (10kg)",
      growingCycleDays: 50,
      seasonality: Seasonality(
        peakMonths: ["July", "August", "September"],
        leanMonths: ["January", "February"],
        offSeason: ["May"],
      ),
      yieldPerSqm: 3.0,
      priceMinHistorical: 25,
      priceMaxHistorical: 100,
    );
  }

  Produce _buildSitaw() {
    return Produce(
      id: 'prod_006',
      nameEnglish: "String Beans",
      nameScientific: 'Vigna unguiculata',
      category: ProduceCategory.legume,
      namesByDialect: {"tagalog": "Sitaw", "hiligaynon": "Latoy"},
      availableVarieties: [
        ProduceVariety(
          id: 'v_sitaw_galante',
          name: "Galante",
          isLocallyGrown: true,
          sourcingProvinces: ["Iloilo", "Antique"],
          pricingModel: "Base",
          priceModifier: 0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1594282486552-05b4d80fbb9f?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1594282486552-05b4d80fbb9f?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/11417/11417534.png',
      gradeGuideUrl: '',
      unitOfMeasure: 'bundle',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 35.0,
        duruhaFarmerPayout: 24.5,
        marketBenchmarkRetail: 45.0,
        marketBenchmarkFarmgate: 15.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 3,
      shelfLifeDays: 4,
      requiresColdChain: true,
      standardPackType: "Bundle (500g)",
      growingCycleDays: 60,
      seasonality: Seasonality(
        peakMonths: ["June", "July", "August"],
        leanMonths: ["December", "January"],
        offSeason: ["April"],
      ),
      yieldPerSqm: 2.5,
      priceMinHistorical: 15,
      priceMaxHistorical: 60,
    );
  }

  Produce _buildAmpalaya() {
    return Produce(
      id: 'prod_007',
      nameEnglish: "Bitter Gourd",
      nameScientific: 'Momordica charantia',
      category: ProduceCategory.fruitVeg,
      namesByDialect: {"tagalog": "Ampalaya", "hiligaynon": "Parya"},
      availableVarieties: [
        ProduceVariety(
          id: 'v_ampalaya_galactica',
          name: "Galactica",
          isLocallyGrown: true,
          sourcingProvinces: ["Iloilo"],
          pricingModel: "Base",
          priceModifier: 0,
        ),
        ProduceVariety(
          id: 'v_ampalaya_native',
          name: "Native (Short)",
          isLocallyGrown: true,
          sourcingProvinces: ["Antique"],
          pricingModel: "Base",
          priceModifier: -10.0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1622325854652-32b4507d4f90?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1622325854652-32b4507d4f90?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/5001/5001710.png',
      gradeGuideUrl: '',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 100.0,
        duruhaFarmerPayout: 70.0,
        marketBenchmarkRetail: 140.0,
        marketBenchmarkFarmgate: 60.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 3,
      shelfLifeDays: 7,
      requiresColdChain: true,
      standardPackType: "Crate (15kg)",
      growingCycleDays: 70,
      seasonality: Seasonality(
        peakMonths: ["August", "September", "October"],
        leanMonths: ["February", "March"],
        offSeason: ["June"],
      ),
      yieldPerSqm: 3.5,
      priceMinHistorical: 40,
      priceMaxHistorical: 160,
    );
  }

  Produce _buildGinger() {
    return Produce(
      id: 'prod_008',
      nameEnglish: "Ginger",
      nameScientific: 'Zingiber officinale',
      category: ProduceCategory.spice,
      namesByDialect: {"tagalog": "Luya", "hiligaynon": "Luy-a"},
      availableVarieties: [
        ProduceVariety(
          id: 'v_ginger_native',
          name: "Native",
          isLocallyGrown: true,
          sourcingProvinces: ["Iloilo", "Antique"],
          pricingModel: "Base",
          priceModifier: 0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1599307767316-776533bb941c?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1599307767316-776533bb941c?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/1041/1041304.png',
      gradeGuideUrl: '',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 150.0,
        duruhaFarmerPayout: 105.0,
        marketBenchmarkRetail: 200.0,
        marketBenchmarkFarmgate: 60.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 1,
      shelfLifeDays: 45,
      requiresColdChain: false,
      standardPackType: "Sack (25kg)",
      growingCycleDays: 240,
      seasonality: Seasonality(
        peakMonths: ["December", "January", "February"],
        leanMonths: ["June", "July"],
        offSeason: ["September"],
      ),
      yieldPerSqm: 2.0,
      priceMinHistorical: 60,
      priceMaxHistorical: 250,
    );
  }

  Produce _buildGarlic() {
    return Produce(
      id: 'prod_009',
      nameEnglish: "Garlic",
      nameScientific: 'Allium sativum',
      category: ProduceCategory.spice,
      namesByDialect: {"tagalog": "Bawang", "hiligaynon": "Ahos"},
      availableVarieties: [
        ProduceVariety(
          id: 'v_garlic_ilocos',
          name: "Ilocos White",
          isLocallyGrown: true,
          sourcingProvinces: ["Ilocos Norte", "Ilocos Sur"],
          pricingModel: "Base",
          priceModifier: 0,
        ),
        ProduceVariety(
          id: 'v_garlic_imported',
          name: "Imported (Large)",
          isLocallyGrown: false,
          sourcingProvinces: ["China", "Manila"],
          pricingModel: "Market_Linked",
          priceModifier: -20.0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1540148426945-6cf22a6b2383?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1540148426945-6cf22a6b2383?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/1041/1041289.png',
      gradeGuideUrl: '',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 140.0,
        duruhaFarmerPayout: 98.0,
        marketBenchmarkRetail: 180.0,
        marketBenchmarkFarmgate: 80.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 1,
      shelfLifeDays: 120,
      requiresColdChain: false,
      standardPackType: "Sack (20kg)",
      growingCycleDays: 120,
      seasonality: Seasonality(
        peakMonths: ["February", "March", "April"],
        leanMonths: ["August", "September"],
        offSeason: ["November"],
      ),
      yieldPerSqm: 1.5,
      priceMinHistorical: 80,
      priceMaxHistorical: 220,
    );
  }

  Produce _buildOnion() {
    return Produce(
      id: 'prod_010',
      nameEnglish: "Onion",
      nameScientific: 'Allium cepa',
      category: ProduceCategory.spice,
      namesByDialect: {"tagalog": "Sibuyas", "hiligaynon": "Lasona"},
      availableVarieties: [
        ProduceVariety(
          id: 'v_onion_red',
          name: "Red Creole",
          isLocallyGrown: true,
          sourcingProvinces: ["Nueva Ecija", "Iloilo"],
          pricingModel: "Base",
          priceModifier: 0,
        ),
        ProduceVariety(
          id: 'v_onion_white',
          name: "White / Yellow",
          isLocallyGrown: true,
          sourcingProvinces: ["Nueva Ecija"],
          pricingModel: "Market_Linked",
          priceModifier: 10.0,
        ),
      ],
      imageHeroUrl:
          'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=900&auto=format&fit=crop',
      imageThumbnailUrl:
          'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=900&auto=format&fit=crop',
      iconUrl: 'https://cdn-icons-png.flaticon.com/128/1041/1041295.png',
      gradeGuideUrl: '',
      unitOfMeasure: 'kg',
      pricingEconomics: PricingEconomics(
        duruhaConsumerPrice: 220.0,
        duruhaFarmerPayout: 154.0,
        marketBenchmarkRetail: 300.0,
        marketBenchmarkFarmgate: 80.0,
        priceTrendSignal: "Stable",
      ),
      perishabilityIndex: 2,
      shelfLifeDays: 90,
      requiresColdChain: false,
      standardPackType: "Sack (25kg)",
      growingCycleDays: 150,
      seasonality: Seasonality(
        peakMonths: ["March", "April", "May"],
        leanMonths: ["September", "October"],
        offSeason: ["January"],
      ),
      yieldPerSqm: 4.0,
      priceMinHistorical: 50,
      priceMaxHistorical: 600,
    );
  }
}
