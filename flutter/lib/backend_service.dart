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
  static const String baseUrl = 'http://localhost:3000';
  static const String apiUrl = '$baseUrl/api';

  static io.Socket? _socket;
  static String? _currentUserId;
  static Function(Environment)? _onEnvironmentUpdate;

  // ==================== Socket.IO ====================

  static void connect({
    required String userId,
    Function(Environment)? onEnvironmentUpdate,
  }) {
    _currentUserId = userId;
    _onEnvironmentUpdate = onEnvironmentUpdate;

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
    });

    _socket!.on('goldCollected', (data) {
      print('Gold collected: $data');
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
      final response = await http.get(
        Uri.parse('$apiUrl/users?q=$query'),
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
        Uri.parse('$apiUrl/accounts/$userId'),
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

  static Future<List<TransactionEntry>> getAccountTransactions(String accountId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/account/$accountId/transactions'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final intAccountId = int.tryParse(accountId);
        return data.map((t) => TransactionEntry.fromJson(t, forAccountId: intAccountId)).toList();
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
      return response.statusCode == 200;
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
      return response.statusCode == 200;
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
    return Environment(
      region: _mapBrightnessToRegion(data['brightness'] ?? 5, data['noise'] ?? 'low'),
      temperature: data['temperature'] ?? 20,
      humidity: data['humidity'] ?? 50,
      windSpeed: data['wind_speed'] ?? 0,
      brightness: data['brightness'] ?? 5,
      noise: _parseNoiseLevel(data['noise']),
    );
  }

  static Region _mapBrightnessToRegion(int brightness, String noise) {
    // Map backend environment to Flutter regions based on conditions
    if (brightness <= 2) return Region.darkCave;
    if (brightness >= 8) return Region.dryBeach;
    if (noise == 'high' || noise == 'boomboom') return Region.loudJungle;
    return Region.rainforest;
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
