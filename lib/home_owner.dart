import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login.dart';
import 'main.dart';
import 'agendamento_model.dart';
import 'home_cliente.dart';

class HomeOwner extends StatefulWidget {
  const HomeOwner({super.key});

  @override
  State<HomeOwner> createState() => _HomeOwnerState();
}

class _HomeOwnerState extends State<HomeOwner>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _marcarAtendido(AgendamentoModel ag) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(ag.clienteUid);

      final userDoc = await userRef.get();
      final totalAtual = (userDoc.data()?['totalAtendidos'] as int? ?? 0);
      final novoTotal = totalAtual + 1;

      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('agendamentos').doc(ag.id),
        {'status': 'atendido'},
      );
      batch.update(userRef, {'totalAtendidos': FieldValue.increment(1)});
      await batch.commit();

      if (novoTotal % 5 == 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 ${ag.clienteNome} ganhou um atendimento GRÁTIS! (${novoTotal ~/ 5}º prêmio)',
            ),
            backgroundColor: const Color(0xFFD4A017),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${ag.clienteNome} marcado como atendido!'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _atualizarStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('agendamentos').doc(id).update({
      'status': status,
    });
  }

  @override
  Widget build(BuildContext context) {
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: gold,
          labelColor: gold,
          unselectedLabelColor: hintColor,
          tabs: const [
            Tab(
              icon: Icon(Icons.calendar_month_outlined),
              text: 'Agendamentos',
            ),
            Tab(icon: Icon(Icons.people_outline), text: 'Clientes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AbaAgendamentos(
            cardColor: cardColor,
            textColor: textColor,
            hintColor: hintColor,
            gold: gold,
            onAtualizar: _atualizarStatus,
            onAtendido: _marcarAtendido,
          ),
          _AbaClientes(
            cardColor: cardColor,
            textColor: textColor,
            hintColor: hintColor,
            gold: gold,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// ABA AGENDAMENTOS COM FILTRO DE DATA
// ──────────────────────────────────────────────
class _AbaAgendamentos extends StatefulWidget {
  final Color cardColor, textColor, hintColor, gold;
  final Future<void> Function(String, String) onAtualizar;
  final Future<void> Function(AgendamentoModel) onAtendido;

  const _AbaAgendamentos({
    required this.cardColor,
    required this.textColor,
    required this.hintColor,
    required this.gold,
    required this.onAtualizar,
    required this.onAtendido,
  });

  @override
  State<_AbaAgendamentos> createState() => _AbaAgendamentosState();
}

class _AbaAgendamentosState extends State<_AbaAgendamentos> {
  String _filtroStatus = 'todos';
  DateTime _dataSelecionada = DateTime.now(); // começa com hoje
  bool _filtroPorDia = true; // começa filtrando por dia

  String _fmtData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  bool _ehHoje(DateTime d) {
    final agora = DateTime.now();
    return d.year == agora.year && d.month == agora.month && d.day == agora.day;
  }

  Future<void> _selecionarData() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: widget.gold,
            brightness: isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dataSelecionada = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── CABEÇALHO DE DATA ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Toggle: filtrar por dia ou ver todos
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _filtroPorDia = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _filtroPorDia ? widget.gold : widget.cardColor,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10),
                          ),
                          border: Border.all(
                            color: widget.gold.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.today,
                              size: 16,
                              color: _filtroPorDia ? Colors.black : widget.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Por dia',
                              style: TextStyle(
                                color: _filtroPorDia
                                    ? Colors.black
                                    : widget.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _filtroPorDia = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_filtroPorDia
                              ? widget.gold
                              : widget.cardColor,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(10),
                          ),
                          border: Border.all(
                            color: widget.gold.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: !_filtroPorDia
                                  ? Colors.black
                                  : widget.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Todos',
                              style: TextStyle(
                                color: !_filtroPorDia
                                    ? Colors.black
                                    : widget.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Seletor de data (só aparece no modo "Por dia")
              if (_filtroPorDia) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Botão dia anterior
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: widget.gold),
                      onPressed: () => setState(
                        () => _dataSelecionada = _dataSelecionada.subtract(
                          const Duration(days: 1),
                        ),
                      ),
                    ),

                    // Data atual clicável
                    Expanded(
                      child: GestureDetector(
                        onTap: _selecionarData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: widget.cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: widget.gold.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: widget.gold,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _ehHoje(_dataSelecionada)
                                    ? 'Hoje — ${_fmtData(_dataSelecionada)}'
                                    : _fmtData(_dataSelecionada),
                                style: TextStyle(
                                  color: widget.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.edit_calendar_outlined,
                                size: 14,
                                color: widget.hintColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Botão próximo dia
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: widget.gold),
                      onPressed: () => setState(
                        () => _dataSelecionada = _dataSelecionada.add(
                          const Duration(days: 1),
                        ),
                      ),
                    ),

                    // Botão voltar para hoje
                    if (!_ehHoje(_dataSelecionada))
                      TextButton(
                        onPressed: () =>
                            setState(() => _dataSelecionada = DateTime.now()),
                        child: Text(
                          'Hoje',
                          style: TextStyle(
                            color: widget.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Filtros de status
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      [
                        'todos',
                        'pendente',
                        'confirmado',
                        'atendido',
                        'cancelado',
                      ].map((f) {
                        final sel = _filtroStatus == f;
                        final label = f == 'todos'
                            ? 'Todos'
                            : f[0].toUpperCase() + f.substring(1);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(label),
                            selected: sel,
                            onSelected: (_) =>
                                setState(() => _filtroStatus = f),
                            selectedColor: widget.gold.withOpacity(0.2),
                            checkmarkColor: widget.gold,
                            labelStyle: TextStyle(
                              color: sel ? widget.gold : widget.hintColor,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: sel ? widget.gold : Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),

        // ── LISTA DE AGENDAMENTOS ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('agendamentos')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Erro: ${snap.error}',
                    style: TextStyle(color: widget.hintColor),
                  ),
                );
              }

              var docs = snap.data?.docs ?? [];

              // Filtro por dia
              if (_filtroPorDia) {
                final inicioDia = DateTime(
                  _dataSelecionada.year,
                  _dataSelecionada.month,
                  _dataSelecionada.day,
                ).millisecondsSinceEpoch;
                final fimDia = DateTime(
                  _dataSelecionada.year,
                  _dataSelecionada.month,
                  _dataSelecionada.day,
                  23,
                  59,
                  59,
                ).millisecondsSinceEpoch;

                docs = docs.where((d) {
                  final ts = (d.data() as Map)['dataHora'] as int? ?? 0;
                  return ts >= inicioDia && ts <= fimDia;
                }).toList();
              }

              // Filtro por status
              if (_filtroStatus != 'todos') {
                docs = docs
                    .where((d) => (d.data() as Map)['status'] == _filtroStatus)
                    .toList();
              }

              // Ordena por horário
              docs.sort((a, b) {
                final aT = (a.data() as Map)['dataHora'] as int? ?? 0;
                final bT = (b.data() as Map)['dataHora'] as int? ?? 0;
                return aT.compareTo(bT);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 56,
                        color: widget.hintColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filtroPorDia
                            ? _ehHoje(_dataSelecionada)
                                  ? 'Nenhum agendamento hoje.'
                                  : 'Nenhum agendamento em ${_fmtData(_dataSelecionada)}.'
                            : 'Nenhum agendamento encontrado.',
                        style: TextStyle(color: widget.hintColor, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // Contador resumo do dia
              return Column(
                children: [
                  if (_filtroPorDia)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: widget.hintColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${docs.length} agendamento${docs.length != 1 ? 's' : ''} '
                            '${_ehHoje(_dataSelecionada) ? 'hoje' : 'neste dia'}',
                            style: TextStyle(
                              color: widget.hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final ag = AgendamentoModel.fromMap(
                          docs[i].id,
                          docs[i].data() as Map<String, dynamic>,
                        );
                        return AgendamentoCard(
                          ag: ag,
                          cardColor: widget.cardColor,
                          textColor: widget.textColor,
                          hintColor: widget.hintColor,
                          gold: widget.gold,
                          isOwner: true,
                          onConfirmar: () =>
                              widget.onAtualizar(ag.id, 'confirmado'),
                          onCancelar: () =>
                              widget.onAtualizar(ag.id, 'cancelado'),
                          onAtendido: () => widget.onAtendido(ag),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// ABA CLIENTES
// ──────────────────────────────────────────────
class _AbaClientes extends StatelessWidget {
  final Color cardColor, textColor, hintColor, gold;

  const _AbaClientes({
    required this.cardColor,
    required this.textColor,
    required this.hintColor,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('role', isEqualTo: 'client')
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

        final clientes = (snap.data?.docs ?? [])
          ..sort((a, b) {
            final nA = (a.data() as Map)['nome'] as String? ?? '';
            final nB = (b.data() as Map)['nome'] as String? ?? '';
            return nA.toLowerCase().compareTo(nB.toLowerCase());
          });

        if (clientes.isEmpty) {
          return Center(
            child: Text(
              'Nenhum cliente cadastrado.',
              style: TextStyle(color: hintColor),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clientes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = clientes[i].data() as Map<String, dynamic>;
            final uid = clientes[i].id;
            final nome = data['nome'] as String? ?? '';
            final telefone = data['telefone'] as String? ?? '';
            final email = data['email'] as String? ?? '';
            final total = data['totalAtendidos'] as int? ?? 0;
            final progresso = total % 5;
            final gratuitos = total ~/ 5;

            return Container(
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
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: CircleAvatar(
                  backgroundColor: gold.withOpacity(0.15),
                  child: Text(
                    nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                    style: TextStyle(color: gold, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      nome,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (gratuitos > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🎉 $gratuitos grátis',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 12, color: hintColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            telefone.isNotEmpty ? telefone : 'Sem telefone',
                            style: TextStyle(color: hintColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.loyalty, size: 12, color: gold),
                        const SizedBox(width: 4),
                        Text(
                          '$progresso/5 atendimentos',
                          style: TextStyle(color: hintColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: hintColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              email,
                              style: TextStyle(color: hintColor, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(5, (i) {
                            final ok = i < progresso;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: ok ? gold : gold.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: gold.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.content_cut,
                                    size: 14,
                                    color: ok
                                        ? Colors.black
                                        : gold.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Agendamentos',
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('agendamentos')
                              .where('clienteUid', isEqualTo: uid)
                              .snapshots(),
                          builder: (context, snapAg) {
                            if (snapAg.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 24,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            final ags = (snapAg.data?.docs ?? [])
                              ..sort((a, b) {
                                final aT =
                                    (a.data() as Map)['dataHora'] as int? ?? 0;
                                final bT =
                                    (b.data() as Map)['dataHora'] as int? ?? 0;
                                return bT.compareTo(aT);
                              });

                            if (ags.isEmpty) {
                              return Text(
                                'Nenhum agendamento.',
                                style: TextStyle(
                                  color: hintColor,
                                  fontSize: 13,
                                ),
                              );
                            }

                            return Column(
                              children: ags.map((d) {
                                final ag = AgendamentoModel.fromMap(
                                  d.id,
                                  d.data() as Map<String, dynamic>,
                                );
                                final dt = ag.dataHora;
                                final dtStr =
                                    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
                                    ' às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                final statusColor = ag.status == 'atendido'
                                    ? Colors.blue
                                    : ag.status == 'confirmado'
                                    ? Colors.green
                                    : ag.status == 'cancelado'
                                    ? Colors.redAccent
                                    : Colors.orange;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    ag.servico,
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (ag.gratis)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: gold,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'GRÁTIS',
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            Text(
                                              dtStr,
                                              style: TextStyle(
                                                color: hintColor,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
