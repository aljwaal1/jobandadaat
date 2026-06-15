import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitsTasksApp());
}

class HabitsTasksApp extends StatelessWidget {
  const HabitsTasksApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B6F52);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مهامي وعاداتي',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F1),
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFFEFEFA),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFFF7F7F1),
          foregroundColor: Color(0xFF263126),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFEFEFA),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE7E8DE)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDFE3D8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDFE3D8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: seed, width: 1.4),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: seed.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HabitsTasksHome(),
      ),
    );
  }
}

enum ItemKind { task, habit }

extension ItemKindText on ItemKind {
  String get label => this == ItemKind.task ? 'مهمة' : 'عادة';

  String get addLabel => this == ItemKind.task ? 'إضافة مهمة' : 'إضافة عادة';

  Color get color => this == ItemKind.task ? const Color(0xFF5B6F52) : const Color(0xFF315F72);
}

class PlannerItem {
  const PlannerItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.dueDate,
    required this.remindBeforeDue,
    required this.remindOnDue,
    required this.remindAfterDue,
    required this.note,
    required this.doneDates,
  });

  final String id;
  final ItemKind kind;
  final String title;
  final String category;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool remindBeforeDue;
  final bool remindOnDue;
  final bool remindAfterDue;
  final String note;
  final Set<String> doneDates;

  bool doneOn(DateTime date) {
    if (kind == ItemKind.task) return doneDates.contains('done');
    return doneDates.contains(dayKey(date));
  }

  PlannerItem toggle(DateTime date) {
    final key = kind == ItemKind.task ? 'done' : dayKey(date);
    final next = {...doneDates};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    return PlannerItem(
      id: id,
      kind: kind,
      title: title,
      category: category,
      createdAt: createdAt,
      dueDate: dueDate,
      remindBeforeDue: remindBeforeDue,
      remindOnDue: remindOnDue,
      remindAfterDue: remindAfterDue,
      note: note,
      doneDates: next,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'title': title,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'remindBeforeDue': remindBeforeDue,
      'remindOnDue': remindOnDue,
      'remindAfterDue': remindAfterDue,
      'note': note,
      'doneDates': doneDates.toList(),
    };
  }

  factory PlannerItem.fromJson(Map<String, dynamic> map) {
    final kind = ItemKind.values.firstWhere(
      (item) => item.name == map['kind'],
      orElse: () => ItemKind.task,
    );
    final doneDates = ((map['doneDates'] as List<dynamic>?) ?? []).map((item) => item.toString()).toSet();
    if (kind == ItemKind.task && doneDates.isNotEmpty) {
      doneDates.add('done');
    }
    return PlannerItem(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? 'عام',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(map['dueDate'] as String? ?? ''),
      remindBeforeDue: map['remindBeforeDue'] as bool? ?? true,
      remindOnDue: map['remindOnDue'] as bool? ?? true,
      remindAfterDue: map['remindAfterDue'] as bool? ?? true,
      note: map['note'] as String? ?? '',
      doneDates: doneDates,
    );
  }
}

class HabitsTasksHome extends StatefulWidget {
  const HabitsTasksHome({super.key});

  @override
  State<HabitsTasksHome> createState() => _HabitsTasksHomeState();
}

class _HabitsTasksHomeState extends State<HabitsTasksHome> {
  static const _storageKey = 'habits_tasks_items_v1';

