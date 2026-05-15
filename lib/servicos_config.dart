// Configuração central de todos os serviços da barbearia
class ServicoConfig {
  final String nome;
  final double preco;
  final int duracaoMinutos;

  const ServicoConfig({
    required this.nome,
    required this.preco,
    required this.duracaoMinutos,
  });

  String get precoFormatado =>
      'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
  String get duracaoFormatada => duracaoMinutos >= 60
      ? '${duracaoMinutos ~/ 60}h${duracaoMinutos % 60 > 0 ? '${duracaoMinutos % 60}min' : ''}'
      : '${duracaoMinutos}min';
}

const Map<String, ServicoConfig> kServicosConfig = {
  'Corte completo (cabelo + barba + sobrancelha)': ServicoConfig(
    nome: 'Corte completo (cabelo + barba + sobrancelha)',
    preco: 40,
    duracaoMinutos: 60,
  ),
  'Corte de cabelo': ServicoConfig(
    nome: 'Corte de cabelo',
    preco: 25,
    duracaoMinutos: 40,
  ),
  'Barba': ServicoConfig(nome: 'Barba', preco: 10, duracaoMinutos: 15),
  'Pé do cabelo': ServicoConfig(
    nome: 'Pé do cabelo',
    preco: 8,
    duracaoMinutos: 10,
  ),
  'Cabelo + barba': ServicoConfig(
    nome: 'Cabelo + barba',
    preco: 35,
    duracaoMinutos: 60,
  ),
  'Cabelo + sobrancelha': ServicoConfig(
    nome: 'Cabelo + sobrancelha',
    preco: 30,
    duracaoMinutos: 45,
  ),
  'Barba + sobrancelha': ServicoConfig(
    nome: 'Barba + sobrancelha',
    preco: 17,
    duracaoMinutos: 20,
  ),
  'Sobrancelha': ServicoConfig(
    nome: 'Sobrancelha',
    preco: 5,
    duracaoMinutos: 5,
  ),
  'Pigmentação': ServicoConfig(
    nome: 'Pigmentação',
    preco: 12,
    duracaoMinutos: 10,
  ),
  'Relaxamento': ServicoConfig(
    nome: 'Relaxamento',
    preco: 60,
    duracaoMinutos: 90,
  ),
  'Platinado': ServicoConfig(
    nome: 'Platinado',
    preco: 120,
    duracaoMinutos: 150,
  ),
  'Luzes': ServicoConfig(nome: 'Luzes', preco: 80, duracaoMinutos: 120),
  'Hidratação capilar': ServicoConfig(
    nome: 'Hidratação capilar',
    preco: 35,
    duracaoMinutos: 40,
  ),
  'Selagem': ServicoConfig(nome: 'Selagem', preco: 90, duracaoMinutos: 120),
};

// Lista ordenada dos nomes
final List<String> kServicosNomes = kServicosConfig.keys.toList();
