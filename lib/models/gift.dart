import '../config/api_config.dart';

class Gift {
  final int id;
  final int? restaurantId;
  final String restaurantName;
  final bool isGlobal;
  final String name;
  final String price;
  final int level;
  final String? imageUrl;
  final bool isActive;
  final int giftableCount;

  const Gift({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.isGlobal,
    required this.name,
    required this.price,
    required this.level,
    required this.imageUrl,
    required this.isActive,
    this.giftableCount = 0,
  });

  factory Gift.fromJson(Map<String, dynamic> json) {
    final rawLevel = (json['level'] as num?)?.toInt() ?? 1;
    final restaurantId = json['restaurant_id'] as int?;

    return Gift(
      id: json['id'] as int,
      restaurantId: restaurantId,
      restaurantName: json['restaurant_name'] as String? ?? '',
      isGlobal: json['is_global'] as bool? ?? restaurantId == null,
      name: json['name'] as String? ?? 'Подарок',
      price: json['price']?.toString() ?? '0.00',
      level: rawLevel.clamp(1, 5).toInt(),
      imageUrl: ApiConfig.resolveUrl(json['image_url'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      giftableCount: json['giftable_count'] as int? ?? 0,
    );
  }

  factory Gift.fromRealtimeJson(Map<String, dynamic> json) {
    final rawLevel = (json['level'] as num?)?.toInt() ?? 1;
    final restaurantId = json['restaurant_id'] as int?;

    return Gift(
      id: json['id'] as int,
      restaurantId: restaurantId,
      restaurantName: '',
      isGlobal: json['is_global'] as bool? ?? restaurantId == null,
      name: json['name'] as String? ?? 'Подарок',
      price: '0.00',
      level: rawLevel.clamp(1, 5).toInt(),
      imageUrl: ApiConfig.resolveUrl(json['image_url'] as String?),
      isActive: true,
    );
  }

  Gift copyWith({int? giftableCount}) {
    return Gift(
      id: id,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      isGlobal: isGlobal,
      name: name,
      price: price,
      level: level,
      imageUrl: imageUrl,
      isActive: isActive,
      giftableCount: giftableCount ?? this.giftableCount,
    );
  }
}

class InventoryGift {
  final int id;
  final Gift gift;
  final String qrCode;
  final String status;
  final bool isGiftable;
  final int? giftedById;
  final String? giftedByName;
  final DateTime? giftedAt;
  final DateTime? acquiredAt;
  final DateTime? redeemedAt;

  const InventoryGift({
    required this.id,
    required this.gift,
    required this.qrCode,
    required this.status,
    required this.isGiftable,
    required this.giftedById,
    required this.giftedByName,
    required this.giftedAt,
    required this.acquiredAt,
    required this.redeemedAt,
  });

  factory InventoryGift.fromJson(Map<String, dynamic> json) {
    return InventoryGift(
      id: json['id'] as int,
      gift: Gift.fromJson(
        Map<String, dynamic>.from(json['gift'] as Map),
      ),
      qrCode: json['qr_code'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      isGiftable: json['is_giftable'] as bool? ?? false,
      giftedById: json['gifted_by_id'] as int?,
      giftedByName: json['gifted_by_name'] as String?,
      giftedAt: DateTime.tryParse(json['gifted_at'] as String? ?? ''),
      acquiredAt: DateTime.tryParse(json['acquired_at'] as String? ?? ''),
      redeemedAt: DateTime.tryParse(json['redeemed_at'] as String? ?? ''),
    );
  }

  bool get isAvailable => status == 'available';

  String get senderLabel {
    final value = giftedByName?.trim();
    return value == null || value.isEmpty ? 'Пользователь Domino' : value;
  }
}

class GiftPurchase {
  final int id;
  final Gift gift;
  final int quantity;
  final String unitPrice;
  final String totalPrice;
  final DateTime? purchasedAt;

  const GiftPurchase({
    required this.id,
    required this.gift,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.purchasedAt,
  });

  factory GiftPurchase.fromJson(Map<String, dynamic> json) {
    return GiftPurchase(
      id: json['id'] as int,
      gift: Gift.fromJson(
        Map<String, dynamic>.from(json['gift'] as Map),
      ),
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: json['unit_price']?.toString() ?? '0.00',
      totalPrice: json['total_price']?.toString() ?? '0.00',
      purchasedAt: DateTime.tryParse(json['purchased_at'] as String? ?? ''),
    );
  }
}

class GiftPurchaseSummary {
  final String totalSpent;
  final int availableCount;
  final List<Gift> ownedGifts;
  final List<GiftPurchase> history;

  const GiftPurchaseSummary({
    required this.totalSpent,
    required this.availableCount,
    required this.ownedGifts,
    required this.history,
  });

  factory GiftPurchaseSummary.fromJson(Map<String, dynamic> json) {
    final owned = json['owned_gifts'];
    final history = json['history'];

    return GiftPurchaseSummary(
      totalSpent: json['total_spent']?.toString() ?? '0.00',
      availableCount: json['available_count'] as int? ?? 0,
      ownedGifts: owned is List
          ? owned
              .map(
                (item) => Gift.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(growable: false)
          : const [],
      history: history is List
          ? history
              .map(
                (item) => GiftPurchase.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}
