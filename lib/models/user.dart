class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.problemsFixed,
    required this.moneySaved,
    required this.servicesUsed,
    required this.isProMember,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: (json['phone'] ?? '') as String,
      problemsFixed: (json['problemsFixed'] ?? 0) as num,
      moneySaved: (json['moneySaved'] ?? 0) as num,
      servicesUsed: (json['servicesUsed'] ?? 0) as num,
      isProMember: (json['isProMember'] ?? false) as bool,
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final num problemsFixed;
  final num moneySaved;
  final num servicesUsed;
  final bool isProMember;

  AppUser copyWith({
    String? fullName,
    String? phone,
    num? problemsFixed,
    num? moneySaved,
    num? servicesUsed,
    bool? isProMember,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      problemsFixed: problemsFixed ?? this.problemsFixed,
      moneySaved: moneySaved ?? this.moneySaved,
      servicesUsed: servicesUsed ?? this.servicesUsed,
      isProMember: isProMember ?? this.isProMember,
    );
  }
}

