// models.dart

// -------------------- World / Region --------------------

enum Region {
  dryBeach,
  darkCave,
  loudJungle,
  windyPlains,
  rainforest,
  arcticSnows,
}

extension RegionX on Region {
  String get label {
    switch (this) {
      case Region.dryBeach:
        return 'Dry beach';
      case Region.darkCave:
        return 'Dark cave';
      case Region.loudJungle:
        return 'Loud jungle';
      case Region.windyPlains:
        return 'Windy plains';
      case Region.rainforest:
        return 'Rainforest';
      case Region.arcticSnows:
        return 'Arctic snows';
    }
  }

  ///   assets/bg/beach.jpg
  ///   assets/bg/cave.jpg
  ///   assets/bg/jungle.jpg
  ///   assets/bg/plains.jpg
  ///   assets/bg/rainforest.jpg
  ///   assets/bg/arctic.jpg
  ///  add to pubspec.yaml under `assets:`.
  String get assetPath {
    switch (this) {
      case Region.dryBeach:
        return 'assets/bg/beach.jpg';
      case Region.darkCave:
        return 'assets/bg/cave.jpg';
      case Region.loudJungle:
        return 'assets/bg/jungle.jpg';
      case Region.windyPlains:
        return 'assets/bg/plains.jpg';
      case Region.rainforest:
        return 'assets/bg/rainforest.jpg';
      case Region.arcticSnows:
        return 'assets/bg/arctic.jpg';
    }
  }

  /// Rough brightness estimate of the background image (0..1).
  double get bgBrightnessHint {
    switch (this) {
      case Region.dryBeach:
        return 0.85;
      case Region.darkCave:
        return 0.15;
      case Region.loudJungle:
        return 0.45;
      case Region.windyPlains:
        return 0.65;
      case Region.rainforest:
        return 0.35;
      case Region.arcticSnows:
        return 0.90;
    }
  }
}

// -------------------- Data model --------------------

class Transaction {
  final String fromAccId;
  final String toAccId;
  final int dollar; // keep as int per prompt

  const Transaction({
    required this.fromAccId,
    required this.toAccId,
    required this.dollar,
  });
}

class Account {
  final String name;
  final String id;
  final int balance;
  final List<Transaction> transactionHistory;

  const Account({
    required this.name,
    required this.id,
    required this.balance,
    required this.transactionHistory,
  });
}

class User {
  final String id;
  final List<Account> accounts;
  final int creditScore;

  const User({
    required this.id,
    required this.accounts,
    required this.creditScore,
  });
}

class Weather {
  final int temperature;
  final int humidity;
  final int windSpeed;

  const Weather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
  });
}

enum NoiseLevel { quiet, low, med, high, boomBoom }

class DistanceToTreasure {
  final int dx;
  final int dy;

  const DistanceToTreasure(this.dx, this.dy);
}

class WorldLocation {
  final int x;
  final int y;

  const WorldLocation(this.x, this.y);
}

// -------------------- Debug overrides --------------------

class DebugOverrides {
  Region? region;
  int? temperature;
  int? humidity;
  int? windSpeed;
  NoiseLevel? noise;
  int? brightness; // 1..10
  WorldLocation? location;
  DistanceToTreasure? treasureDist;

  bool get anyEnabled =>
      region != null ||
      temperature != null ||
      humidity != null ||
      windSpeed != null ||
      noise != null ||
      brightness != null ||
      location != null ||
      treasureDist != null;

  void clear() {
    region = null;
    temperature = null;
    humidity = null;
    windSpeed = null;
    noise = null;
    brightness = null;
    location = null;
    treasureDist = null;
  }
}
