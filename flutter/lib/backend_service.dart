// backend_service.dart
// Real API service connecting to FastAPI backend

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'models.dart';

String _generateUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class BackendService {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const String apiUrl = '$baseUrl/api';

  static io.Socket? _socket;
  static String? _currentUserId;
  static Function(Environment)? _onEnvironmentUpdate;
  static void Function()? _onGoldUpdate;

  // ==================== Socket.IO ====================

  static void connect({
    required String userId,
    Function(Environment)? onEnvironmentUpdate,
    void Function()? onGoldUpdate,
  }) {
    _currentUserId = userId;
    _onEnvironmentUpdate = onEnvironmentUpdate;
    _onGoldUpdate = onGoldUpdate;

    _socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      print('Socket connected');
      _socket!.emit('join', userId);
    });

    _socket!.on('environmentUpdated', (data) {
      if (_onEnvironmentUpdate != null && data != null) {
        // Environment is nested: {"environment": {...}, "hints": {...}}
        final envData = data['environment'] ?? data;
        final env = _parseEnvironment(envData);
        _onEnvironmentUpdate!(env);
      }
    });

    _socket!.on('playerData', (data) {
      print('Received player data: $data');
      if (_onGoldUpdate != null) {
        _onGoldUpdate!();
      }
    });

    _socket!.on('goldCollected', (data) {
      print('Gold collected: $data');
      if (_onGoldUpdate != null) {
        _onGoldUpdate!();
      }
    });

    _socket!.on('goldUpdated', (data) {
      print('Gold updated: $data');
      if (_onGoldUpdate != null) {
        _onGoldUpdate!();
      }
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _currentUserId = null;
    _onEnvironmentUpdate = null;
    _onGoldUpdate = null;
  }

  static bool get isConnected => _socket?.connected ?? false;

  // ==================== Auth ====================

  static Future<UserWithAccounts?> loginOrRegister(String name) async {
    try {
      // Generate a unique ID for this user
      final id = _generateUuid();

      final response = await http.post(
        Uri.parse('$apiUrl/user/get-or-create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'name': name}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserWithAccounts.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // ==================== User ====================

  static Future<UserWithAccounts?> getUser(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/user/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserWithAccounts.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Get user error: $e');
      return null;
    }
  }

  static Future<List<UserProfile>> findUsers(String query) async {
    try {
      final cleaned = query.trim();
      final response = await http.get(
        Uri.parse('$apiUrl/users?search=$cleaned'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((u) => UserProfile.fromJson(u)).toList();
      }
      return [];
    } catch (e) {
      print('Find users error: $e');
      return [];
    }
  }

  // ==================== Accounts ====================

  static Future<List<Account>> getAccounts(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/user/$userId/accounts'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((a) => Account.fromJson(a)).toList();
      }
      return [];
    } catch (e) {
      print('Get accounts error: $e');
      return [];
    }
  }

  // ==================== Transactions ====================

  static Future<List<TransactionEntry>> getTransactions(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/user/$userId/transactions'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((t) => TransactionEntry.fromJson(t)).toList();
      }
      return [];
    } catch (e) {
      print('Get transactions error: $e');
      return [];
    }
  }

  static Future<List<TransactionEntry>> getAccountTransactions(
    String accountId, {
    bool isLoan = false,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/account/$accountId/transactions'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final intAccountId = int.tryParse(accountId);
        return data
            .map(
              (t) => TransactionEntry.fromJson(
                t,
                forAccountId: intAccountId,
                accountIsLoan: isLoan,
              ),
            )
            .toList();
      }
      return [];
    } catch (e) {
      print('Get account transactions error: $e');
      return [];
    }
  }

  static Future<bool> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from_account_id': fromAccountId,
          'to_account_id': toAccountId,
          'amount': amount,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Transfer error: $e');
      return false;
    }
  }

  static Future<bool> sendMoney({
    required String fromUserId,
    required String toUserId,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'amount': amount,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Send money error: $e');
      return false;
    }
  }

  // ==================== Environment ====================

  static Future<Environment?> getEnvironment() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/environment'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseEnvironment(data);
      }
      return null;
    } catch (e) {
      print('Get environment error: $e');
      return null;
    }
  }

  static Future<AdaptationHints?> getAdaptationHints() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/environment/hints'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AdaptationHints.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Get hints error: $e');
      return null;
    }
  }

  // ==================== Gold ====================

  static Future<ExchangeGoldResult?> exchangeGold({
    required String userId,
    required int bars,
    String toAccountType = 'checking',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/exchange-gold'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'bars': bars,
          'to_account_type': toAccountType,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ExchangeGoldResult.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Exchange gold error: $e');
      return null;
    }
  }

  static Future<int> getGoldRate() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/gold-rate'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['rate'] ?? 7000;
      }
      return 7000;
    } catch (e) {
      print('Get gold rate error: $e');
      return 7000;
    }
  }

  // ==================== Helpers ====================

  static Environment _parseEnvironment(Map<String, dynamic> data) {
    final temperature = _readInt(data['temperature'], 20);
    final humidity = _readInt(data['humidity'], 50);
    final windSpeed = _readInt(data['wind_speed'] ?? data['windSpeed'], 0);
    final brightness = _readInt(data['brightness'], 5);
    final noiseRaw = data['noise']?.toString();
    final region = _parseRegion(data['region'] ?? data['type']) ??
        _mapEnvironmentToRegion(
          brightness: brightness,
          noise: noiseRaw ?? 'low',
          temperature: temperature,
          humidity: humidity,
          windSpeed: windSpeed,
        );

    return Environment(
      region: region,
      temperature: temperature,
      humidity: humidity,
      windSpeed: windSpeed,
      brightness: brightness,
      noise: _parseNoiseLevel(noiseRaw),
    );
  }

  static Region _mapEnvironmentToRegion({
    required int brightness,
    required String noise,
    required int temperature,
    required int humidity,
    required int windSpeed,
  }) {
    final noiseKey = noise.toLowerCase();
    if (temperature <= 0) return Region.arcticSnows;
    if (brightness <= 2) return Region.darkCave;
    if (windSpeed >= 35) return Region.windyPlains;
    if (noiseKey == 'high' || noiseKey == 'boomboom') return Region.loudJungle;
    if (brightness >= 8) return Region.dryBeach;
    if (humidity >= 80) return Region.rainforest;
    return Region.rainforest;
  }

  static Region? _parseRegion(dynamic value) {
    if (value is Region) {
      return value;
    }
    if (value is! String) {
      return null;
    }
    final key = value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    switch (key) {
      case 'drybeach':
      case 'beach':
        return Region.dryBeach;
      case 'darkcave':
      case 'cave':
        return Region.darkCave;
      case 'loudjungle':
      case 'jungle':
        return Region.loudJungle;
      case 'windyplains':
      case 'windy':
        return Region.windyPlains;
      case 'rainforest':
      case 'rain':
        return Region.rainforest;
      case 'arcticsnows':
      case 'arctic':
        return Region.arcticSnows;
      default:
        return null;
    }
  }

  static int _readInt(dynamic value, int fallback) {
    if (value == null) {
      return fallback;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static NoiseLevel _parseNoiseLevel(String? noise) {
    switch (noise) {
      case 'quiet': return NoiseLevel.quiet;
      case 'low': return NoiseLevel.low;
      case 'med': return NoiseLevel.med;
      case 'high': return NoiseLevel.high;
      case 'boomboom': return NoiseLevel.boomBoom;
      default: return NoiseLevel.low;
    }
  }
}

// ==================== Response Models ====================

class UserWithAccounts {
  final String id;
  final String name;
  final List<Account> accounts;

  UserWithAccounts({
    required this.id,
    required this.name,
    required this.accounts,
  });

  factory UserWithAccounts.fromJson(Map<String, dynamic> json) {
    return UserWithAccounts(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      accounts: (json['accounts'] as List<dynamic>?)
          ?.map((a) => Account.fromJson(a))
          .toList() ?? [],
    );
  }
}

class AdaptationHints {
  final List<String> visual;
  final List<String> interaction;

  AdaptationHints({
    required this.visual,
    required this.interaction,
  });

  factory AdaptationHints.fromJson(Map<String, dynamic> json) {
    return AdaptationHints(
      visual: List<String>.from(json['visual'] ?? []),
      interaction: List<String>.from(json['interaction'] ?? []),
    );
  }
}

class ExchangeGoldResult {
  final int exchangeRate;
  final double totalCash;
  final int goldBars;
  final Map<String, dynamic>? summary;

  ExchangeGoldResult({
    required this.exchangeRate,
    required this.totalCash,
    required this.goldBars,
    this.summary,
  });

  factory ExchangeGoldResult.fromJson(Map<String, dynamic> json) {
    final transaction = json['transaction'] as Map<String, dynamic>?;
    final rate = json['exchangeRate'] ?? 7000;
    final amount = (transaction?['amount'] as num?)?.toDouble() ?? 0;

    return ExchangeGoldResult(
      exchangeRate: rate,
      totalCash: amount,
      goldBars: (amount / rate).round(),
      summary: json['summary'],
    );
  }
}
