import '../config/api_config.dart';

class Gift {
  final int id;
  final int restaurantId;
  final String restaurantName;
  final String name;
  final String price;
  final String? imageUrl;
  final bool isActive;
  final int giftableCount;

  const Gift({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.isActive,
    this.giftableCount = 0,
  });

  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] as int,
      restaurantId: json['restaurant_id'] as int? ?? 0,
      restaurantName: json['restaurant_name'] as String? ?? '',
      name: json['name'] as String? ?? 'Подарок',
      price: json['price']?.toString() ?? '0.00',
      imageUrl: ApiConfig.resolveUrl(json['image_url'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      giftableCount: json['giftable_count'] as int? ?? 0,
    );
  }

  factory Gift.fromRealtimeJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] as int,
      restaurantId: json['restaurant_id'] as int? ?? 0,
      restaurantName: '',
      name: json['name'] as String? ?? 'Подарок',
      price: '0.00',
      imageUrl: ApiConfig.resolveUrl(json['image_url'] as String?),
      isActive: true,
    );
  }

  Gift copyWith({int? giftableCount}) {
    return Gift(
      id: id,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      name: name,
      price: price,
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
