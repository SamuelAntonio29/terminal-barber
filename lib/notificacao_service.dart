import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificacaoService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _iniciado = false;

  // ── Inicializa o serviço (chamar no main) ──
  static Future<void> init() async {
    if (_iniciado) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Solicita permissão no Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _iniciado = true;
  }

  // ── Agenda notificação 1h antes do atendimento ──
  static Future<void> agendarLembrete({
    required int id,
    required String servico,
    required DateTime dataHora,
    required int minutesAntes, // 60 = 1h antes, 30 = 30min antes
  }) async {
    final horarioNotif = dataHora.subtract(Duration(minutes: minutesAntes));

    // Só agenda se ainda está no futuro
    if (horarioNotif.isBefore(DateTime.now())) return;

    final tzHorario = tz.TZDateTime.from(horarioNotif, tz.local);

    final h = dataHora.hour.toString().padLeft(2, '0');
    final m = dataHora.minute.toString().padLeft(2, '0');
    final d = dataHora.day.toString().padLeft(2, '0');
    final mo = dataHora.month.toString().padLeft(2, '0');

    await _plugin.zonedSchedule(
      id,
      '✂️ Lembrete de agendamento',
      '$servico — hoje às $h:$m ($d/$mo). Não esqueça!',
      tzHorario,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'agendamento_channel',
          'Agendamentos',
          channelDescription: 'Lembretes de agendamentos na barbearia',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Cancela notificação (ex: quando cancela o agendamento) ──
  static Future<void> cancelar(int id) async {
    await _plugin.cancel(id);
  }

  // ── Cancela todas ──
  static Future<void> cancelarTodas() async {
    await _plugin.cancelAll();
  }

  // ── Gera ID único baseado no timestamp ──
  static int gerarId(DateTime dataHora) {
    return dataHora.millisecondsSinceEpoch ~/ 1000 % 2147483647;
  }
}
