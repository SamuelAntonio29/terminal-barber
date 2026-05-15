class UserModel {
  final String uid;
  final String nome;
  final String email;
  final String telefone;
  final String role; // 'owner' ou 'client'

  UserModel({
    required this.uid,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.role,
  });

  bool get isOwner => role == 'owner';

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      telefone: map['telefone'] ?? '',
      role: map['role'] ?? 'client',
    );
  }

  Map<String, dynamic> toMap() {
    return {'nome': nome, 'email': email, 'telefone': telefone, 'role': role};
  }
}
