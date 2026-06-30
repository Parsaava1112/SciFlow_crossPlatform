import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'database_helper.dart';

class HistoryScreen extends StatefulWidget {
  final String username;
  const HistoryScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _allMessages = [];
  List<Map<String, dynamic>> _filteredMessages = [];
  String _searchQuery = '';
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = _showArchived
        ? await _dbHelper.getArchivedHistory(widget.username)
        : await _dbHelper.getUserHistory(widget.username);
    setState(() {
      _allMessages = data;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredMessages = List.from(_allMessages);
    } else {
      _filteredMessages = _allMessages.where((msg) {
        final q = (msg['question'] ?? '').toLowerCase();
        final a = (msg['answer'] ?? '').toLowerCase();
        final term = _searchQuery.toLowerCase();
        return q.contains(term) || a.contains(term);
      }).toList();
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (var msg in _filteredMessages) {
      final ts = DateTime.tryParse(msg['timestamp'] ?? '') ?? DateTime.now();
      final j = Jalali.fromDateTime(ts);
      final key = '${j.day} ${j.formatter.mN} ${j.year}';
      map.putIfAbsent(key, () => []).add(msg);
    }
    return map;
  }

  Future<void> _togglePin(int id, bool current) async {
    await _dbHelper.pinMessage(id, !current);
    _loadHistory();
  }

  Future<void> _archive(int id) async {
    await _dbHelper.archiveMessage(id, true);
    _loadHistory();
  }

  Future<void> _delete(int id) async {
    await _dbHelper.deleteMessage(id);
    _loadHistory();
  }

  Future<void> _unarchive(int id) async {
    await _dbHelper.archiveMessage(id, false);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تاریخچه گفتگو'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.unarchive : Icons.archive),
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _loadHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'جستجو در تاریخچه...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilter();
                });
              },
            ),
          ),
          Expanded(
            child: _filteredMessages.isEmpty
                ? const Center(child: Text('موردی یافت نشد.'))
                : ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final date = groups.keys.elementAt(index);
                      final messages = groups[date]!;
                      return _buildGroup(date, messages);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(String date, List<Map<String, dynamic>> messages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(date,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...messages.map((msg) => _buildMessageTile(msg)),
      ],
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> msg) {
    final id = msg['id'] as int;
    final question = msg['question'] ?? '';
    final answer = msg['answer'] ?? '';
    final isPinned = (msg['is_pinned'] ?? 0) == 1;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: isPinned
            ? const Icon(FontAwesomeIcons.thumbtack, size: 16)
            : null,
        title: Text(question, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(answer, maxLines: 2, overflow: TextOverflow.ellipsis),
        onLongPress: () => _showOptions(id, isPinned),
      ),
    );
  }

  void _showOptions(int id, bool isPinned) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(isPinned ? 'حذف پین' : 'پین کردن'),
            onTap: () {
              _togglePin(id, isPinned);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('بایگانی'),
            onTap: () {
              _archive(id);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('حذف'),
            onTap: () {
              _delete(id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}