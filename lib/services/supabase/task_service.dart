import 'package:flutter/material.dart';
import 'base_service.dart';
import 'dart:async';

class TaskService {
  final BaseSupabaseService _baseService = BaseSupabaseService();
  
  // Stream controller for task updates
  final StreamController<List<Map<String, dynamic>>> _tasksStreamController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  
  // Expose stream for UI components to listen to
  Stream<List<Map<String, dynamic>>> get tasksStream => _tasksStreamController.stream;
  
  // Get tasks for the current user's team
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      if (!_baseService.isInitialized) return [];
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) return [];
      
      // Get the user's team ID
      final userProfile = await _baseService.getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) return [];
      
      final teamId = userProfile['team_id'];
      
      // Get all tasks for this team
      final response = await _baseService.client
          .from('tasks')
          .select('*')
          .eq('team_id', teamId)
          .order('created_at', ascending: false);
      
      final tasks = List<Map<String, dynamic>>.from(response);
      
      // Fetch creator and assignee information for each task
      final tasksWithDetails = await _addUserDetailsToTasks(tasks);
      
      // Update the stream
      _tasksStreamController.add(tasksWithDetails);
      
      return tasksWithDetails;
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }
  
  // Create a new task
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedToUserId,
  }) async {
    try {
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Get the user's team ID
      final userProfile = await _baseService.getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) {
        return {
          'success': false,
          'error': 'User not associated with a team',
        };
      }
      
      final teamId = userProfile['team_id'];
      
      // Create the task
      final Map<String, dynamic> taskData = {
        'title': title,
        'description': description,
        'status': 'todo',
        'approval_status': 'pending',
        'team_id': teamId,
        'created_by': user.id,
      };
      
      if (assignedToUserId != null && assignedToUserId.isNotEmpty) {
        taskData['assigned_to'] = assignedToUserId;
      }
      
      if (dueDate != null) {
        taskData['due_date'] = dueDate.toIso8601String();
      }
      
      final response = await _baseService.client
          .from('tasks')
          .insert(taskData)
          .select();
          
      if (response.isEmpty) {
        return {
          'success': false,
          'error': 'Failed to create task',
        };
      }
      
      // Refresh tasks list
      getTasks();
      
      return {
        'success': true,
        'task': response[0],
      };
    } catch (e) {
      debugPrint('Error creating task: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update a task's status
  Future<Map<String, dynamic>> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    try {
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Update the task status
      await _baseService.client
          .from('tasks')
          .update({'status': status})
          .eq('id', taskId);
      
      // Refresh tasks list
      getTasks();
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating task status: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update a task's approval status (admin only)
  Future<Map<String, dynamic>> updateTaskApproval({
    required String taskId,
    required String approvalStatus,
  }) async {
    try {
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Check if user is admin
      final userProfile = await _baseService.getCurrentUserProfile();
      if (userProfile == null || userProfile['role'] != 'admin') {
        return {
          'success': false,
          'error': 'Only admins can approve tasks',
        };
      }
      
      // Update the task approval status
      await _baseService.client
          .from('tasks')
          .update({'approval_status': approvalStatus})
          .eq('id', taskId);
      
      // Refresh tasks list
      getTasks();
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating task approval: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Get task details with comments
  Future<Map<String, dynamic>?> getTaskDetails(String taskId) async {
    try {
      if (!_baseService.isInitialized) return null;
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) return null;
      
      // Get task details
      final taskResponse = await _baseService.client
          .from('tasks')
          .select('*')
          .eq('id', taskId)
          .single();
      
      // Get task comments
      final commentsResponse = await _baseService.client
          .from('task_comments')
          .select('*')
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
          
      // Get creator and assignee info
      String? createdById = taskResponse['created_by'];
      String? assignedToId = taskResponse['assigned_to'];
      
      Map<String, dynamic>? creator;
      Map<String, dynamic>? assignee;
      
      if (createdById != null) {
        final creatorResponse = await _baseService.client
            .from('users')
            .select('id, full_name')
            .eq('id', createdById)
            .maybeSingle();
        
        if (creatorResponse != null) {
          creator = creatorResponse;
        }
      }
      
      if (assignedToId != null) {
        final assigneeResponse = await _baseService.client
            .from('users')
            .select('id, full_name')
            .eq('id', assignedToId)
            .maybeSingle();
        
        if (assigneeResponse != null) {
          assignee = assigneeResponse;
        }
      }
      
      // Get comment user info
      List<Map<String, dynamic>> commentsWithUsers = [];
      for (var comment in commentsResponse) {
        String? userId = comment['user_id'];
        Map<String, dynamic>? user;
        
        if (userId != null) {
          final userResponse = await _baseService.client
              .from('users')
              .select('id, full_name')
              .eq('id', userId)
              .maybeSingle();
          
          if (userResponse != null) {
            user = userResponse;
          }
        }
        
        commentsWithUsers.add({
          ...comment,
          'user': user,
        });
      }
      
      Map<String, dynamic> taskWithDetails = {
        ...taskResponse,
        'creator': creator,
        'assignee': assignee,
      };
          
      return {
        'task': taskWithDetails,
        'comments': commentsWithUsers,
      };
    } catch (e) {
      debugPrint('Error getting task details: $e');
      return null;
    }
  }
  
  // Add a comment to a task
  Future<Map<String, dynamic>> addTaskComment({
    required String taskId,
    required String content,
  }) async {
    try {
      if (!_baseService.isInitialized) {
        return {
          'success': false,
          'error': 'Supabase is not initialized',
        };
      }
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }
      
      // Add the comment
      final response = await _baseService.client
          .from('task_comments')
          .insert({
            'task_id': taskId,
            'user_id': user.id,
            'content': content,
          })
          .select();
          
      if (response.isEmpty) {
        return {
          'success': false,
          'error': 'Failed to add comment',
        };
      }
      
      // Get user info
      final userResponse = await _baseService.client
          .from('users')
          .select('id, full_name')
          .eq('id', user.id)
          .maybeSingle();
      
      final commentWithUser = {
        ...response[0],
        'user': userResponse,
      };
          
      return {
        'success': true,
        'comment': commentWithUser,
      };
    } catch (e) {
      debugPrint('Error adding task comment: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Get team members for task assignment
  Future<List<Map<String, dynamic>>> getTeamMembers() async {
    try {
      if (!_baseService.isInitialized) return [];
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) return [];
      
      // Get the user's team ID
      final userProfile = await _baseService.getCurrentUserProfile();
      if (userProfile == null || userProfile['teams'] == null) return [];
      
      final teamId = userProfile['teams']['team_code'];
      
      // First, get the UUID of the team from the team code
      final teamResponse = await _baseService.client
          .from('teams')
          .select('id')
          .eq('team_code', teamId)
          .limit(1);
      
      if (teamResponse.isEmpty) return [];
      
      final teamIdUuid = teamResponse[0]['id'];
      
      // Then get all users in that team
      final response = await _baseService.client
          .from('users')
          .select('*')
          .eq('team_id', teamIdUuid)
          .order('role', ascending: false); // Put admins first
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting team members: $e');
      return [];
    }
  }
  
  // Helper method to add user details to tasks
  Future<List<Map<String, dynamic>>> _addUserDetailsToTasks(List<Map<String, dynamic>> tasks) async {
    // Create a map to cache user details
    final Map<String, Map<String, dynamic>> userCache = {};
    
    // Function to get user details with caching
    Future<Map<String, dynamic>?> getUserDetails(String? userId) async {
      if (userId == null) return null;
      
      // Return from cache if available
      if (userCache.containsKey(userId)) {
        return userCache[userId];
      }
      
      // Fetch from database
      final userResponse = await _baseService.client
          .from('users')
          .select('id, full_name')
          .eq('id', userId)
          .maybeSingle();
      
      // Cache the result
      if (userResponse != null) {
        userCache[userId] = userResponse;
      }
      
      return userResponse;
    }
    
    // Process all tasks
    List<Map<String, dynamic>> result = [];
    
    for (var task in tasks) {
      final createdById = task['created_by'];
      final assignedToId = task['assigned_to'];
      
      final creator = await getUserDetails(createdById);
      final assignee = await getUserDetails(assignedToId);
      
      result.add({
        ...task,
        'creator': creator,
        'assignee': assignee,
      });
    }
    
    return result;
  }
  
  // Dispose resources
  void dispose() {
    _tasksStreamController.close();
  }
} 