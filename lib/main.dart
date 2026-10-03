import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'countdown.dart';
import 'src/glasses_sdk.dart';

void main() => runApp(const YosakoiApp());

class YosakoiApp extends StatelessWidget {
  const YosakoiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'よさこい集合時計',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ja'),
    supportedLocales: const [Locale('ja')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffad352e)),
      scaffoldBackgroundColor: const Color(0xfffaf7f2),
    ),
    home: const CountdownPage(),
  );
}

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});
  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage>
    with WidgetsBindingObserver {
  final _team = TextEditingController(), _venue = TextEditingController();
  Gathering? _gathering;
  DateTime _date = DateTime.now(), _now = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  Timer? _timer;
  StreamSubscription<GlassConnectionState>? _subscription;
  GlassConnectionState _connection = GlassConnectionState.disconnected;
  bool _loading = true,
      _connecting = false,
      _sending = false,
      _saving = false,
      _pageReady = false;
  String? _sentText, _error;
  bool get _supportsGlass =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_supportsGlass) {
      _subscription = GlassesSdk.instance.connectionState.listen(
        (state) {
          if (!mounted) return;
          setState(() {
            _connection = state;
            _pageReady = false;
            _sentText = null;
          });
          _syncGlass();
        },
        onError: (_) {
          if (mounted) {
            setState(() => _error = '接続状態を確認できません。SABERAを再接続してください。');
          }
        },
      );
    }
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('gathering');
      if (!mounted) return;
      if (saved != null) {
        final fields = saved.split('\n');
        final at = DateTime.tryParse(fields.first);
        if (at != null && fields.length == 3) {
          _gathering = Gathering(at: at, team: fields[1], venue: fields[2]);
          _team.text = fields[1];
          _venue.text = fields[2];
          _date = at;
          _time = TimeOfDay.fromDateTime(at);
        }
      }
    } catch (_) {
      if (mounted) _error = '保存した集合予定を読み込めませんでした。再設定してください。';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _syncGlass();
      }
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _syncGlass();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pageReady = false;
      _sentText = null;
      _tick();
    }
  }

  Future<void> _syncGlass() async {
    if (_sending || !_connection.connected || _gathering == null) return;
    final text = _gathering!.glassText(_now);
    if (text == _sentText) return;
    _sending = true;
    try {
      if (!_pageReady) {
        await GlassesSdk.instance.enterTeleprompterPage();
        _pageReady = true;
      }
      await GlassesSdk.instance.sendTeleprompterContent(text);
      _sentText = text;
    } catch (_) {
      if (mounted) setState(() => _error = 'グラスへの送信に失敗しました。接続を確認し、再送してください。');
      _sentText = text; // Prevent repeated commands after an error.
      _pageReady = false;
    } finally {
      _sending = false;
    }
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await GlassesSdk.instance.showSelectionDialog();
    } catch (_) {
      if (mounted) {
        setState(() => _error = '接続できませんでした。Bluetoothと付近のデバイスの許可を確認してください。');
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _save() async {
    final at = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (!at.isAfter(DateTime.now())) {
      setState(() => _error = 'これからの集合日・時刻を選んでください。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final gathering = Gathering(
      at: at,
      team: _team.text.trim(),
      venue: _venue.text.trim(),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(
        'gathering',
        '${at.toIso8601String()}\n${gathering.team}\n${gathering.venue}',
      );
      if (!ok) throw StateError('Save failed');
      if (!mounted) return;
      setState(() {
        _gathering = gathering;
        _now = DateTime.now();
        _sentText = null;
      });
      await _syncGlass();
    } catch (_) {
      if (mounted) setState(() => _error = '集合予定を保存できませんでした。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final last = DateTime(today.year + 2, today.month, today.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) || _date.isAfter(last) ? today : _date,
      firstDate: today,
      lastDate: last,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _subscription?.cancel();
    _team.dispose();
    _venue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gathering = _gathering;
    final minutes = gathering?.remainingMinutes(_now);
    final urgent = gathering != null && minutes! <= 10;
    return Scaffold(
      appBar: AppBar(
        title: const Text('よさこい集合時計'),
        backgroundColor: Colors.transparent,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '踊る準備を、心おきなく。',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '現在 ${clock(_now)} ・この端末の時刻で表示',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color:
                                  urgent
                                      ? const Color(0xffad352e)
                                      : const Color(0xff183e3a),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '演舞の集合まで',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  gathering == null ? '—' : '$minutes',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 88,
                                    height: 1.1,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '分',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  gathering?.status(_now) ?? '集合時刻を設定しましょう',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                if (gathering != null) ...[
                                  const SizedBox(height: 18),
                                  Text(
                                    '${gathering.at.month}/${gathering.at.day} ${clock(gathering.at)} 集合',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  if (gathering.team.isNotEmpty)
                                    Text(
                                      gathering.team,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (gathering.venue.isNotEmpty)
                                    Text(
                                      gathering.venue,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '集合予定',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _team,
                            maxLength: 24,
                            decoration: const InputDecoration(
                              labelText: 'チーム名（任意）',
                              hintText: '例：よさこい鳴子連',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _venue,
                            maxLength: 40,
                            decoration: const InputDecoration(
                              labelText: '集合場所（任意）',
                              hintText: '例：中央公園・ステージ裏',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  '${_date.year}/${_date.month}/${_date.day}',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _time,
                                    builder:
                                        (context, child) => MediaQuery(
                                          data: MediaQuery.of(context).copyWith(
                                            alwaysUse24HourFormat: true,
                                          ),
                                          child: child!,
                                        ),
                                  );
                                  if (time != null && mounted) {
                                    setState(() => _time = time);
                                  }
                                },
                                icon: const Icon(Icons.schedule),
                                label: Text(
                                  '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? '保存中…' : 'この予定でカウントダウン'),
                          ),
                          const SizedBox(height: 24),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _connection.connected
                                            ? Icons.bluetooth_connected
                                            : Icons.bluetooth,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _connection.connected
                                              ? 'SABERA 接続中'
                                              : 'SABERA 未接続',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _supportsGlass
                                        ? '接続するとグラスにも残り時間を表示します。'
                                        : 'グラスとの接続はAndroid / iPhoneアプリで利用できます。',
                                  ),
                                  if (_supportsGlass)
                                    TextButton(
                                      onPressed:
                                          _connecting
                                              ? null
                                              : _connection.connected
                                              ? () {
                                                _sentText = null;
                                                _pageReady = false;
                                                _error = null;
                                                _syncGlass();
                                              }
                                              : _connect,
                                      child: Text(
                                        _connecting
                                            ? 'デバイスを選択中…'
                                            : _connection.connected
                                            ? 'グラスに再送'
                                            : 'SABERAを接続',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Text(
                            '残り時間は分単位で切り上げ表示します。自動更新を続ける間は、アプリを開いたままにしてください。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}
