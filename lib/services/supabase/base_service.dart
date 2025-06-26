import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BaseSupabaseService {
  static final BaseSupabaseService _instance = BaseSupabaseService._internal();
  late final SupabaseClient _client;
  bool _isInitialized = false;
  
  // Cache for user profile data
  Map<String, dynamic>? _cachedUserProfile;
  
  factory BaseSupabaseService() {
    return _instance;
  }
  
  BaseSupabaseService._internal();
  
  bool get isInitialized => _isInitialized;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Try to load from .env file
      await dotenv.load().catchError((e) {
        debugPrint('Error loading .env file: $e');
        // If .env file is not found, we'll use hardcoded values below
      });
      
      // Get values from .env or use placeholder values for development
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      
      // Load cached user profile if available
      await _loadCachedUserProfile();
      
      // Set up auth state change listener
      _client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedOut) {
          _clearCachedUserProfile();
        }
      });
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }
  
  SupabaseClient get client => _client;
  
  // Get current user profile with caching
  Future<Map<String, dynamic>?> getCurrentUserProfile({bool forceRefresh = false}) async {
    try {
      if (!_isInitialized) return null;
      
      final user = _client.auth.currentUser;
      if (user == null) return null;
      
      // Return cached profile if available and not forcing refresh
      if (!forceRefresh && _cachedUserProfile != null) {
        return _cachedUserProfile;
      }
      
      final response = await _client
          .from('users')
          .select('*, teams(name, team_code)')
          .eq('id', user.id)
          .maybeSingle();
          
      if (response != null) {
        _cachedUserProfile = response;
        await _saveCachedUserProfile(response);
      }
      
      return response;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return _cachedUserProfile; // Return cached profile on error
    }
  }
  
  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      if (!_isInitialized) return false;
      
      final user = _client.auth.currentUser;
      if (user == null) return false;
      
      await _client
          .from('users')
          .update(data)
          .eq('id', user.id);
      
      // Refresh cached profile
      _cachedUserProfile = null;
      await getCurrentUserProfile(forceRefresh: true);
          
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    if (!_isInitialized) return;
    _clearCachedUserProfile();
    await _client.auth.signOut();
  }
  
  // Cache management methods
  Future<void> _saveCachedUserProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', jsonEncode(profile));
    } catch (e) {
      debugPrint('Error saving cached profile: $e');
    }
  }
  
  Future<void> _loadCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      
      if (profileJson != null) {
        _cachedUserProfile = jsonDecode(profileJson);
      }
    } catch (e) {
      debugPrint('Error loading cached profile: $e');
    }
  }
  
  Future<void> _clearCachedUserProfile() async {
    try {
      _cachedUserProfile = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');
    } catch (e) {
      debugPrint('Error clearing cached profile: $e');
    }
  }
} 