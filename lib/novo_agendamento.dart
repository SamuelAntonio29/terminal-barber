import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_bar_custom.dart';
import 'notificacao_service.dart';
import 'servicos_config.dart';

class NovoAgendamento extends StatefulWidget {
  const NovoAgendamento({super.key});

  @override
  State<NovoAgendamento> createState() => _NovoAgendamentoState();
}

class _NovoAgendamentoState extends State<NovoAgendamento> {
  String? _servicoSelecionado;
  DateTime? _dataSelecionada;
  TimeOfDay? _horaSelecionada;
  bool _loading = false;
  bool _loadingHorarios = false;

  // Horários bloqueados: chave = "HH:mm", valor = minutos que aquele atendimento ocupa
  // Ex: barba às 10:00 dura 15min → bloqueia 10:00 e 10:15 ficaria o próximo
  final Map<String, int> _horariosOcupados = {};

  // Gera lista de horários disponíveis: 08h–12h e 14h–20h, de 30 em 30 min
  List<TimeOfDay> _gerarHorarios() {
    final lista = <TimeOfDay>[];
    for (int h = 8; h < 12; h++) {
      lista.add(TimeOfDay(hour: h, minute: 0));
      lista.add(TimeOfDay(hour: h, minute: 30));
    }
    for (int h = 14; h < 20; h++) {
      lista.add(TimeOfDay(hour: h, minute: 0));
      lista.add(TimeOfDay(hour: h, minute: 30));
    }
    lista.add(const TimeOfDay(hour: 20, minute: 0));
    return lista;
  }

  String _fmtHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Verifica se um horário está bloqueado considerando duração e horário atual
  bool _estaOcupado(TimeOfDay horario) {
    final minHorario = horario.hour * 60 + horario.minute;

    // ✅ Bloqueia horários que já passaram (apenas para o dia de hoje)
    if (_dataSelecionada != null) {
      final agora = DateTime.now();
      final ehHoje =
          _dataSelecionada!.year == agora.year &&
          _dataSelecionada!.month == agora.month &&
          _dataSelecionada!.day == agora.day;

      if (ehHoje) {
        final minAgora = agora.hour * 60 + agora.minute;
        // Bloqueia horários que já passaram ou que estão a menos de 30 min
        if (minHorario <= minAgora + 30) return true;
      }
    }

    // Bloqueia se cair dentro do intervalo de outro agendamento
    for (final entry in _horariosOcupados.entries) {
      final parts = entry.key.split(':');
      final minInicio = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final minFim = minInicio + entry.value;
      if (minHorario >= minInicio && minHorario < minFim) return true;
    }

    // Bloqueia se o novo atendimento conflitar com um existente
    final duracaoNovo =
        kServicosConfig[_servicoSelecionado]?.duracaoMinutos ?? 30;
    final minFimNovo = minHorario + duracaoNovo;
    for (final entry in _horariosOcupados.entries) {
      final parts = entry.key.split(':');
      final minInicio = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (minHorario < minInicio && minFimNovo > minInicio) return true;
    }

    return false;
  }

