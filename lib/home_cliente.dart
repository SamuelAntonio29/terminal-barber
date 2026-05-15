import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login.dart';
import 'main.dart';
import 'agendamento_model.dart';
import 'novo_agendamento.dart';
import 'perfil_cliente.dart';

class HomeCliente extends StatelessWidget {
  const HomeCliente({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD4A017);
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final hintColor = isDark ? Colors.white54 : Colors.black45;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Image.asset(
          'assets/images/logo.png',
          height: 38,
          fit: BoxFit.contain,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
            ),
            onPressed: () => MyApp.of(context)?.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Meu perfil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PerfilCliente()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const Login()),
                (r) => false,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NovoAgendamento()),
        ),
        backgroundColor: gold,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Agendar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, ${user?.displayName ?? 'Cliente'} 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),

              // ── CARTÃO FIDELIDADE ──
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(user?.uid)
                    .snapshots(),
                builder: (context, snap) {
                  final total =
                      (snap.data?.data() as Map?)?['totalAtendidos'] as int? ??
                      0;
                  final progresso = total % 5;
                  final gratuitos = total ~/ 5;
                  return _CartaoFidelidade(
                    progresso: progresso,
                    gratuitos: gratuitos,
                    cardColor: cardColor,
                    textColor: textColor,
                    hintColor: hintColor,
                    gold: gold,
                  );
                },
              ),

              const SizedBox(height: 20),
              Text(
                'Seus agendamentos',
                style: TextStyle(
                  color: hintColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // ── LISTA DE AGENDAMENTOS ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('agendamentos')
                      .where('clienteUid', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Erro: ${snap.error}',
                          style: TextStyle(color: hintColor),
                        ),
                      );
                    }

                    final docs = (snap.data?.docs ?? [])
                      ..sort((a, b) {
                        final aT = (a.data() as Map)['dataHora'] as int? ?? 0;
                        final bT = (b.data() as Map)['dataHora'] as int? ?? 0;
                        return bT.compareTo(aT);
                      });

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 64,
                              color: hintColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum agendamento',
                              style: TextStyle(color: hintColor, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Toque em "Agendar" para marcar um horário',
                              style: TextStyle(color: hintColor, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final ag = AgendamentoModel.fromMap(
                          docs[i].id,
                          docs[i].data() as Map<String, dynamic>,
                        );
                        return AgendamentoCard(
                          ag: ag,
                          cardColor: cardColor,
                          textColor: textColor,
                          hintColor: hintColor,
                          gold: gold,
                          isOwner: false,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CARTÃO FIDELIDADE ──
class _CartaoFidelidade extends StatelessWidget {
  final int progresso, gratuitos;
  final Color cardColor, textColor, hintColor, gold;

  const _CartaoFidelidade({
    required this.progresso,
    required this.gratuitos,
    required this.cardColor,
    required this.textColor,
    required this.hintColor,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.loyalty, color: gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cartão Fidelidade',
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (gratuitos > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🎉 $gratuitos grátis disponível',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final preenchido = i < progresso;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Container(
                        height: 36,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: preenchido ? gold : gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gold.withOpacity(0.4)),
                        ),
                        child: Icon(
                          preenchido
                              ? Icons.content_cut
                              : Icons.content_cut_outlined,
                          color: preenchido
                              ? Colors.black
                              : gold.withOpacity(0.4),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            progresso == 0 && gratuitos == 0
                ? 'Faça 5 atendimentos e ganhe 1 grátis!'
                : '$progresso de 5 atendimentos — falta ${5 - progresso} para o próximo grátis!',
            style: TextStyle(color: hintColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// CARD DE AGENDAMENTO
// ─────────────────────────────────────────────────────────────────
class AgendamentoCard extends StatelessWidget {
  final AgendamentoModel ag;
  final Color cardColor, textColor, hintColor, gold;
  final bool isOwner;
  final VoidCallback? onConfirmar;
  final VoidCallback? onCancelar;
  final VoidCallback? onAtendido;

  const AgendamentoCard({
    super.key,
    required this.ag,
    required this.cardColor,
    required this.textColor,
    required this.hintColor,
    required this.gold,
    required this.isOwner,
    this.onConfirmar,
    this.onCancelar,
    this.onAtendido,
  });

  Color get _statusColor {
    switch (ag.status) {
      case 'confirmado':
        return Colors.green;
      case 'cancelado':
        return Colors.redAccent;
      case 'atendido':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (ag.status) {
      case 'confirmado':
        return 'Confirmado';
      case 'cancelado':
        return 'Cancelado';
      case 'atendido':
        return 'Atendido ✓';
      default:
        return 'Pendente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = ag.dataHora;
    final dataStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final horaStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (ag.gratis) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🎉 GRÁTIS',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Icon(Icons.access_time, size: 13, color: hintColor),
              const SizedBox(width: 4),
              Text(
                '$dataStr às $horaStr',
                style: TextStyle(color: hintColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ag.servico,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          // Info do cliente (owner)
          if (isOwner) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: hintColor),
                const SizedBox(width: 4),
                Text(
                  ag.clienteNome,
                  style: TextStyle(color: hintColor, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Icon(Icons.phone_outlined, size: 13, color: hintColor),
                const SizedBox(width: 4),
                Text(
                  ag.clienteTelefone,
                  style: TextStyle(color: hintColor, fontSize: 13),
                ),
              ],
            ),
          ],

          // Botões do owner
          if (isOwner && ag.status == 'pendente') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancelar,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onConfirmar,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Confirmar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Botão "Marcar como Atendido" — só aparece se confirmado
          if (isOwner && ag.status == 'confirmado') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAtendido,
                icon: const Icon(Icons.how_to_reg, size: 16),
                label: const Text('Marcar como Atendido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],

          // Botão cancelar do cliente
          if (!isOwner && ag.status == 'pendente') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('agendamentos')
                      .doc(ag.id)
                      .update({'status': 'cancelado'});
                },
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancelar agendamento'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
