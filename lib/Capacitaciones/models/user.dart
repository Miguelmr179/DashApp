class UserModel {
  final String id;
  final String email;
  final String? role;
  final String? area;
  final String? fullName;
  final String? nomina;

  UserModel({
    required this.id,
    required this.email,
    this.role,
    this.area,
    this.fullName,
    this.nomina,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String?,
      area: json['area'] as String?,
      fullName: json['fullName'] as String?,
      nomina: json['nomina'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'area': area,
      'fullName': fullName,
      'nomina': nomina,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? role,
    String? area,
    String? fullName,
    String? nomina,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      area: area ?? this.area,
      fullName: fullName ?? this.fullName,
      nomina: nomina ?? this.nomina,
    );
  }
}