  Future<void> _buscarHorariosOcupados(DateTime data) async {
    setState(() {
      _loadingHorarios = true;
      _horariosOcupados.clear();
    });

    try {
      final inicioDia = DateTime(
        data.year,
        data.month,
        data.day,
        0,
        0,
      ).millisecondsSinceEpoch;
      final fimDia = DateTime(
        data.year,
        data.month,
        data.day,
        23,
        59,
      ).millisecondsSinceEpoch;

      final snap = await FirebaseFirestore.instance
          .collection('agendamentos')
          .where('dataHora', isGreaterThanOrEqualTo: inicioDia)
          .where('dataHora', isLessThanOrEqualTo: fimDia)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        final status = d['status'] as String? ?? '';
        if (status == 'cancelado' || status == 'atendido') continue;

        final ts = d['dataHora'] as int?;
        if (ts == null) continue;

        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final chave = _fmtHora(TimeOfDay(hour: dt.hour, minute: dt.minute));
        final servico = d['servico'] as String? ?? '';
        final duracao = kServicosConfig[servico]?.duracaoMinutos ?? 30;

        _horariosOcupados[chave] = duracao;
      }
    } catch (e) {
      debugPrint('Erro ao buscar horários: $e');
    } finally {
      if (mounted) setState(() => _loadingHorarios = false);
    }
  }

  Future<void> _salvar() async {
    if (_servicoSelecionado == null) {
      _snack('Selecione um serviço.', Colors.orange);
      return;
    }
    if (_dataSelecionada == null) {
      _snack('Selecione uma data.', Colors.orange);
      return;
    }
    if (_horaSelecionada == null) {
      _snack('Selecione um horário.', Colors.orange);
      return;
    }

    if (_estaOcupado(_horaSelecionada!)) {
      _snack(
        'Este horário acabou de ser ocupado. Escolha outro.',
        Colors.orange,
      );
      await _buscarHorariosOcupados(_dataSelecionada!);
      setState(() => _horaSelecionada = null);
      return;
    }

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final docSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final nome = docSnap.data()?['nome'] as String? ?? user.displayName ?? '';
      final telefone = docSnap.data()?['telefone'] as String? ?? '';
      final totalAtendidos = docSnap.data()?['totalAtendidos'] as int? ?? 0;
      final gratis = (totalAtendidos % 5 == 0) && totalAtendidos > 0;
      final config = kServicosConfig[_servicoSelecionado]!;

      final dataHora = DateTime(
        _dataSelecionada!.year,
        _dataSelecionada!.month,
        _dataSelecionada!.day,
        _horaSelecionada!.hour,
        _horaSelecionada!.minute,
      );

      await FirebaseFirestore.instance.collection('agendamentos').add({
        'clienteUid': user.uid,
        'clienteNome': nome,
        'clienteTelefone': telefone,
        'servico': _servicoSelecionado,
        'duracaoMinutos': config.duracaoMinutos,
        'preco': gratis ? 0.0 : config.preco,
        'gratis': gratis,
        'dataHora': dataHora.millisecondsSinceEpoch,
        'status': 'pendente',
        'criadoEm': DateTime.now().millisecondsSinceEpoch,
      });

      // Agenda notificação 1h antes
      await NotificacaoService.agendarLembrete(
        id: NotificacaoService.gerarId(dataHora),
        servico: _servicoSelecionado!,
        dataHora: dataHora,
        minutesAntes: 60,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gratis
                ? '🎉 Agendamento grátis realizado!'
                : '✅ Agendamento realizado! Lembrete 1h antes.',
          ),
          backgroundColor: gratis ? const Color(0xFFD4A017) : Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao agendar: ${e.toString()}', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD4A017);
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final hintColor = isDark ? Colors.white54 : Colors.black45;
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    final horariosTodos = _gerarHorarios();
    final servicoConfig = kServicosConfig[_servicoSelecionado];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const AppBarCustom(title: 'Novo Agendamento', showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── AVISO DE POLÍTICA ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Atenção: caso não compareça e não cancele o agendamento com antecedência, o valor do serviço deverá ser pago na próxima visita.',
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SERVIÇO ──
              Text(
                'Serviço',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _servicoSelecionado != null ? gold : borderColor,
                    width: _servicoSelecionado != null ? 1.5 : 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _servicoSelecionado,
                    isExpanded: true,
                    dropdownColor: cardColor,
                    hint: Text(
                      'Selecione o serviço',
                      style: TextStyle(color: hintColor),
                    ),
                    style: TextStyle(color: textColor, fontSize: 14),
                    icon: Icon(Icons.keyboard_arrow_down, color: hintColor),
                    items: kServicosNomes.map((s) {
                      final cfg = kServicosConfig[s]!;
                      return DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cfg.precoFormatado,
                              style: TextStyle(
                                color: gold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() {
                      _servicoSelecionado = v;
                      _horaSelecionada =
                          null; // reseta horário ao trocar serviço
                    }),
                  ),
                ),
              ),

              // Info do serviço selecionado
              if (servicoConfig != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_money, color: gold, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            servicoConfig.precoFormatado,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: gold, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            servicoConfig.duracaoFormatada,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── DATA ──
              Text(
                'Data',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  if (_servicoSelecionado == null) {
                    _snack('Selecione o serviço primeiro.', Colors.orange);
                    return;
                  }
                  // Se já passou das 20h, o dia de hoje não tem mais horários
                  final agora = DateTime.now();
                  final primeiroDia = (agora.hour >= 20)
                      ? agora.add(const Duration(days: 1))
                      : agora;

                  final picked = await showDatePicker(
                    context: context,
                    initialDate: primeiroDia,
                    firstDate: primeiroDia,
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    locale: const Locale('pt', 'BR'),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: gold,
                          brightness: isDark
                              ? Brightness.dark
                              : Brightness.light,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _dataSelecionada = picked;
                      _horaSelecionada = null;
                    });
                    await _buscarHorariosOcupados(picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _dataSelecionada != null ? gold : borderColor,
                      width: _dataSelecionada != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: _dataSelecionada != null ? gold : hintColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _dataSelecionada != null
                            ? '${_dataSelecionada!.day.toString().padLeft(2, '0')}/'
                                  '${_dataSelecionada!.month.toString().padLeft(2, '0')}/'
                                  '${_dataSelecionada!.year}'
                            : _servicoSelecionado != null
                            ? 'Selecione a data'
                            : 'Selecione o serviço primeiro',
                        style: TextStyle(
                          color: _dataSelecionada != null
                              ? textColor
                              : hintColor,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── HORÁRIOS ──
              if (_dataSelecionada != null && _servicoSelecionado != null) ...[
                Row(
                  children: [
                    Text(
                      'Horário',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(08h–12h e 14h–20h)',
                      style: TextStyle(color: hintColor, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Legenda
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _LegendaItem(color: gold, label: 'Selecionado'),
                    _LegendaItem(
                      color: Colors.green.withOpacity(0.15),
                      label: 'Disponível',
                      borderColor: Colors.green,
                    ),
                    _LegendaItem(
                      color: Colors.redAccent.withOpacity(0.15),
                      label: 'Ocupado',
                      borderColor: Colors.redAccent,
                    ),
                    _LegendaItem(
                      color: Colors.grey.withOpacity(0.15),
                      label: 'Passado',
                      borderColor: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_loadingHorarios)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Text(
                    'Manhã',
                    style: TextStyle(
                      color: hintColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GradeHorarios(
                    horarios: horariosTodos.where((t) => t.hour < 12).toList(),
                    selecionado: _horaSelecionada,
                    estaOcupado: _estaOcupado,
                    dataSelecionada: _dataSelecionada,
                    gold: gold,
                    textColor: textColor,
                    cardColor: cardColor,
                    onSelect: (t) => setState(() => _horaSelecionada = t),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tarde',
                    style: TextStyle(
                      color: hintColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GradeHorarios(
                    horarios: horariosTodos.where((t) => t.hour >= 14).toList(),
                    selecionado: _horaSelecionada,
                    estaOcupado: _estaOcupado,
                    dataSelecionada: _dataSelecionada,
                    gold: gold,
                    textColor: textColor,
                    cardColor: cardColor,
                    onSelect: (t) => setState(() => _horaSelecionada = t),
                  ),
                ],
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _servicoSelecionado == null
                        ? 'Selecione um serviço e uma data para ver os horários.'
                        : 'Selecione uma data para ver os horários disponíveis.',
                    style: TextStyle(color: hintColor, fontSize: 13),
                  ),
                ),

              const SizedBox(height: 24),

              // ── RESUMO ──
              if (_servicoSelecionado != null &&
                  _dataSelecionada != null &&
                  _horaSelecionada != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: gold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumo',
                        style: TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ResumoLinha(
                        icon: Icons.content_cut,
                        texto: _servicoSelecionado!,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 6),
                      _ResumoLinha(
                        icon: Icons.calendar_today_outlined,
                        texto:
                            '${_dataSelecionada!.day.toString().padLeft(2, '0')}/'
                            '${_dataSelecionada!.month.toString().padLeft(2, '0')}/'
                            '${_dataSelecionada!.year} às ${_fmtHora(_horaSelecionada!)}',
                        textColor: textColor,
                      ),
                      const SizedBox(height: 6),
                      _ResumoLinha(
                        icon: Icons.timer_outlined,
                        texto:
                            'Duração: ${servicoConfig?.duracaoFormatada ?? ''}',
                        textColor: textColor,
                      ),
                      const SizedBox(height: 6),
                      _ResumoLinha(
                        icon: Icons.attach_money,
                        texto: 'Valor: ${servicoConfig?.precoFormatado ?? ''}',
                        textColor: textColor,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          '⚠️ Não comparecendo sem cancelar, o valor será cobrado na próxima visita.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── BOTÃO CONFIRMAR ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: gold.withOpacity(0.5),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Confirmar Agendamento',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumoLinha extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color textColor;
  const _ResumoLinha({
    required this.icon,
    required this.texto,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD4A017)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto, style: TextStyle(color: textColor, fontSize: 13)),
        ),
      ],
    );
  }
}

class _LegendaItem extends StatelessWidget {
  final Color color;
  final String label;
  final Color? borderColor;
  const _LegendaItem({
    required this.color,
    required this.label,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor ?? color),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _GradeHorarios extends StatelessWidget {
  final List<TimeOfDay> horarios;
  final TimeOfDay? selecionado;
  final bool Function(TimeOfDay) estaOcupado;
  final DateTime? dataSelecionada;
  final Color gold, textColor, cardColor;
  final void Function(TimeOfDay) onSelect;

  const _GradeHorarios({
    required this.horarios,
    required this.selecionado,
    required this.estaOcupado,
    this.dataSelecionada,
    required this.gold,
    required this.textColor,
    required this.cardColor,
    required this.onSelect,
  });

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Verifica se é horário passado (hoje e já passou)
  bool _estaNoPassado(TimeOfDay t) {
    // Não temos acesso direto à data aqui, mas o estaOcupado já lida com isso
    // Esta função é apenas para diferenciar o ícone visual
    return false; // Tratado dentro do estaOcupado
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final minAgora = agora.hour * 60 + agora.minute;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: horarios.map((t) {
        final ocupado = estaOcupado(t);
        final minT = t.hour * 60 + t.minute;
        final ehPassado =
            dataSelecionada != null &&
            dataSelecionada!.year == agora.year &&
            dataSelecionada!.month == agora.month &&
            dataSelecionada!.day == agora.day &&
            minT <= minAgora + 30;

        final sel =
            !ocupado &&
            selecionado?.hour == t.hour &&
            selecionado?.minute == t.minute;

        Color bg, border, txt;
        IconData? icone;
        TextDecoration? deco;

        if (sel) {
          bg = gold;
          border = gold;
          txt = Colors.black;
        } else if (ehPassado) {
          // Horário passado — cinza
          bg = Colors.grey.withOpacity(0.1);
          border = Colors.grey.withOpacity(0.3);
          txt = Colors.grey.withOpacity(0.5);
          icone = Icons.history;
          deco = TextDecoration.lineThrough;
        } else if (ocupado) {
          // Ocupado por outro cliente — vermelho
          bg = Colors.redAccent.withOpacity(0.12);
          border = Colors.redAccent.withOpacity(0.5);
          txt = Colors.redAccent.withOpacity(0.6);
          icone = Icons.person_off_outlined;
          deco = TextDecoration.lineThrough;
        } else {
          // Disponível — verde
          bg = Colors.green.withOpacity(0.08);
          border = Colors.green.withOpacity(0.5);
          txt = textColor;
        }

        return GestureDetector(
          onTap: ocupado ? null : () => onSelect(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: sel ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icone != null) ...[
                  Icon(icone, size: 11, color: txt),
                  const SizedBox(width: 3),
                ],
                Text(
                  _fmt(t),
                  style: TextStyle(
                    color: txt,
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    decoration: deco,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
