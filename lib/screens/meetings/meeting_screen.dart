import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase/supabase_service.dart';
import 'create_meeting_screen.dart';
import 'meeting_detail_screen.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isAdmin = false;
  String _selectedFilter = 'upcoming';
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Check if user is admin
      final userProfile = await _supabaseService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _isAdmin = userProfile?['role'] == 'admin';
        });
      }
      
      // Initial load of meetings
      await _supabaseService.getMeetings();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _deleteMeeting(String meetingId) async {
    try {
      final result = await _supabaseService.deleteMeeting(meetingId);
      
      if (mounted && !result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meeting: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting meeting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMeetingScreen(),
            ),
          );
          
          if (result == true) {
            // Meeting was created, refresh meetings
            _supabaseService.getMeetings();
          }
        },
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabaseService.meetingsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final meetings = snapshot.data ?? [];
          final now = DateTime.now();
          
          // Filter meetings based on selected filter
          final filteredMeetings = meetings.where((meeting) {
            final meetingDate = DateTime.parse(meeting['meeting_date']);
            if (_selectedFilter == 'upcoming') {
              return meetingDate.isAfter(now);
            } else {
              return meetingDate.isBefore(now);
            }
          }).toList();
          
          return Column(
            children: [
              _buildHeader(
                upcomingCount: meetings.where((m) => 
                  DateTime.parse(m['meeting_date']).isAfter(now)).length,
                pastCount: meetings.where((m) => 
                  DateTime.parse(m['meeting_date']).isBefore(now)).length,
              ),
              const SizedBox(height: 16),
              _buildFilterTabs(),
              Expanded(
                child: _buildMeetingList(filteredMeetings),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    required int upcomingCount,
    required int pastCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Team Meetings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMeetingStat(
                label: 'Upcoming',
                value: upcomingCount,
                icon: Icons.calendar_today,
                color: Colors.blue.shade400,
              ),
              _buildMeetingStat(
                label: 'Past',
                value: pastCount,
                icon: Icons.history,
                color: Colors.purple.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingStat({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            icon,
            color: color,
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final filterOptions = [
      {'id': 'upcoming', 'label': 'Upcoming', 'color': Colors.blue},
      {'id': 'past', 'label': 'Past', 'color': Colors.purple},
    ];
    
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filterOptions.map((filter) {
          final isSelected = filter['id'] == _selectedFilter;
          final color = filter['color'] as MaterialColor;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter['id'] as String),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  filter['label'] as String,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMeetingList(List<Map<String, dynamic>> filteredMeetings) {
    if (filteredMeetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == 'upcoming' ? Icons.calendar_today : Icons.history,
              size: 80,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_selectedFilter == 'upcoming' ? 'upcoming' : 'past'} meetings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'upcoming' 
                ? 'Create new meetings to get started' 
                : 'Past meetings will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMeetings.length,
      itemBuilder: (context, index) {
        final meeting = filteredMeetings[index];
        return _MeetingCard(
          meeting: meeting,
          isAdmin: _isAdmin,
          onDelete: _deleteMeeting,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MeetingDetailScreen(meetingId: meeting['id']),
              ),
            );
            
            if (result == true) {
              // Meeting was updated in detail screen, refresh meetings
              _supabaseService.getMeetings();
            }
          },
        );
      },
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final bool isAdmin;
  final Function(String) onDelete;
  final VoidCallback onTap;

  const _MeetingCard({
    required this.meeting,
    required this.isAdmin,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meetingDate = DateTime.parse(meeting['meeting_date']);
    final isUpcoming = meetingDate.isAfter(DateTime.now());
    final dateFormat = DateFormat('E, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF2D2D2D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    meeting['meeting_number'] ?? 'MTG-???',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUpcoming 
                        ? Colors.green.shade400.withOpacity(0.2)
                        : Colors.grey.shade600.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUpcoming ? Icons.event_available : Icons.event_busy,
                          color: isUpcoming ? Colors.green.shade400 : Colors.grey.shade600,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUpcoming ? 'UPCOMING' : 'PAST',
                          style: TextStyle(
                            color: isUpcoming ? Colors.green.shade400 : Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                meeting['title'] ?? 'Untitled Meeting',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (meeting['description'] != null)
                Text(
                  meeting['description'],
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: Colors.blue.shade400,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(meetingDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    color: Colors.orange.shade400,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeFormat.format(meetingDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (meeting['meeting_url'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam,
                            color: Colors.blue,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Meeting Link',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (meeting['creator'] != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.green.shade700,
                          child: Text(
                            meeting['creator']['full_name'] != null && meeting['creator']['full_name'].isNotEmpty
                                ? meeting['creator']['full_name'][0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Created by ${meeting['creator']['full_name'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if ((isAdmin || (meeting['creator'] != null && 
                  meeting['creator']['id'] == SupabaseService().client.auth.currentUser?.id)) && 
                  isUpcoming)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => onDelete(meeting['id']),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Cancel Meeting',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 