  final List<PlannerItem> _items = [];
  int _tab = 0;
  bool _loading = true;
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && saved.isNotEmpty) {
      final decoded = jsonDecode(saved) as List<dynamic>;
      _items
        ..clear()
        ..addAll(decoded.map((item) => PlannerItem.fromJson(item as Map<String, dynamic>)));
    }
    if (mounted) {
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDueReminderIfNeeded());
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_items.map((item) => item.toJson()).toList()));
  }

  List<PlannerItem> get _allTasks {
    final list = _items.where((item) => item.kind == ItemKind.task).toList();
    list.sort((a, b) {
      final done = a.doneOn(_selectedDay).toString().compareTo(b.doneOn(_selectedDay).toString());
      if (done != 0) return done;
      final status = taskVisualRank(a, _selectedDay).compareTo(taskVisualRank(b, _selectedDay));
      if (status != 0) return status;
      final dueA = a.dueDate ?? DateTime(2099);
      final dueB = b.dueDate ?? DateTime(2099);
      final due = dueA.compareTo(dueB);
      if (due != 0) return due;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<PlannerItem> get _todayTasks {
    return _allTasks.where((item) => taskVisibleToday(item, _selectedDay)).toList();
  }

  List<PlannerItem> get _habits {
    final list = _items.where((item) => item.kind == ItemKind.habit).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get _todayTotal => _todayTasks.length + _habits.length;

  int get _todayDone {
    return [..._todayTasks, ..._habits].where((item) => item.doneOn(_selectedDay)).length;
  }

  double get _progress => _todayTotal == 0 ? 0 : _todayDone / _todayTotal;

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _tab,
            children: [
              _TodayView(
                selectedDay: _selectedDay,
                tasks: _todayTasks,
                habits: _habits,
                progress: _progress,
                done: _todayDone,
                total: _todayTotal,
                onPickDay: _pickDay,
                onAdd: _openItemSheet,
                onToggle: _toggleItem,
                onDelete: _deleteItem,
              ),
              _TasksView(
                selectedDay: _selectedDay,
                items: _allTasks,
                onAdd: () => _openItemSheet(initialKind: ItemKind.task),
                onToggle: _toggleItem,
                onDelete: _deleteItem,
              ),
              _HabitsView(
                selectedDay: _selectedDay,
                items: _habits,
                onAdd: () => _openItemSheet(initialKind: ItemKind.habit),
                onToggle: _toggleItem,
                onDelete: _deleteItem,
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مهامي وعاداتي',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: [
          IconButton(
            tooltip: 'إضافة',
            onPressed: () => _openItemSheet(),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'اليوم',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl_rounded),
            label: 'المهام',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_graph_outlined),
            selectedIcon: Icon(Icons.auto_graph_rounded),
            label: 'العادات',
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  Future<void> _openItemSheet({ItemKind initialKind = ItemKind.task}) async {
    final item = await showModalBottomSheet<PlannerItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemSheet(initialKind: initialKind),
    );
    if (item == null) return;
    setState(() => _items.add(item));
    await _saveItems();
  }

  Future<void> _toggleItem(PlannerItem item) async {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) return;
    setState(() => _items[index] = _items[index].toggle(_selectedDay));
    await _saveItems();
  }

  Future<void> _showDueReminderIfNeeded() async {
    if (!mounted) return;
    final today = DateTime.now();
    final activeAlerts = _items.where((item) {
      return item.kind == ItemKind.task && !item.doneOn(today) && taskAlertRank(item, today) <= 2;
    }).toList();
    if (activeAlerts.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final alertKey = 'habits_tasks_due_alert_${dayKey(today)}';
    final alreadyPlayed = prefs.getBool(alertKey) ?? false;
    if (!alreadyPlayed) {
      await SystemSound.play(SystemSoundType.alert);
      await prefs.setBool(alertKey, true);
    }

    final overdue = activeAlerts.where((item) => taskAlertRank(item, today) == 0).length;
    final dueToday = activeAlerts.where((item) => taskAlertRank(item, today) == 1).length;
    final dueTomorrow = activeAlerts.where((item) => taskAlertRank(item, today) == 2).length;
    final parts = [
      if (overdue > 0) '$overdue متأخرة',
      if (dueToday > 0) '$dueToday اليوم',
      if (dueTomorrow > 0) '$dueTomorrow غدًا',
    ].join(' · ');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تنبيه مهام العمل: $parts')),
    );
  }

  Future<void> _deleteItem(PlannerItem item) async {
    setState(() => _items.removeWhere((entry) => entry.id == item.id));
    await _saveItems();
  }
}

class _TodayView extends StatelessWidget {
  const _TodayView({
    required this.selectedDay,
    required this.tasks,
    required this.habits,
    required this.progress,
    required this.done,
    required this.total,
    required this.onPickDay,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
  });

  final DateTime selectedDay;
  final List<PlannerItem> tasks;
  final List<PlannerItem> habits;
  final double progress;
  final int done;
  final int total;
  final VoidCallback onPickDay;
  final void Function({ItemKind initialKind}) onAdd;
  final ValueChanged<PlannerItem> onToggle;
  final ValueChanged<PlannerItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
      children: [
        Text(
          formatFriendlyDay(selectedDay),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF263126)),
        ),
        const SizedBox(height: 6),
        const Text(
          'رتب يومك بهدوء: مهام قليلة، عادات ثابتة، وإنجاز واضح.',
          style: TextStyle(color: Color(0xFF697367), height: 1.45),
        ),
        const SizedBox(height: 14),
        _ProgressPanel(percent: percent, done: done, total: total),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickDay,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('اختيار اليوم'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onAdd(initialKind: ItemKind.task),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('مهمة'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => onAdd(initialKind: ItemKind.habit),
                icon: const Icon(Icons.repeat_rounded),
                label: const Text('عادة'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('مهام اليوم'),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          const _EmptyState(title: 'لا توجد مهام', subtitle: 'أضف مهمة صغيرة قابلة للإنجاز اليوم.')
        else
          ...tasks.take(5).map(
                (item) => _PlannerTile(
                  item: item,
                  selectedDay: selectedDay,
                  onToggle: () => onToggle(item),
                  onDelete: () => onDelete(item),
                ),
              ),
        const SizedBox(height: 16),
        const _SectionTitle('عادات اليوم'),
        const SizedBox(height: 8),
        if (habits.isEmpty)
          const _EmptyState(title: 'لا توجد عادات', subtitle: 'أضف عادة يومية مثل القراءة أو المشي.')
        else
          ...habits.take(5).map(
                (item) => _PlannerTile(
                  item: item,
                  selectedDay: selectedDay,
                  onToggle: () => onToggle(item),
                  onDelete: () => onDelete(item),
                ),
              ),
      ],
    );
  }
}

class _TasksView extends StatelessWidget {
  const _TasksView({
    required this.selectedDay,
    required this.items,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
  });

  final DateTime selectedDay;
  final List<PlannerItem> items;
  final VoidCallback onAdd;
  final ValueChanged<PlannerItem> onToggle;
  final ValueChanged<PlannerItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'المهام',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF263126)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('مهمة'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptyState(title: 'لا توجد مهام بعد', subtitle: 'اكتب مهمة قصيرة وواضحة.')
        else
          ...items.map(
            (item) => _PlannerTile(
              item: item,
              selectedDay: selectedDay,
              onToggle: () => onToggle(item),
              onDelete: () => onDelete(item),
            ),
          ),
      ],
    );
  }
}

