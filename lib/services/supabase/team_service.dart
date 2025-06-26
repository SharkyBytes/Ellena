import 'package:flutter/material.dart';
import 'base_service.dart';
import 'dart:async';

class TeamService {
  final BaseSupabaseService _baseService = BaseSupabaseService();
  
  // Stream controller for team members updates
  final StreamController<List<Map<String, dynamic>>> _teamMembersStreamController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  
  // Expose stream for UI components to listen to
  Stream<List<Map<String, dynamic>>> get teamMembersStream => _teamMembersStreamController.stream;
  
  // Get all members of a specific team
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
      
      final members = List<Map<String, dynamic>>.from(response);
      
      // Update the stream
      _teamMembersStreamController.add(members);
          
      return members;
    } catch (e) {
      debugPrint('Error getting team members: $e');
      return [];
    }
  }
  
  // Get current team information
  Future<Map<String, dynamic>?> getCurrentTeam() async {
    try {
      if (!_baseService.isInitialized) return null;
      
      final userProfile = await _baseService.getCurrentUserProfile();
      if (userProfile == null || userProfile['teams'] == null) return null;
      
      return userProfile['teams'];
    } catch (e) {
      debugPrint('Error getting current team: $e');
      return null;
    }
  }
  
  // Update team information (admin only)
  Future<Map<String, dynamic>> updateTeam(Map<String, dynamic> data) async {
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
          'error': 'Only admins can update team information',
        };
      }
      
      final teamId = userProfile['team_id'];
      
      // Update the team
      await _baseService.client
          .from('teams')
          .update(data)
          .eq('id', teamId);
      
      // Refresh user profile to get updated team info
      await _baseService.getCurrentUserProfile(forceRefresh: true);
      
      return {
        'success': true,
      };
    } catch (e) {
      debugPrint('Error updating team: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Invite a new member to the team (admin only)
  Future<Map<String, dynamic>> inviteMember(String email) async {
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
          'error': 'Only admins can invite team members',
        };
      }
      
      final teamId = userProfile['teams']['team_code'];
      
      // TODO: Implement email invitation functionality
      // For now, just return the team code that can be shared manually
      
      return {
        'success': true,
        'teamCode': teamId,
        'message': 'Share this team code with the person you want to invite',
      };
    } catch (e) {
      debugPrint('Error inviting member: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Dispose resources
  void dispose() {
    _teamMembersStreamController.close();
  }
} 