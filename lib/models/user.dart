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
    required this.avatarUrl,
    required this.role,
    required this.serviceCategory,
    required this.panNumber,
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
      avatarUrl: (json['avatarUrl'] ?? '') as String,
      role: (json['role'] ?? 'user') as String,
      serviceCategory: (json['serviceCategory'] ?? '') as String,
      panNumber: (json['panNumber'] ?? '') as String,
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
  final String avatarUrl;
  final String role;
  final String serviceCategory;
  final String panNumber;

  AppUser copyWith({
    String? fullName,
    String? phone,
    num? problemsFixed,
    num? moneySaved,
    num? servicesUsed,
    bool? isProMember,
    String? avatarUrl,
    String? role,
    String? serviceCategory,
    String? panNumber,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      panNumber: panNumber ?? this.panNumber,
    );
  }
}

