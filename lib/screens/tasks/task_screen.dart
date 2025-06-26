import 'package:flutter/material.dart';
import '../../services/supabase/supabase_service.dart';
import 'task_detail_screen.dart';
import 'create_task_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  String _selectedStatus = 'todo';
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
      
      // Initial load of tasks
      await _supabaseService.getTasks();
      
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
  
  Future<void> _updateTaskStatus(String taskId, String status) async {
    try {
      await _supabaseService.updateTaskStatus(
        taskId: taskId,
        status: status,
      );
    } catch (e) {
      debugPrint('Error updating task status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _updateTaskApproval(String taskId, String approvalStatus) async {
    try {
      await _supabaseService.updateTaskApproval(
        taskId: taskId,
        approvalStatus: approvalStatus,
      );
    } catch (e) {
      debugPrint('Error updating task approval: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task approval: $e'),
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
              builder: (context) => const CreateTaskScreen(),
              fullscreenDialog: true,
            ),
          );
          
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        backgroundColor: Colors.green.shade400,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabaseService.tasksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final tasks = snapshot.data ?? [];
          
          final todoTasks = tasks.where((task) => task['status'] == 'todo').toList();
          final inProgressTasks = tasks.where((task) => task['status'] == 'in_progress').toList();
          final completedTasks = tasks.where((task) => task['status'] == 'completed').toList();
          final totalTasks = tasks.length;
          
          return Column(
            children: [
              _buildProgressHeader(
                completedTasks: completedTasks.length,
                inProgressTasks: inProgressTasks.length,
                todoTasks: todoTasks.length,
                totalTasks: totalTasks,
              ),
              const SizedBox(height: 16),
              _buildStatusTabs(),
              Expanded(
                child: _buildTaskList(
                  tasks.where((task) => task['status'] == _selectedStatus).toList()
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader({
    required int completedTasks,
    required int inProgressTasks,
    required int todoTasks,
    required int totalTasks,
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
                label: 'Completed',
                value: completedTasks,
                total: totalTasks > 0 ? totalTasks : 1,
                color: Colors.green.shade400,
              ),
              _buildProgressStat(
                label: 'In Progress',
                value: inProgressTasks,
                total: totalTasks > 0 ? totalTasks : 1,
                color: Colors.orange.shade400,
              ),
              _buildProgressStat(
                label: 'To Do',
                value: todoTasks,
                total: totalTasks > 0 ? totalTasks : 1,
                color: Colors.blue.shade400,
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
                      width: totalTasks > 0 ? completedTasks / totalTasks : 0,
                      color: Colors.green.shade400,
                    ),
                    _buildProgressBar(
                      width: totalTasks > 0 ? inProgressTasks / totalTasks : 0,
                      color: Colors.orange.shade400,
                    ),
                    _buildProgressBar(
                      width: totalTasks > 0 ? todoTasks / totalTasks : 0,
                      color: Colors.blue.shade400,
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
      {'id': 'todo', 'label': 'To Do', 'color': Colors.blue},
      {'id': 'in_progress', 'label': 'In Progress', 'color': Colors.orange},
      {'id': 'completed', 'label': 'Completed', 'color': Colors.green},
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

  Widget _buildTaskList(List<Map<String, dynamic>> filteredTasks) {
    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedStatus == 'todo' ? Icons.assignment_outlined :
              _selectedStatus == 'in_progress' ? Icons.pending_actions_outlined :
              Icons.task_alt_outlined,
              size: 80,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'todo' ? 'Add new tasks to get started' :
              _selectedStatus == 'in_progress' ? 'Move tasks here when you start working on them' :
              'Completed tasks will appear here',
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
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _TaskCard(
          task: task,
          isAdmin: _isAdmin,
          onStatusChange: _updateTaskStatus,
          onApprovalChange: _updateTaskApproval,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailScreen(taskId: task['id']),
              ),
            );
            
            if (result == true) {
              // Task was updated in detail screen, refresh tasks
              _supabaseService.getTasks();
            }
          },
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isAdmin;
  final Function(String, String) onStatusChange;
  final Function(String, String) onApprovalChange;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.isAdmin,
    required this.onStatusChange,
    required this.onApprovalChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String title = task['title'] ?? 'Untitled Task';
    final String description = task['description'] ?? 'No description';
    final String status = task['status'] ?? 'todo';
    final String approvalStatus = task['approval_status'] ?? 'pending';
    final String creatorName = task['creator']?['full_name'] ?? 'Unknown';
    final String assigneeName = task['assignee']?['full_name'] ?? 'Unassigned';
    
    // Format due date if available
    String dueDate = 'No due date';
    if (task['due_date'] != null) {
      final DateTime date = DateTime.parse(task['due_date']);
      dueDate = '${date.day}/${date.month}/${date.year}';
    }
    
    // Determine colors based on status
    final Color statusColor = status == 'todo' 
        ? Colors.blue 
        : status == 'in_progress' 
            ? Colors.orange 
            : Colors.green;
            
    final Color approvalColor = approvalStatus == 'pending' 
        ? Colors.grey 
        : approvalStatus == 'approved' 
            ? Colors.green 
            : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'todo' ? Icons.assignment_outlined :
                        status == 'in_progress' ? Icons.pending_actions_outlined :
                        Icons.task_alt_outlined,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == 'todo' ? 'To Do' :
                        status == 'in_progress' ? 'In Progress' : 'Completed',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    dueDate,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: approvalColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          approvalStatus.toUpperCase(),
                          style: TextStyle(
                            color: approvalColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue.shade700,
                            child: Text(
                              creatorName.isNotEmpty ? creatorName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Created by $creatorName',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (assigneeName != 'Unassigned')
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.purple.shade700,
                              child: Text(
                                assigneeName.isNotEmpty ? assigneeName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Assigned to $assigneeName',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isAdmin && approvalStatus == 'pending')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => onApprovalChange(task['id'], 'approved'),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Approve', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => onApprovalChange(task['id'], 'rejected'),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('Reject', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            if (status != 'completed')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (status == 'todo')
                      ElevatedButton.icon(
                        onPressed: () => onStatusChange(task['id'], 'in_progress'),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('Start', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    if (status == 'in_progress')
                      ElevatedButton.icon(
                        onPressed: () => onStatusChange(task['id'], 'completed'),
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Complete', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
