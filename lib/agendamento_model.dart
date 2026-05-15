class AgendamentoModel {
  final String id;
  final String clienteUid;
  final String clienteNome;
  final String clienteTelefone;
  final String servico;
  final DateTime dataHora;
  final String status; // 'pendente', 'confirmado', 'cancelado', 'atendido'
  final bool gratis; // true se for o 6º atendimento (fidelidade)

  AgendamentoModel({
    required this.id,
    required this.clienteUid,
    required this.clienteNome,
    required this.clienteTelefone,
    required this.servico,
    required this.dataHora,
    required this.status,
    this.gratis = false,
  });

  factory AgendamentoModel.fromMap(String id, Map<String, dynamic> map) {
    return AgendamentoModel(
      id: id,
      clienteUid: map['clienteUid'] ?? '',
      clienteNome: map['clienteNome'] ?? '',
      clienteTelefone: map['clienteTelefone'] ?? '',
      servico: map['servico'] ?? '',
      dataHora: DateTime.fromMillisecondsSinceEpoch(map['dataHora'] ?? 0),
      status: map['status'] ?? 'pendente',
      gratis: map['gratis'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'clienteUid': clienteUid,
    'clienteNome': clienteNome,
    'clienteTelefone': clienteTelefone,
    'servico': servico,
    'dataHora': dataHora.millisecondsSinceEpoch,
    'status': status,
    'gratis': gratis,
  };
}
