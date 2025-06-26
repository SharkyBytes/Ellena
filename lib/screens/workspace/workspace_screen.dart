import 'package:flutter/material.dart';
import '../tasks/task_screen.dart';
import '../tasks/create_task_screen.dart';
import '../tickets/ticket_screen.dart';
import '../chat/chat_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  void _showCreateDialog() {
    final currentTab = _tabController.index;
    if (currentTab == 0) {
      _showCreateTaskDialog();
    } else if (currentTab == 1) {
      _showCreateTicketDialog();
    } else if (currentTab == 2) {
      _showCreateMeetingDialog();
    }
  }

  void _showCreateTaskDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateTaskScreen(),
      ),
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showCreateTicketDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Create Ticket',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ticket Title',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Description',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF2D2D2D),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  items:
                      ['Low', 'Medium', 'High'].map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        );
                      }).toList(),
                  onChanged: (value) {},
                  hint: Text(
                    'Priority',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to chat screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChatScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy, color: Colors.green),
                  label: const Text(
                    'Make with AI',
                    style: TextStyle(color: Colors.green),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.1),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Handle ticket creation
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ticket created successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  'Create',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
    );
  }

  void _showCreateMeetingDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Schedule Meeting',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Meeting Title',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.green,
                              surface: Color(0xFF2D2D2D),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    // Handle date selection
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text(
                          'Select Date',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.green,
                              surface: Color(0xFF2D2D2D),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    // Handle time selection
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text(
                          'Select Time',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to chat screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChatScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy, color: Colors.green),
                  label: const Text(
                    'Plan with AI',
                    style: TextStyle(color: Colors.green),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.1),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Handle meeting creation
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Meeting scheduled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  'Schedule',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF2D2D2D),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.green,
              labelColor: Colors.green,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.task), text: 'Tasks'),
                Tab(icon: Icon(Icons.confirmation_number), text: 'Tickets'),
                Tab(icon: Icon(Icons.group), text: 'Meetings'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const TaskScreen(),
                const TicketScreen(),
                _buildMeetingsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMeetingsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF2D2D2D),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Meeting Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMeetingStat(
                    label: 'This Week',
                    count: '3',
                    icon: Icons.calendar_today,
                    color: Colors.green,
                  ),
                  _buildMeetingStat(
                    label: 'Hours',
                    count: '4.5',
                    icon: Icons.access_time,
                    color: Colors.orange,
                  ),
                  _buildMeetingStat(
                    label: 'Completed',
                    count: '12',
                    icon: Icons.check_circle,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')],
                  labelColor: Colors.green,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.green,
                ),
                Expanded(
                  child: TabBarView(
                    children: [_buildUpcomingMeetings(), _buildPastMeetings()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingStat({
    required String label,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildUpcomingMeetings() {
    // Sample upcoming meetings
    final upcomingMeetings = [
      {'title': 'Team Sync', 'time': 'Tomorrow, 10:00 AM', 'participants': 5},
      {'title': 'Project Review', 'time': 'Friday, 2:30 PM', 'participants': 8},
      {
        'title': 'Client Meeting',
        'time': 'Next Monday, 11:00 AM',
        'participants': 3,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcomingMeetings.length,
      itemBuilder: (context, index) {
        final meeting = upcomingMeetings[index];
        return _buildUpcomingMeetingCard(
          title: meeting['title'] as String,
          time: meeting['time'] as String,
          participants: meeting['participants'] as int,
        );
      },
    );
  }

  Widget _buildUpcomingMeetingCard({
    required String title,
    required String time,
    required int participants,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$participants',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'AI Listening: ',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Switch(
                            value: false, // Default value
                            onChanged: (value) {
                              if (value) {
                                _showMeetingTypeDialog();
                              }
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastMeetings() {
    // Sample past meetings
    final pastMeetings = [
      {
        'title': 'Weekly Standup',
        'time': 'Yesterday, 9:30 AM',
        'duration': '45 min',
      },
      {
        'title': 'Design Review',
        'time': 'Monday, 3:00 PM',
        'duration': '1h 15min',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pastMeetings.length,
      itemBuilder: (context, index) {
        final meeting = pastMeetings[index];
        return _buildPastMeetingCard(
          title: meeting['title'] as String,
          time: meeting['time'] as String,
          duration: meeting['duration'] as String,
        );
      },
    );
  }

  Widget _buildPastMeetingCard({
    required String title,
    required String time,
    required String duration,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.timer, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(
                      duration,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.description, size: 16),
                      label: const Text('Transcription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.2),
                        foregroundColor: Colors.green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.summarize, size: 16),
                      label: const Text('AI Summary'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        foregroundColor: Colors.blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMeetingTypeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Meeting Type',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Is this an online or offline meeting?',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showOnlineMeetingDialog();
                      },
                      icon: const Icon(Icons.video_call),
                      label: const Text('Online'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showOfflineMeetingDialog();
                      },
                      icon: const Icon(Icons.meeting_room),
                      label: const Text('Offline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _showOnlineMeetingDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Enter Meeting URL',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'https://meeting-url.com/...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                    prefixIcon: const Icon(Icons.link, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Joining online meeting...'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Join Meeting'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _showOfflineMeetingDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text(
              'Start Offline Meeting',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ell-ena will listen to your meeting and create a transcript and summary.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Meeting recording started'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.mic),
                        label: const Text('Start Meeting'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}
