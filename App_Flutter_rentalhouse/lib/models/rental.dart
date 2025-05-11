class Rental {
  final String? id;
  final String title;
  final String description;
  final double price;
  final String location;
  final String userId;
  final List<String> images;
  final DateTime createdAt;

  Rental({
    this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.userId,
    required this.images,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'description': description,
    'price': price,
    'location': location,
    'userId': userId,
    'images': images,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Rental.fromJson(Map<String, dynamic> json) => Rental(
    id: json['_id'] as String?,
    title: json['title'] as String,
    description: json['description'] as String,
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    location: json['location'] as String,
    userId: json['userId'] as String,
    images: List<String>.from(json['images'] as List),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}