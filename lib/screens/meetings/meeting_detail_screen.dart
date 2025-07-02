import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase/supabase_service.dart';

class MeetingDetailScreen extends StatefulWidget {
  final String meetingId;
  
  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final _supabaseService = SupabaseService();
  Map<String, dynamic>? _meeting;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isAdmin = false;
  bool _isCreator = false;
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _transcriptionController = TextEditingController();
  final _aiSummaryController = TextEditingController();
  DateTime? _meetingDate;
  TimeOfDay? _meetingTime;
  
  @override
  void initState() {
    super.initState();
    _loadMeetingDetails();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _transcriptionController.dispose();
    _aiSummaryController.dispose();
    super.dispose();
  }
  
  Future<void> _loadMeetingDetails() async {
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
      
      // Get meeting details
      final meetingDetails = await _supabaseService.getMeetingDetails(widget.meetingId);
      
      if (mounted && meetingDetails != null) {
        final userId = _supabaseService.client.auth.currentUser?.id;
        final isCreator = meetingDetails['created_by'] == userId;
        
        // Parse meeting date and time
        final meetingDateTime = DateTime.parse(meetingDetails['meeting_date']);
        
        setState(() {
          _meeting = meetingDetails;
          _isCreator = isCreator;
          _meetingDate = meetingDateTime;
          _meetingTime = TimeOfDay.fromDateTime(meetingDateTime);
          
          // Set initial values for editing
          _titleController.text = meetingDetails['title'] ?? '';
          _descriptionController.text = meetingDetails['description'] ?? '';
          _urlController.text = meetingDetails['meeting_url'] ?? '';
          _transcriptionController.text = meetingDetails['transcription'] ?? '';
          _aiSummaryController.text = meetingDetails['ai_summary'] ?? '';
          
          _isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading meeting details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading meeting details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _deleteMeeting() async {
    try {
      final result = await _supabaseService.deleteMeeting(widget.meetingId);
      
      if (mounted) {
        if (result['success']) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting meeting: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
  
  Future<void> _updateMeeting() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_meetingDate == null || _meetingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Combine date and time
      final meetingDateTime = DateTime(
        _meetingDate!.year,
        _meetingDate!.month,
        _meetingDate!.day,
        _meetingTime!.hour,
        _meetingTime!.minute,
      );
      
      final result = await _supabaseService.updateMeeting(
        meetingId: widget.meetingId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        meetingDate: meetingDateTime,
        meetingUrl: _urlController.text.trim().isNotEmpty ? _urlController.text.trim() : null,
        transcription: _transcriptionController.text.trim().isNotEmpty ? _transcriptionController.text.trim() : null,
        ai_summary: _aiSummaryController.text.trim().isNotEmpty ? _aiSummaryController.text.trim() : null,
      );
      
      if (mounted) {
        if (result['success']) {
          setState(() {
            _isEditing = false;
            _isLoading = false;
          });
          
          // Reload meeting details
          _loadMeetingDetails();
        } else {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating meeting: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating meeting: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _launchMeetingUrl() async {
    if (_meeting == null || _meeting!['meeting_url'] == null) return;
    
    final url = Uri.parse(_meeting!['meeting_url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
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
  }
  
  Future<void> _copyMeetingUrl() async {
    if (_meeting == null || _meeting!['meeting_url'] == null) return;
    
    await Clipboard.setData(ClipboardData(text: _meeting!['meeting_url']));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting URL copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Color(0xFF2D2D2D),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _meetingDate = picked;
      });
    }
  }
  
  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _meetingTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Color(0xFF2D2D2D),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _meetingTime = picked;
      });
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
    
    if (_meeting == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: Text('Meeting not found')),
      );
    }
    
    final meetingDateTime = DateTime.parse(_meeting!['meeting_date']);
    final isUpcoming = meetingDateTime.isAfter(DateTime.now());
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final canEdit = (_isAdmin || _isCreator) && isUpcoming;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Text(_isEditing ? 'Edit Meeting' : 'Meeting Details'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _updateMeeting,
              icon: const Icon(Icons.check),
              tooltip: 'Save Changes',
            )
          else if (canEdit)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Meeting',
            ),
          if (canEdit && !_isEditing)
            IconButton(
              onPressed: () => _showDeleteConfirmation(context),
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Meeting',
            ),
        ],
      ),
      body: _isEditing ? _buildEditForm() : _buildMeetingDetails(dateFormat, timeFormat, isUpcoming),
    );
  }
  
  Widget _buildMeetingDetails(DateFormat dateFormat, DateFormat timeFormat, bool isUpcoming) {
    final meetingDateTime = DateTime.parse(_meeting!['meeting_date']);
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Meeting number and status
        Row(
          children: [
            Text(
              _meeting!['meeting_number'] ?? 'MTG-???',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUpcoming 
                  ? Colors.green.shade400.withOpacity(0.2)
                  : Colors.grey.shade600.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUpcoming ? Icons.event_available : Icons.event_busy,
                    color: isUpcoming ? Colors.green.shade400 : Colors.grey.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUpcoming ? 'UPCOMING' : 'PAST',
                    style: TextStyle(
                      color: isUpcoming ? Colors.green.shade400 : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Title
        Text(
          _meeting!['title'] ?? 'Untitled Meeting',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Date and time
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: Colors.blue.shade400,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(meetingDateTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.orange.shade400,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeFormat.format(meetingDateTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Meeting URL
        if (_meeting!['meeting_url'] != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.videocam,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Meeting Link',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _copyMeetingUrl,
                      icon: const Icon(Icons.copy, color: Colors.white),
                      tooltip: 'Copy URL',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _meeting!['meeting_url'],
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isUpcoming)
                  const SizedBox(height: 16),
                if (isUpcoming)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _launchMeetingUrl,
                      icon: const Icon(Icons.open_in_new, color: Colors.white),
                      label: const Text(
                        'Join Meeting',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (_meeting!['meeting_url'] != null)
          const SizedBox(height: 24),
        
        // Description
        if (_meeting!['description'] != null && _meeting!['description'].trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _meeting!['description'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        if (_meeting!['description'] != null && _meeting!['description'].trim().isNotEmpty)
          const SizedBox(height: 24),
        
        // Transcription (only for past meetings)
        if (!isUpcoming && _meeting!['transcription'] != null && _meeting!['transcription'].toString().trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.purple.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.record_voice_over,
                      color: Colors.purple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Meeting Transcription',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _meeting!['transcription'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        if (!isUpcoming && _meeting!['transcription'] != null && _meeting!['transcription'].toString().trim().isNotEmpty)
          const SizedBox(height: 24),
        
        // AI Summary (only for past meetings)
        if (!isUpcoming && _meeting!['ai_summary'] != null && _meeting!['ai_summary'].toString().trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.teal.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.teal,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Summary',
                      style: TextStyle(
                        color: Colors.teal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _meeting!['ai_summary'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        if (!isUpcoming && _meeting!['ai_summary'] != null && _meeting!['ai_summary'].toString().trim().isNotEmpty)
          const SizedBox(height: 24),
          
        // Creator info
        if (_meeting!['creator'] != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green.shade700,
                  child: Text(
                    _meeting!['creator']['full_name'] != null && _meeting!['creator']['full_name'].isNotEmpty
                        ? _meeting!['creator']['full_name'][0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created by',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _meeting!['creator']['full_name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_meeting!['creator']['role'] == 'admin')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade400.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.orange.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildEditForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            labelStyle: TextStyle(color: Colors.grey.shade400),
            hintText: 'Enter meeting title',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF2D2D2D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.title, color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        
        // Description
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description',
            labelStyle: TextStyle(color: Colors.grey.shade400),
            hintText: 'Enter meeting description',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF2D2D2D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.description, color: Colors.grey),
            alignLabelWithHint: true,
          ),
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        
        // Date
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: Colors.blue.shade400,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _meetingDate != null
                            ? DateFormat('EEEE, MMMM d, yyyy').format(_meetingDate!)
                            : 'Select date',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Time
        InkWell(
          onTap: _selectTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.orange.shade400,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _meetingTime != null
                            ? _meetingTime!.format(context)
                            : 'Select time',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Meeting URL
        TextFormField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: 'Meeting URL (Optional)',
            labelStyle: TextStyle(color: Colors.grey.shade400),
            hintText: 'Enter Google Meet or other meeting URL',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF2D2D2D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.videocam, color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 24),
        
        // Transcription
        TextFormField(
          controller: _transcriptionController,
          decoration: InputDecoration(
            labelText: 'Transcription (Optional)',
            labelStyle: TextStyle(color: Colors.grey.shade400),
            hintText: 'Enter meeting transcription',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF2D2D2D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.record_voice_over, color: Colors.grey),
            alignLabelWithHint: true,
          ),
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        
        // AI Summary
        TextFormField(
          controller: _aiSummaryController,
          decoration: InputDecoration(
            labelText: 'AI Summary (Optional)',
            labelStyle: TextStyle(color: Colors.grey.shade400),
            hintText: 'Enter meeting AI summary',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF2D2D2D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.auto_awesome, color: Colors.grey),
            alignLabelWithHint: true,
          ),
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
        ),
        const SizedBox(height: 32),
        
        // Save button
        ElevatedButton(
          onPressed: _updateMeeting,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Save Changes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Cancel button
        TextButton(
          onPressed: () => setState(() => _isEditing = false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
  
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          'Delete Meeting',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this meeting? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMeeting();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
} 