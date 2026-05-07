class Branch {
  final String id;
  final String name;
  final String? location;

  Branch({
    required this.id,
    required this.name,
    this.location,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'location': location,
    };
  }

  @override
  String toString() => name;
}
