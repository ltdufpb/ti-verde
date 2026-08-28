#!/usr/bin/env python3
"""
Helper script to trigger LibrePhotos photo scan / AI processing pipeline
"""
import urllib.request
import json
import sys

BASE_URL = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:3000'
USERNAME = sys.argv[2] if len(sys.argv) > 2 else 'admin'
PASSWORD = sys.argv[3] if len(sys.argv) > 3 else 'AdminPass123!'

print(f"==> Autenticando no LibrePhotos em {BASE_URL}...")
login_payload = json.dumps({'username': USERNAME, 'password': PASSWORD}).encode('utf-8')
req = urllib.request.Request(f'{BASE_URL}/api/auth/token/obtain/', data=login_payload, headers={'Content-Type': 'application/json'})

try:
    with urllib.request.urlopen(req) as resp:
        tokens = json.loads(resp.read().decode('utf-8'))
    access_token = tokens['access']
    print("  [OK] Token JWT obtido com sucesso.")
except Exception as e:
    print(f"  [ERRO] Falha ao autenticar: {e}")
    sys.exit(1)

print("==> Disparando job de scan e processamento de fotos (IA/Thumbnails/Face Recognition)...")
scan_req = urllib.request.Request(f'{BASE_URL}/api/scanphotos/', headers={'Authorization': f'Bearer {access_token}'})
try:
    with urllib.request.urlopen(scan_req) as resp:
        result = json.loads(resp.read().decode('utf-8'))
        print(f"  [OK] Scan iniciado! Job ID: {result.get('job_id')}")
        print("  Processando imagens em background no container 'backend'...")
except Exception as e:
    print(f"  [ERRO] Falha ao disparar scan: {e}")
    sys.exit(1)
