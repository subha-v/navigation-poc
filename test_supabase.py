#!/usr/bin/env python3
"""
Test script to verify Supabase tables are created correctly
"""

import requests
import json

# Your Supabase credentials (from SupabaseConfig.swift)
SUPABASE_URL = "https://hofzmltxieveekiwvjxy.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhvZnptbHR4aWV2ZWVraXd2anh5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU4MTI3NzksImV4cCI6MjA3MTM4ODc3OX0.PUOwftAd855RuVSiLqPm3VzGjLPM-3JipwPFEvK3Szw"

def test_tables():
    """Test if tables exist and are accessible"""
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }
    
    print("Testing Supabase connection...")
    print(f"URL: {SUPABASE_URL}")
    print()
    
    # Test users table
    print("1. Testing 'users' table...")
    users_url = f"{SUPABASE_URL}/rest/v1/users?select=*&limit=1"
    response = requests.get(users_url, headers=headers)
    
    if response.status_code == 200:
        print("   ✅ Users table exists and is accessible")
        print(f"   Response: {response.text}")
    else:
        print(f"   ❌ Error accessing users table: {response.status_code}")
        print(f"   Response: {response.text}")
    
    print()
    
    # Test navigation_ratings table
    print("2. Testing 'navigation_ratings' table...")
    ratings_url = f"{SUPABASE_URL}/rest/v1/navigation_ratings?select=*&limit=1"
    response = requests.get(ratings_url, headers=headers)
    
    if response.status_code == 200:
        print("   ✅ Navigation_ratings table exists and is accessible")
        print(f"   Response: {response.text}")
    else:
        print(f"   ❌ Error accessing navigation_ratings table: {response.status_code}")
        print(f"   Response: {response.text}")
    
    print()
    print("=" * 50)
    print("Table structure verification complete!")
    print("If both tables show ✅, your Supabase is configured correctly.")
    print("If you see ❌, check the error message and ensure tables were created.")

if __name__ == "__main__":
    test_tables()