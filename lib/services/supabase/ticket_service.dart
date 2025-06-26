import 'package:flutter/material.dart';
import 'base_service.dart';
import 'dart:async';

class TicketService {
  final BaseSupabaseService _baseService = BaseSupabaseService();
  
  // Stream controller for ticket updates
  final StreamController<List<Map<String, dynamic>>> _ticketsStreamController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  
  // Expose stream for UI components to listen to
  Stream<List<Map<String, dynamic>>> get ticketsStream => _ticketsStreamController.stream;
  
  // Get tickets for the current user's team
  Future<List<Map<String, dynamic>>> getTickets() async {
    try {
      if (!_baseService.isInitialized) return [];
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) return [];
      
      // Get the user's team ID
      final userProfile = await _baseService.getCurrentUserProfile();
      if (userProfile == null || userProfile['team_id'] == null) return [];
      
      final teamId = userProfile['team_id'];
      
      // Get all tickets for this team
      final response = await _baseService.client
          .from('tickets')
          .select('*')
          .eq('team_id', teamId)
          .order('created_at', ascending: false);
      
      final tickets = List<Map<String, dynamic>>.from(response);
      
      // Fetch creator and assignee information for each ticket
      final ticketsWithDetails = await _addUserDetailsToTickets(tickets);
      
      // Update the stream
      _ticketsStreamController.add(ticketsWithDetails);
      
      return ticketsWithDetails;
    } catch (e) {
      debugPrint('Error getting tickets: $e');
      return [];
    }
  }
  
  // Get team members for ticket assignment
  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    try {
      if (!_baseService.isInitialized) return [];
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) return [];
      
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
  
  // Create a new ticket
  Future<Map<String, dynamic>> createTicket({
    required String title,
    String? description,
    required String priority,
    required String category,
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
      
      // Create the ticket data map
      final Map<String, dynamic> ticketData = {
        'title': title,
        'description': description,
        'priority': priority.toLowerCase(),
        'category': category,
        'status': 'open',
        'approval_status': 'pending',
        'team_id': teamId,
        'created_by': user.id,
      };
      
      if (assignedToUserId != null && assignedToUserId.isNotEmpty) {
        ticketData['assigned_to'] = assignedToUserId;
      }
      
      final response = await _baseService.client
          .from('tickets')
          .insert(ticketData)
          .select();
          
      if (response.isEmpty) {
        return {
          'success': false,
          'error': 'Failed to create ticket',
        };
      }
      
      // Refresh tickets list
      getTickets();
      
      return {
        'success': true,
        'ticket': response[0],
      };
    } catch (e) {
      debugPrint('Error creating ticket: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update a ticket's status
  Future<Map<String, dynamic>> updateTicketStatus({
    required String ticketId,
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
      
      // Update the ticket status
      await _baseService.client
          .from('tickets')
          .update({'status': status})
          .eq('id', ticketId);
      
      // Refresh tickets list
      getTickets();
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating ticket status: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update a ticket's approval status (admin only)
  Future<Map<String, dynamic>> updateTicketApproval({
    required String ticketId,
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
          'error': 'Only admins can approve tickets',
        };
      }
      
      // Update the ticket approval status
      await _baseService.client
          .from('tickets')
          .update({'approval_status': approvalStatus})
          .eq('id', ticketId);
      
      // Refresh tickets list
      getTickets();
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating ticket approval: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Update ticket priority
  Future<Map<String, dynamic>> updateTicketPriority({
    required String ticketId,
    required String priority,
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
      
      // Update the ticket priority
      await _baseService.client
          .from('tickets')
          .update({'priority': priority.toLowerCase()})
          .eq('id', ticketId);
      
      // Refresh tickets list
      getTickets();
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating ticket priority: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Get ticket details with comments
  Future<Map<String, dynamic>?> getTicketDetails(String ticketId) async {
    try {
      if (!_baseService.isInitialized) return null;
      
      final user = _baseService.client.auth.currentUser;
      if (user == null) return null;
      
      // Get ticket details
      final ticketResponse = await _baseService.client
          .from('tickets')
          .select('*')
          .eq('id', ticketId)
          .single();
      
      // Get ticket comments
      final commentsResponse = await _baseService.client
          .from('ticket_comments')
          .select('*')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
          
      // Get creator and assignee info
      String? createdById = ticketResponse['created_by'];
      String? assignedToId = ticketResponse['assigned_to'];
      
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
      
      Map<String, dynamic> ticketWithDetails = {
        ...ticketResponse,
        'creator': creator,
        'assignee': assignee,
      };
          
      return {
        'ticket': ticketWithDetails,
        'comments': commentsWithUsers,
      };
    } catch (e) {
      debugPrint('Error getting ticket details: $e');
      return null;
    }
  }
  
  // Add a comment to a ticket
  Future<Map<String, dynamic>> addTicketComment({
    required String ticketId,
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
          .from('ticket_comments')
          .insert({
            'ticket_id': ticketId,
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
      debugPrint('Error adding ticket comment: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Assign ticket to user
  Future<Map<String, dynamic>> assignTicket({
    required String ticketId,
    required String userId,
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
      
      // Update the ticket assignment
      await _baseService.client
          .from('tickets')
          .update({'assigned_to': userId})
          .eq('id', ticketId);
      
      // Refresh tickets list
      getTickets();
          
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error assigning ticket: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Helper method to add user details to tickets
  Future<List<Map<String, dynamic>>> _addUserDetailsToTickets(List<Map<String, dynamic>> tickets) async {
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
    
    // Process all tickets
    List<Map<String, dynamic>> result = [];
    
    for (var ticket in tickets) {
      final createdById = ticket['created_by'];
      final assignedToId = ticket['assigned_to'];
      
      final creator = await getUserDetails(createdById);
      final assignee = await getUserDetails(assignedToId);
      
      result.add({
        ...ticket,
        'creator': creator,
        'assignee': assignee,
      });
    }
    
    return result;
  }
  
  // Get ticket categories (defined in UI)
  List<String> getTicketCategories() {
    return [
      'Bug',
      'Feature',
      'Enhancement',
      'Documentation',
      'UI/UX',
      'Performance',
      'Security',
      'Testing',
      'Other'
    ];
  }
  
  // Dispose resources
  void dispose() {
    _ticketsStreamController.close();
  }
} 