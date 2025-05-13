class Rental {
  final String? id;
  final String title;
  final double price;
  final Map<String, dynamic> area; // total, livingRoom, bedrooms, bathrooms
  final Map<String, dynamic> location; // short, fullAddress
  final String propertyType;
  final List<String> furniture;
  final List<String> amenities;
  final List<String> surroundings;
  final Map<String, dynamic> rentalTerms; // minimumLease, deposit, paymentMethod, renewalTerms
  final Map<String, dynamic> contactInfo; // name, phone, availableHours
  final String userId;
  final List<String> images;
  final String status;
  final DateTime createdAt;

  Rental({
    this.id,
    required this.title,
    required this.price,
    required this.area,
    required this.location,
    required this.propertyType,
    required this.furniture,
    required this.amenities,
    required this.surroundings,
    required this.rentalTerms,
    required this.contactInfo,
    required this.userId,
    required this.images,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'price': price,
    'area': {
      'total': area['total'],
      'livingRoom': area['livingRoom'],
      'bedrooms': area['bedrooms'],
      'bathrooms': area['bathrooms'],
    },
    'location': {
      'short': location['short'],
      'fullAddress': location['fullAddress'],
    },
    'propertyType': propertyType,
    'furniture': furniture,
    'amenities': amenities,
    'surroundings': surroundings,
    'rentalTerms': {
      'minimumLease': rentalTerms['minimumLease'],
      'deposit': rentalTerms['deposit'],
      'paymentMethod': rentalTerms['paymentMethod'],
      'renewalTerms': rentalTerms['renewalTerms'],
    },
    'contactInfo': {
      'name': contactInfo['name'],
      'phone': contactInfo['phone'],
      'availableHours': contactInfo['availableHours'],
    },
    'userId': userId,
    'images': images,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Rental.fromJson(Map<String, dynamic> json) => Rental(
    id: json['_id'] as String?,
    title: json['title'] as String,
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    area: {
      'total': (json['area']['total'] as num?)?.toDouble() ?? 0.0,
      'livingRoom': (json['area']['livingRoom'] as num?)?.toDouble() ?? 0.0,
      'bedrooms': (json['area']['bedrooms'] as num?)?.toDouble() ?? 0.0,
      'bathrooms': (json['area']['bathrooms'] as num?)?.toDouble() ?? 0.0,
    },
    location: {
      'short': json['location']['short'] as String,
      'fullAddress': json['location']['fullAddress'] as String,
    },
    propertyType: json['propertyType'] as String,
    furniture: List<String>.from(json['furniture'] as List),
    amenities: List<String>.from(json['amenities'] as List),
    surroundings: List<String>.from(json['surroundings'] as List),
    rentalTerms: {
      'minimumLease': json['rentalTerms']['minimumLease'] as String,
      'deposit': json['rentalTerms']['deposit'] as String,
      'paymentMethod': json['rentalTerms']['paymentMethod'] as String,
      'renewalTerms': json['rentalTerms']['renewalTerms'] as String,
    },
    contactInfo: {
      'name': json['contactInfo']['name'] as String,
      'phone': json['contactInfo']['phone'] as String,
      'availableHours': json['contactInfo']['availableHours'] as String,
    },
    userId: json['userId'] as String,
    images: List<String>.from(json['images'] as List),
    status: json['status'] as String? ?? 'available',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}