class _HabitsView extends StatelessWidget {
  const _HabitsView({
    required this.selectedDay,
    required this.items,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
  });

  final DateTime selectedDay;
  final List<PlannerItem> items;
  final VoidCallback onAdd;
  final ValueChanged<PlannerItem> onToggle;
  final ValueChanged<PlannerItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'العادات',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF263126)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('عادة'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'كل علامة تمثل إنجازًا في يوم من آخر 7 أيام.',
          style: TextStyle(color: Color(0xFF697367), height: 1.45),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptyState(title: 'لا توجد عادات بعد', subtitle: 'ابدأ بعادة واحدة سهلة، ثم زد تدريجيًا.')
        else
          ...items.map(
            (item) => _HabitTile(
              item: item,
              selectedDay: selectedDay,
              onToggle: () => onToggle(item),
              onDelete: () => onDelete(item),
            ),
          ),
      ],
    );
  }
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.initialKind});

  final ItemKind initialKind;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  late ItemKind _kind;
  String _category = 'عام';
  DateTime? _dueDate;
  bool _remindBeforeDue = true;
  bool _remindOnDue = true;
  bool _remindAfterDue = true;

  final List<String> _taskCategories = const ['عمل', 'دراسة', 'بيت', 'مشوار', 'شخصي', 'عام'];
  final List<String> _habitCategories = const ['صحة', 'تعلم', 'عبادة', 'رياضة', 'قراءة', 'عام'];

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _category = _categories.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _categories => _kind == ItemKind.task ? _taskCategories : _habitCategories;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFEFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E8DE)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _kind.addLabel,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ItemKind>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: ItemKind.values
                      .map((kind) => DropdownMenuItem(value: kind, child: Text(kind.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _kind = value;
                      _category = _categories.first;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _kind == ItemKind.task ? 'عنوان المهمة' : 'اسم العادة',
                    hintText: _kind == ItemKind.task ? 'مثال: إنهاء تقرير' : 'مثال: قراءة 10 دقائق',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'اكتب عنوانًا واضحًا';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                if (_kind == ItemKind.task) ...[
                  OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      _dueDate == null ? 'تحديد تاريخ المهمة' : 'تاريخ المهمة: ${formatDate(_dueDate!)}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _remindBeforeDue,
                    onChanged: (value) => setState(() => _remindBeforeDue = value ?? true),
                    title: const Text('تذكير قبل يوم'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: _remindOnDue,
                    onChanged: (value) => setState(() => _remindOnDue = value ?? true),
                    title: const Text('تذكير في نفس تاريخ المهمة'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: _remindAfterDue,
                    onChanged: (value) => setState(() => _remindAfterDue = value ?? true),
                    title: const Text('تذكير بعد تاريخ المهمة إذا لم تنجز'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<String>(
                  key: ValueKey(_kind),
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: _categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظة اختيارية'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('حفظ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final item = PlannerItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: _kind,
      title: _titleController.text.trim(),
      category: _category,
      createdAt: DateTime.now(),
      dueDate: _kind == ItemKind.task ? _dueDate : null,
      remindBeforeDue: _kind == ItemKind.task ? _remindBeforeDue : false,
      remindOnDue: _kind == ItemKind.task ? _remindOnDue : false,
      remindAfterDue: _kind == ItemKind.task ? _remindAfterDue : false,
      note: _noteController.text.trim(),
      doneDates: {},
    );
    Navigator.pop(context, item);
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.percent,
    required this.done,
    required this.total,
  });

  final int percent;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF263126),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إنجاز اليوم',
            style: TextStyle(color: Color(0xFFD5DED0), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '$percent%',
            style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1.05),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : percent / 100,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFAEC7A4)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total == 0 ? 'ابدأ بإضافة مهمة أو عادة.' : 'أنجزت $done من $total.',
            style: const TextStyle(color: Color(0xFFD5DED0)),
          ),
        ],
      ),
    );
  }
}

