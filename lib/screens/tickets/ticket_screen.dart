import 'package:flutter/material.dart';
import '../../services/supabase/supabase_service.dart';
import 'ticket_detail_screen.dart';
import 'create_ticket_screen.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  String _selectedStatus = 'open';
  bool _isAdmin = false;
  
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
      
      // Initial load of tickets
      await _supabaseService.getTickets();
      
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
  
  Future<void> _updateTicketStatus(String ticketId, String status) async {
    try {
      await _supabaseService.updateTicketStatus(
        ticketId: ticketId,
        status: status,
      );
    } catch (e) {
      debugPrint('Error updating ticket status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ticket status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _updateTicketApproval(String ticketId, String approvalStatus) async {
    try {
      await _supabaseService.updateTicketApproval(
        ticketId: ticketId,
        approvalStatus: approvalStatus,
      );
    } catch (e) {
      debugPrint('Error updating ticket approval: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ticket approval: $e'),
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabaseService.ticketsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final tickets = snapshot.data ?? [];
          
          final openTickets = tickets.where((ticket) => ticket['status'] == 'open').toList();
          final inProgressTickets = tickets.where((ticket) => ticket['status'] == 'in_progress').toList();
          final resolvedTickets = tickets.where((ticket) => ticket['status'] == 'resolved').toList();
          final totalTickets = tickets.length;
          
          return Column(
            children: [
              _buildProgressHeader(
                openTickets: openTickets.length,
                inProgressTickets: inProgressTickets.length,
                resolvedTickets: resolvedTickets.length,
                totalTickets: totalTickets,
              ),
              const SizedBox(height: 16),
              _buildStatusTabs(),
              Expanded(
                child: _buildTicketList(
                  tickets.where((ticket) => ticket['status'] == _selectedStatus).toList()
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader({
    required int openTickets,
    required int inProgressTickets,
    required int resolvedTickets,
    required int totalTickets,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressStat(
                label: 'Open',
                value: openTickets,
                total: totalTickets > 0 ? totalTickets : 1,
                color: Colors.blue.shade400,
              ),
              _buildProgressStat(
                label: 'In Progress',
                value: inProgressTickets,
                total: totalTickets > 0 ? totalTickets : 1,
                color: Colors.orange.shade400,
              ),
              _buildProgressStat(
                label: 'Resolved',
                value: resolvedTickets,
                total: totalTickets > 0 ? totalTickets : 1,
                color: Colors.green.shade400,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.grey.shade800),
                Row(
                  children: [
                    _buildProgressBar(
                      width: totalTickets > 0 ? openTickets / totalTickets : 0,
                      color: Colors.blue.shade400,
                    ),
                    _buildProgressBar(
                      width: totalTickets > 0 ? inProgressTickets / totalTickets : 0,
                      color: Colors.orange.shade400,
                    ),
                    _buildProgressBar(
                      width: totalTickets > 0 ? resolvedTickets / totalTickets : 0,
                      color: Colors.green.shade400,
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

  Widget _buildProgressStat({
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final percentage = (value / total * 100).round();
    return Column(
      children: [
        Text(
          '$percentage%',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProgressBar({required double width, required Color color}) {
    return Container(
      height: 8,
      width: MediaQuery.of(context).size.width * width - 32 * width,
      color: color,
    );
  }

  Widget _buildStatusTabs() {
    final statusOptions = [
      {'id': 'open', 'label': 'Open', 'color': Colors.blue},
      {'id': 'in_progress', 'label': 'In Progress', 'color': Colors.orange},
      {'id': 'resolved', 'label': 'Resolved', 'color': Colors.green},
    ];
    
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: statusOptions.map((status) {
          final isSelected = status['id'] == _selectedStatus;
          final color = status['color'] as MaterialColor;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedStatus = status['id'] as String),
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
                  status['label'] as String,
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

  Widget _buildTicketList(List<Map<String, dynamic>> filteredTickets) {
    if (filteredTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedStatus == 'open' ? Icons.report_problem_outlined :
              _selectedStatus == 'in_progress' ? Icons.pending_actions_outlined :
              Icons.task_alt_outlined,
              size: 80,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'open' ? 'Create new tickets to get started' :
              _selectedStatus == 'in_progress' ? 'Move tickets here when you start working on them' :
              'Resolved tickets will appear here',
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
      itemCount: filteredTickets.length,
      itemBuilder: (context, index) {
        final ticket = filteredTickets[index];
        return _TicketCard(
          ticket: ticket,
          isAdmin: _isAdmin,
          onStatusChange: _updateTicketStatus,
          onApprovalChange: _updateTicketApproval,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TicketDetailScreen(ticketId: ticket['id']),
              ),
            );
            
            if (result == true) {
              // Ticket was updated in detail screen, refresh tickets
              _supabaseService.getTickets();
            }
          },
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final bool isAdmin;
  final Function(String, String) onStatusChange;
  final Function(String, String) onApprovalChange;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.isAdmin,
    required this.onStatusChange,
    required this.onApprovalChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priority = ticket['priority'] as String;
    final approvalStatus = ticket['approval_status'] as String;
    
    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red.shade400;
        break;
      case 'medium':
        priorityColor = Colors.orange.shade400;
        break;
      case 'low':
        priorityColor = Colors.green.shade400;
        break;
      default:
        priorityColor = Colors.grey;
    }
    
    Color approvalColor;
    IconData approvalIcon;
    switch (approvalStatus) {
      case 'approved':
        approvalColor = Colors.green.shade400;
        approvalIcon = Icons.check_circle;
        break;
      case 'rejected':
        approvalColor = Colors.red.shade400;
        approvalIcon = Icons.cancel;
        break;
      case 'pending':
      default:
        approvalColor = Colors.grey;
        approvalIcon = Icons.pending;
    }
    
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
                    ticket['ticket_number'] ?? 'TKT-???',
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
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          color: priorityColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: approvalColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          approvalIcon,
                          color: approvalColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          approvalStatus.toUpperCase(),
                          style: TextStyle(
                            color: approvalColor,
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
                ticket['title'] ?? 'Untitled Ticket',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ticket['description'] ?? 'No description',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ticket['category'] ?? 'Other',
                      style: TextStyle(
                        color: Colors.purple.shade300,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (ticket['creator'] != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.green.shade700,
                          child: Text(
                            ticket['creator']['full_name'] != null && ticket['creator']['full_name'].isNotEmpty
                                ? ticket['creator']['full_name'][0].toUpperCase()
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
                          'Created by ${ticket['creator']['full_name'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (isAdmin && approvalStatus == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onApprovalChange(ticket['id'], 'approved'),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text(
                            'Approve',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onApprovalChange(ticket['id'], 'rejected'),
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text(
                            'Reject',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
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
