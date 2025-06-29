class Booking {
  final String id;
  final String userId;
  final String rentalId;
  final Map<String, dynamic> customerInfo;
  final DateTime bookingDate;
  final String preferredViewingTime;
  final String status;
  final String ownerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Thông tin bài viết
  final String? rentalTitle;
  final String? rentalAddress;
  final double? rentalPrice;
  final String? rentalImage;
  final String? propertyType;
  final Map<String, dynamic>? area;
  final List<String>? amenities;
  final List<String>? furniture;
  final List<String>? surroundings;
  final Map<String, dynamic>? rentalTerms;

  // Thông tin chủ nhà
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerEmail;

  Booking({
    required this.id,
    required this.userId,
    required this.rentalId,
    required this.customerInfo,
    required this.bookingDate,
    required this.preferredViewingTime,
    required this.status,
    required this.ownerNotes,
    required this.createdAt,
    required this.updatedAt,
    this.rentalTitle,
    this.rentalAddress,
    this.rentalPrice,
    this.rentalImage,
    this.propertyType,
    this.area,
    this.amenities,
    this.furniture,
    this.surroundings,
    this.rentalTerms,
    this.ownerName,
    this.ownerPhone,
    this.ownerEmail,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      rentalId: json['rentalId']?.toString() ?? '',
      customerInfo: Map<String, dynamic>.from(json['customerInfo'] ?? {}),
      bookingDate: DateTime.parse(
          json['bookingDate'] ?? DateTime.now().toIso8601String()),
      preferredViewingTime: json['preferredViewingTime'] ?? '',
      status: json['status'] ?? 'pending',
      ownerNotes: json['ownerNotes'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      // Thông tin bài viết
      rentalTitle: json['rental']?['title'] ?? json['rentalTitle'],
      rentalAddress:
          json['rental']?['location']?['fullAddress'] ?? json['rentalAddress'],
      rentalPrice:
          (json['rental']?['price'] ?? json['rentalPrice'])?.toDouble(),
      rentalImage: json['rental']?['images']?[0] ?? json['rentalImage'],
      propertyType: json['rental']?['propertyType'] ?? json['propertyType'],
      area: json['rental']?['area'] != null
          ? Map<String, dynamic>.from(json['rental']['area'])
          : json['area'] != null
              ? Map<String, dynamic>.from(json['area'])
              : null,
      amenities: json['rental']?['amenities'] != null
          ? List<String>.from(json['rental']['amenities'])
          : json['amenities'] != null
              ? List<String>.from(json['amenities'])
              : null,
      furniture: json['rental']?['furniture'] != null
          ? List<String>.from(json['rental']['furniture'])
          : json['furniture'] != null
              ? List<String>.from(json['furniture'])
              : null,
      surroundings: json['rental']?['surroundings'] != null
          ? List<String>.from(json['rental']['surroundings'])
          : json['surroundings'] != null
              ? List<String>.from(json['surroundings'])
              : null,
      rentalTerms: json['rental']?['rentalTerms'] != null
          ? Map<String, dynamic>.from(json['rental']['rentalTerms'])
          : json['rentalTerms'] != null
              ? Map<String, dynamic>.from(json['rentalTerms'])
              : null,
      // Thông tin chủ nhà
      ownerName: json['rental']?['contactInfo']?['name'] ?? json['ownerName'],
      ownerPhone:
          json['rental']?['contactInfo']?['phone'] ?? json['ownerPhone'],
      ownerEmail:
          json['rental']?['contactInfo']?['email'] ?? json['ownerEmail'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'rentalId': rentalId,
      'customerInfo': customerInfo,
      'bookingDate': bookingDate.toIso8601String(),
      'preferredViewingTime': preferredViewingTime,
      'status': status,
      'ownerNotes': ownerNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'rentalTitle': rentalTitle,
      'rentalAddress': rentalAddress,
      'rentalPrice': rentalPrice,
      'rentalImage': rentalImage,
      'propertyType': propertyType,
      'area': area,
      'amenities': amenities,
      'furniture': furniture,
      'surroundings': surroundings,
      'rentalTerms': rentalTerms,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'ownerEmail': ownerEmail,
    };
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? rentalId,
    Map<String, dynamic>? customerInfo,
    DateTime? bookingDate,
    String? preferredViewingTime,
    String? status,
    String? ownerNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rentalTitle,
    String? rentalAddress,
    double? rentalPrice,
    String? rentalImage,
    String? propertyType,
    Map<String, dynamic>? area,
    List<String>? amenities,
    List<String>? furniture,
    List<String>? surroundings,
    Map<String, dynamic>? rentalTerms,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rentalId: rentalId ?? this.rentalId,
      customerInfo: customerInfo ?? this.customerInfo,
      bookingDate: bookingDate ?? this.bookingDate,
      preferredViewingTime: preferredViewingTime ?? this.preferredViewingTime,
      status: status ?? this.status,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rentalTitle: rentalTitle ?? this.rentalTitle,
      rentalAddress: rentalAddress ?? this.rentalAddress,
      rentalPrice: rentalPrice ?? this.rentalPrice,
      rentalImage: rentalImage ?? this.rentalImage,
      propertyType: propertyType ?? this.propertyType,
      area: area ?? this.area,
      amenities: amenities ?? this.amenities,
      furniture: furniture ?? this.furniture,
      surroundings: surroundings ?? this.surroundings,
      rentalTerms: rentalTerms ?? this.rentalTerms,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerEmail: ownerEmail ?? this.ownerEmail,
    );
  }
}