class _PlannerTile extends StatelessWidget {
  const _PlannerTile({
    required this.item,
    required this.selectedDay,
    required this.onToggle,
    required this.onDelete,
  });

  final PlannerItem item;
  final DateTime selectedDay;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final done = item.doneOn(selectedDay);
    final status = taskStatusLabel(item, selectedDay);
    final statusColor = taskStatusColor(item, selectedDay);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Checkbox(value: done, onChanged: (_) => onToggle()),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: done ? const Color(0xFF7A8476) : const Color(0xFF263126),
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.dueDate == null
                        ? '${item.kind.label} · ${item.category}'
                        : '${item.kind.label} · ${item.category} · تاريخ المهمة ${formatDate(item.dueDate!)}',
                    style: const TextStyle(color: Color(0xFF697367), fontSize: 12),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 6),
                    _StatusPill(label: status, color: statusColor),
                  ],
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF7A8476), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({
    required this.item,
    required this.selectedDay,
    required this.onToggle,
    required this.onDelete,
  });

  final PlannerItem item;
  final DateTime selectedDay;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) => DateTime.now().subtract(Duration(days: 6 - index)));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(value: item.doneOn(selectedDay), onChanged: (_) => onToggle()),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF263126)),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: Text(
                item.category,
                style: const TextStyle(color: Color(0xFF697367), fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: days.map((day) {
                final done = item.doneOn(day);
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: done ? item.kind.color : const Color(0xFFE9ECE3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          done ? Icons.check_rounded : Icons.remove_rounded,
                          size: 17,
                          color: done ? Colors.white : const Color(0xFF879080),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shortDay(day),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF697367)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF263126)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.task_alt_rounded, size: 34, color: Color(0xFF8D9788)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF697367), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

int taskVisualRank(PlannerItem item, DateTime date) {
  if (item.kind != ItemKind.task || item.dueDate == null || item.doneOn(date)) return 4;
  final diff = _dayDifference(item.dueDate!, date);
  if (diff < 0) return 0;
  if (diff == 0) return 1;
  if (diff == 1) return 2;
  return 3;
}

int taskAlertRank(PlannerItem item, DateTime date) {
  if (item.kind != ItemKind.task || item.dueDate == null || item.doneOn(date)) return 9;
  final diff = _dayDifference(item.dueDate!, date);
  if (diff < 0 && item.remindAfterDue) return 0;
  if (diff == 0 && item.remindOnDue) return 1;
  if (diff == 1 && item.remindBeforeDue) return 2;
  return 9;
}

bool taskVisibleToday(PlannerItem item, DateTime date) {
  if (item.kind != ItemKind.task) return false;
  if (item.dueDate == null) return true;
  if (item.doneOn(date)) return true;
  final diff = _dayDifference(item.dueDate!, date);
  if (diff <= 0) return true;
  return diff == 1 && item.remindBeforeDue;
}

String? taskStatusLabel(PlannerItem item, DateTime date) {
  if (item.kind != ItemKind.task || item.dueDate == null) return null;
  if (item.doneOn(date)) return 'منجزة';
  final diff = _dayDifference(item.dueDate!, date);
  if (diff < 0) return 'متأخرة';
  if (diff == 0) return 'تاريخها اليوم';
  if (diff == 1) return 'تاريخها غدًا';
  return 'قادمة';
}

Color taskStatusColor(PlannerItem item, DateTime date) {
  if (item.doneOn(date)) return const Color(0xFF6F7A68);
  final diff = item.dueDate == null ? 99 : _dayDifference(item.dueDate!, date);
  if (diff < 0) return const Color(0xFFB9574F);
  if (diff == 0) return const Color(0xFF9B6A24);
  if (diff == 1) return const Color(0xFF315F72);
  return const Color(0xFF5B6F52);
}

int _dayDifference(DateTime target, DateTime base) {
  final targetDay = DateTime(target.year, target.month, target.day);
  final baseDay = DateTime(base.year, base.month, base.day);
  return targetDay.difference(baseDay).inDays;
}

String dayKey(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String formatFriendlyDay(DateTime date) {
  final today = DateTime.now();
  if (dayKey(date) == dayKey(today)) return 'اليوم';
  final yesterday = today.subtract(const Duration(days: 1));
  if (dayKey(date) == dayKey(yesterday)) return 'أمس';
  return formatDate(date);
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String shortDay(DateTime date) {
  const days = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
  return days[date.weekday % 7];
}
