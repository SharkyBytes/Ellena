import 'package:flutter/material.dart';
import '../tasks/task_screen.dart';
import '../tasks/create_task_screen.dart';
import '../tickets/ticket_screen.dart';
import '../tickets/create_ticket_screen.dart';
import '../chat/chat_screen.dart';
import '../../services/supabase/supabase_service.dart';
import '../meetings/create_meeting_screen.dart';
import '../meetings/meeting_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _supabaseService = SupabaseService();

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
      _showCreateMeetingScreen();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateTicketScreen(),
      ),
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showCreateMeetingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateMeetingScreen(),
      ),
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
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
    return DefaultTabController(
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
    );
  }

  Widget _buildUpcomingMeetings() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabaseService.getUpcomingMeetings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading meetings: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        
        final meetings = snapshot.data ?? [];
        
        if (meetings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade700),
                const SizedBox(height: 16),
                Text(
                  'No upcoming meetings',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showCreateMeetingScreen,
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule Meeting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: meetings.length,
          itemBuilder: (context, index) {
            final meeting = meetings[index];
            final meetingDate = DateTime.parse(meeting['meeting_date']);
            final dateFormat = DateFormat('EEEE, MMMM d');
            final timeFormat = DateFormat('h:mm a');
            
            return _buildUpcomingMeetingCard(
              id: meeting['id'],
              title: meeting['title'] ?? 'Untitled Meeting',
              time: '${dateFormat.format(meetingDate)}, ${timeFormat.format(meetingDate)}',
              participants: meeting['participants'] ?? 0,
              meetingUrl: meeting['meeting_url'],
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingMeetingCard({
    required String id,
    required String title,
    required String time,
    required int participants,
    String? meetingUrl,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingDetailScreen(meetingId: id),
          ),
        ).then((value) {
          if (value == true) {
            setState(() {}); // Refresh if meeting was updated or deleted
          }
        });
      },
      child: Container(
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
                  if (participants > 0)
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (meetingUrl != null && meetingUrl.isNotEmpty)
                        ElevatedButton(
                          onPressed: () async {
                            final url = Uri.parse(meetingUrl);
                            try {
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not launch meeting URL'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              debugPrint('Error launching URL: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error launching URL: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
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
      ),
    );
  }

  Widget _buildPastMeetings() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabaseService.getPastMeetings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading meetings: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        
        final meetings = snapshot.data ?? [];
        
        if (meetings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade700),
                const SizedBox(height: 16),
                Text(
                  'No past meetings',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: meetings.length,
          itemBuilder: (context, index) {
            final meeting = meetings[index];
            final meetingDate = DateTime.parse(meeting['meeting_date']);
            final dateFormat = DateFormat('EEEE, MMMM d');
            final timeFormat = DateFormat('h:mm a');
            
            return _buildPastMeetingCard(
              id: meeting['id'],
              title: meeting['title'] ?? 'Untitled Meeting',
              time: '${dateFormat.format(meetingDate)}, ${timeFormat.format(meetingDate)}',
              hasTranscription: meeting['transcription'] != null && meeting['transcription'].toString().trim().isNotEmpty,
              hasAiSummary: meeting['ai_summary'] != null && meeting['ai_summary'].toString().trim().isNotEmpty,
            );
          },
        );
      },
    );
  }

  Widget _buildPastMeetingCard({
    required String id,
    required String title,
    required String time,
    required bool hasTranscription,
    required bool hasAiSummary,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingDetailScreen(meetingId: id),
          ),
        ).then((value) {
          if (value == true) {
            setState(() {}); // Refresh if meeting was updated or deleted
          }
        });
      },
      child: Container(
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasTranscription)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MeetingDetailScreen(meetingId: id),
                              ),
                            );
                          },
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
                      if (hasTranscription && hasAiSummary)
                        const SizedBox(width: 8),
                      if (hasAiSummary)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MeetingDetailScreen(meetingId: id),
                              ),
                            );
                          },
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
