import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

void main() {
  runApp(const LettersToGodApp());
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> fontNotifier = ValueNotifier('sans-serif');

class LettersToGodApp extends StatelessWidget {
  const LettersToGodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, _) {
        return MaterialApp(
          title: 'Letters to God',
          themeMode: currentTheme,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.amber,
            scaffoldBackgroundColor: const Color(0xFFFBF9F5),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF3EFE6),
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.amber,
            scaffoldBackgroundColor: const Color(0xFF101014),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF18181F),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          home: const LockGateKeeper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class Note {
  final String text;
  final String timestamp;
  final String deity;
  final String tag;
  final String? audioPath;

  Note({
    required this.text,
    required this.timestamp,
    required this.deity,
    required this.tag,
    this.audioPath,
  });
}

class LockGateKeeper extends StatefulWidget {
  const LockGateKeeper({super.key});

  @override
  State<LockGateKeeper> createState() => _LockGateKeeperState();
}

class _LockGateKeeperState extends State<LockGateKeeper> {
  String? _savedPin;
  bool _isLoading = true;
  final TextEditingController _pinController = TextEditingController();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPin();
  }

  Future<void> _checkPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('user_pin');
      _isLoading = false;
    });
  }

  void _verifyOrSetPin() async {
    final enteredPin = _pinController.text.trim();
    if (enteredPin.length != 4) {
      setState(() => _errorMessage = 'Please enter a 4-digit PIN');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (_savedPin == null) {
      await prefs.setString('user_pin', enteredPin);
      _unlockApp();
    } else if (_savedPin == enteredPin) {
      _unlockApp();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _pinController.clear();
      });
    }
  }

  void _unlockApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _reportIssue() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'puneetfsn@gmail.com',
      query: 'subject=App Issue Report - Letters to God',
    );
    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isSettingUp = _savedPin == null;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    isSettingUp ? 'Set a 4-Digit Security PIN' : 'Letters to God',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSettingUp
                        ? 'Protect your personal prayers & letters'
                        : 'Enter your 4-digit PIN to open journal',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _pinController,
                      obscureText: true,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 12),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _verifyOrSetPin(),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                    ),
                    onPressed: _verifyOrSetPin,
                    child: Text(isSettingUp ? 'Set PIN & Enter' : 'Unlock'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: IconButton(
              icon: const Icon(Icons.support_agent, color: Colors.grey),
              tooltip: 'Report an Issue',
              onPressed: _reportIssue,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _notes = [];
  DateTime? _filterDate;
  String _selectedTagFilter = 'All';
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<String> _tags = [
    'All',
    '#Prayer',
    '#Gratitude',
    '#Guidance',
    '#Confession',
    '#Peace',
    '#Surrender'
  ];

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedNotes = prefs.getStringList('user_notes');

    setState(() {
      if (savedNotes != null) {
        _notes = savedNotes.map((item) {
          final parts = item.split('|||');
          return Note(
            text: parts[0],
            timestamp: parts[1],
            deity: parts.length > 2 ? parts[2] : 'The GOD/Creator',
            tag: parts.length > 3 ? parts[3] : '#Prayer',
            audioPath: parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
          );
        }).toList();
      }
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> listToSave = _notes
        .map((n) => '${n.text}|||${n.timestamp}|||${n.deity}|||${n.tag}|||${n.audioPath ?? ''}')
        .toList();
    await prefs.setStringList('user_notes', listToSave);
  }

  void _onAddPressed() {
    _showComposeDialog();
  }

  void _showComposeDialog() {
    String selectedTag = _tags[1];
    final controller = TextEditingController();
    final AudioRecorder audioRecorder = AudioRecorder();
    
    bool isRecording = false;
    String? recordedAudioPath;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Write to the Divine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category / Tag:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags.where((t) => t != 'All').map((tag) {
                    final isSelected = selectedTag == tag;
                    return ChoiceChip(
                      label: Text(tag, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black87 : null)),
                      selected: isSelected,
                      selectedColor: Colors.amber,
                      onSelected: (selected) {
                        if (selected) setDialogState(() => selectedTag = tag);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Pour your heart out in silent prayer or confession...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        IconButton(
                          iconSize: 32,
                          icon: Icon(
                            isRecording ? Icons.stop_circle : Icons.mic,
                            color: isRecording ? Colors.redAccent : Colors.amber,
                          ),
                          onPressed: () async {
                            if (isRecording) {
                              final path = await audioRecorder.stop();
                              setDialogState(() {
                                isRecording = false;
                                recordedAudioPath = path;
                              });
                            } else {
                              final messenger = ScaffoldMessenger.of(context);
                              final hasPerm = await audioRecorder.hasPermission();
                              if (hasPerm) {
                                final dir = await getApplicationDocumentsDirectory();
                                final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
                                await audioRecorder.start(const RecordConfig(), path: path);
                                setDialogState(() {
                                  isRecording = true;
                                  recordedAudioPath = null;
                                });
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Microphone permission is required to record audio.')),
                                );
                              }
                            }
                          },
                        ),
                        if (isRecording)
                          const Text('Recording...', style: TextStyle(fontSize: 10, color: Colors.red)),
                        if (recordedAudioPath != null && !isRecording)
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                  ],
                ),
                if (recordedAudioPath != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.play_arrow, color: Colors.amber),
                    label: const Text('Preview Voice Note'),
                    onPressed: () async {
                      AudioPlayer previewPlayer = AudioPlayer();
                      await previewPlayer.play(DeviceFileSource(recordedAudioPath!));
                    },
                  ),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (isRecording) audioRecorder.stop();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send to God'),
              onPressed: () {
                if (isRecording) return;
                
                if (controller.text.trim().isNotEmpty || recordedAudioPath != null) {
                  final now = DateTime.now();
                  final formattedDate = DateFormat('yyyy-MM-dd  |  hh:mm a').format(now);

                  setState(() {
                    _notes.insert(
                      0,
                      Note(
                        text: controller.text.trim().isEmpty ? '[Voice Confession / Prayer]' : controller.text.trim(),
                        timestamp: formattedDate,
                        deity: 'The GOD/Creator',
                        tag: selectedTag,
                        audioPath: recordedAudioPath,
                      ),
                    );
                  });
                  _saveNotes();
                  Navigator.pop(dialogContext);
                  _showOfferedBlessing('The GOD/Creator');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOfferedBlessing(String deity) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volunteer_activism, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Arpanam (Offered in Faith)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 10),
            Text(
              'Your letter has been offered to $deity.\n\nGod listens in sacred silence. No reply is needed, as your prayers are already received. May peace fill your heart.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black87),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Amen / Namaste'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFontDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Choose Journal Font'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Modern Sans', style: TextStyle(fontFamily: 'sans-serif')),
              trailing: fontNotifier.value == 'sans-serif' ? const Icon(Icons.check, color: Colors.amber) : null,
              onTap: () {
                fontNotifier.value = 'sans-serif';
                Navigator.pop(dialogCtx);
              },
            ),
            ListTile(
              title: const Text('Sacred Serif', style: TextStyle(fontFamily: 'serif')),
              trailing: fontNotifier.value == 'serif' ? const Icon(Icons.check, color: Colors.amber) : null,
              onTap: () {
                fontNotifier.value = 'serif';
                Navigator.pop(dialogCtx);
              },
            ),
            ListTile(
              title: const Text('Contemplative Monospace', style: TextStyle(fontFamily: 'monospace')),
              trailing: fontNotifier.value == 'monospace' ? const Icon(Icons.check, color: Colors.amber) : null,
              onTap: () {
                fontNotifier.value = 'monospace';
                Navigator.pop(dialogCtx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeUpiPayment(String amount) async {
    const upiId = 'puneetfsn@ybl';
    const payeeName = 'Schizophrenia Awareness Project';
    const note = 'Donation for Schizophrenia Awareness';

    final upiUri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&tn=${Uri.encodeComponent(note)}&am=$amount&cu=INR',
    );

    try {
      final launched = await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(Uri.parse('https://razorpay.me/@yourcampaign'), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(Uri.parse('https://razorpay.me/@yourcampaign'), mode: LaunchMode.externalApplication);
    }
  }

  void _showDonationDialog() {
    String selectedAmount = '100';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.volunteer_activism, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text('Support the Cause'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We are running a vital awareness and support initiative for schizophrenia. Mental health matters, and together we can provide care, therapy, and break social stigmas.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Donation Amount (INR):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['50', '100', '500'].map((amt) {
                  final isSelected = selectedAmount == amt;
                  return ChoiceChip(
                    label: Text('Rs. $amt'),
                    selected: isSelected,
                    selectedColor: Colors.amber,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => selectedAmount = amt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Direct via GPay / PhonePe / Paytm / BHIM UPI',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _makeUpiPayment(selectedAmount);
              },
              icon: const Icon(Icons.payment, size: 18),
              label: Text('Donate Rs. $selectedAmount via UPI'),
            ),
          ],
        ),
      ),
    );
  }

  void _closeAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close Account?'),
        content: const Text(
          'This will permanently delete all your letters and security PIN. This cannot be undone.',
          style: TextStyle(color: Colors.redAccent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(dialogContext);
              final rootNav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!mounted) return;

              setState(() {
                _notes.clear();
              });
              nav.pop();
              messenger.showSnackBar(const SnackBar(content: Text('Account wiped completely.')));
              rootNav.pushReplacement(MaterialPageRoute(builder: (context) => const LockGateKeeper()));
            },
            child: const Text('Delete All & Close'),
          ),
        ],
      ),
    );
  }

  List<Note> get _filteredNotes {
    return _notes.where((note) {
      final matchesDate = _filterDate == null ||
          note.timestamp.startsWith(DateFormat('yyyy-MM-dd').format(_filterDate!));
      final matchesTag = _selectedTagFilter == 'All' || note.tag == _selectedTagFilter;
      return matchesDate && matchesTag;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('Letters to God', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                pw.SizedBox(height: 4),
                pw.Text('Personal Spiritual Archive', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.blueGrey200, thickness: 1),
                pw.SizedBox(height: 16),
              ],
            ),
          ),
          ..._filteredNotes.map((note) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('Offered to: ${note.deity}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
                        ),
                        pw.Text(note.tag, style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(note.text, style: const pw.TextStyle(fontSize: 12)),
                    if (note.audioPath != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('[Voice Note Attached]', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                    ],
                    pw.SizedBox(height: 6),
                    pw.Text('Created: ${note.timestamp}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              )),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'letters_to_god_backup.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final displayNotes = _filteredNotes;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: fontNotifier,
      builder: (context, currentFont, _) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Letters to God'),
                Text(
                  '${_notes.length} ${_notes.length == 1 ? "Letter" : "Letters"} Written',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () {
                  themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
              ),
              IconButton(
                icon: const Icon(Icons.font_download_outlined),
                onPressed: _showFontDialog,
              ),
              IconButton(
                icon: const Icon(Icons.volunteer_activism, color: Colors.redAccent),
                onPressed: _showDonationDialog,
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _notes.isEmpty ? null : _exportToPDF,
              ),
              IconButton(
                icon: const Icon(Icons.lock_reset),
                onPressed: _closeAccount,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_filterDate != null)
                      Text(
                        'Filter: ${DateFormat('MMM dd, yyyy').format(_filterDate!)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.calendar_month,
                        color: _filterDate == null ? Colors.grey : Colors.amber,
                      ),
                      tooltip: 'Filter by Date',
                      onPressed: _pickDate,
                    ),
                    if (_filterDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.redAccent),
                        tooltip: 'Clear Date Filter',
                        onPressed: () => setState(() => _filterDate = null),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _tags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final tag = _tags[idx];
                    final isSelected = _selectedTagFilter == tag;
                    return ChoiceChip(
                      label: Text(
                        tag,
                        style: TextStyle(fontSize: 12, color: isSelected ? Colors.black87 : null),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.amber,
                      onSelected: (selected) {
                        setState(() => _selectedTagFilter = tag);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: displayNotes.isEmpty
                    ? const Center(
                        child: Text(
                          'No letters found.\nTap + to write your letter to the Divine',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayNotes.length,
                        itemBuilder: (context, index) {
                          final note = displayNotes[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B1B22) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '- ${note.deity}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: currentFont,
                                          color: isDark ? Colors.amber : const Color(0xFFB57000),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(note.tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (note.text.isNotEmpty)
                                  Text(
                                    note.text,
                                    style: TextStyle(fontSize: 15, height: 1.4, fontFamily: currentFont),
                                  ),
                                if (note.audioPath != null) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.play_circle, color: Colors.amber, size: 24),
                                    label: const Text('Play Voice Note'),
                                    onPressed: () async {
                                      await _audioPlayer.play(DeviceFileSource(note.audioPath!));
                                    },
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(note.timestamp, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const Text('Offered', style: TextStyle(fontSize: 11, color: Colors.green)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _onAddPressed,
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black87,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}