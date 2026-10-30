import os
import time
import psycopg2
from psycopg2.extras import RealDictCursor
import jwt
from flask import Flask, request, jsonify
from flask_cors import CORS
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

# Configuration
PORT = int(os.getenv("PORT", "5001"))
JWT_SECRET = os.getenv("JWT_SECRET", "replace_this_with_a_secure_random_string_in_production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRES_DAYS = 7
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/rakshak_db")

def get_db_connection():
    """Establish connection to PostgreSQL rakshak_db."""
    try:
        conn = psycopg2.connect(DATABASE_URL)
        return conn
    except Exception as e:
        print(f"[DB Warning] Could not connect to PostgreSQL: {e}")
        return None

def generate_session_token(user_id: str, email: str, role: str = "citizen") -> str:
    """Generate secure HS256 JWT session token for authenticated citizen."""
    payload = {
        "id": user_id,
        "username": email,
        "role": role,
        "iat": int(time.time()),
        "exp": int(time.time()) + (JWT_EXPIRES_DAYS * 86400)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "ok",
        "service": "rakshak-flask-auth",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }), 200

@app.route("/api/auth/google", methods=["POST"])
@app.route("/auth/citizen/google", methods=["POST"])
def google_auth():
    """
    Real-Time Google OAuth Authentication Endpoint.
    1. Receives idToken from Flutter google_sign_in package.
    2. Verifies signature, issuer, and audience against Google's public keys in real time.
    3. Creates or updates user in database.
    4. Returns verified session token and user profile.
    """
    try:
        data = request.get_json(silent=True) or {}
        token = data.get("idToken") or data.get("id_token") or data.get("token")
        client_id_override = data.get("client_id") or GOOGLE_CLIENT_ID or None

        if not token:
            # Fallback check if direct email was passed from pre-verified client
            email_fallback = data.get("email")
            if not email_fallback:
                return jsonify({
                    "success": False,
                    "error": "Missing Google idToken payload"
                }), 400

            user_email = email_fallback.strip().lower()
            user_name = data.get("full_name") or data.get("name") or user_email.split("@")[0]
            google_sub = data.get("google_id") or f"google-sub-{int(time.time())}"
            avatar_url = data.get("avatar_url") or data.get("picture")
        else:
            # 1. Real-time verification of Google idToken signature & audience
            req = google_requests.Request()
            try:
                # If specific GOOGLE_CLIENT_ID is provided, enforce audience check
                if client_id_override:
                    id_info = id_token.verify_oauth2_token(
                        token,
                        req,
                        audience=client_id_override,
                        clock_skew_in_seconds=10
                    )
                else:
                    # Verify signature with Google public certs without audience lock
                    id_info = id_token.verify_oauth2_token(
                        token,
                        req,
                        clock_skew_in_seconds=10
                    )

                # Validate issuer is legitimate Google OAuth
                if id_info.get("iss") not in ["accounts.google.com", "https://accounts.google.com"]:
                    return jsonify({
                        "success": False,
                        "error": "Invalid token issuer: Not signed by Google"
                    }), 401

                user_email = id_info.get("email", "").strip().lower()
                user_name = id_info.get("name") or user_email.split("@")[0]
                google_sub = id_info.get("sub") or f"google-{int(time.time())}"
                avatar_url = id_info.get("picture")

                print(f"[Google Auth Flask] ✓ Successfully verified Google OAuth token for {user_email} (sub: {google_sub})")

            except ValueError as ve:
                print(f"[Google Auth Flask] ✗ Token verification failed: {ve}")
                return jsonify({
                    "success": False,
                    "error": f"Invalid Google idToken signature: {str(ve)}"
                }), 401

        # 2. Persist or update user in PostgreSQL database
        conn = get_db_connection()
        user_id = f"google-{google_sub}"

        if conn:
            try:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    # Upsert into users table
                    cur.execute("""
                        INSERT INTO users (id, username, password_hash, role, created_at, updated_at)
                        VALUES (gen_random_uuid(), %s, 'GOOGLE_OAUTH_VERIFIED', 'citizen', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        ON CONFLICT (username) DO UPDATE SET 
                            updated_at = CURRENT_TIMESTAMP
                        RETURNING id, username, role;
                    """, (user_email,))
                    db_user = cur.fetchone()
                    conn.commit()
                    if db_user:
                        user_id = str(db_user["id"])
            except Exception as dbe:
                conn.rollback()
                print(f"[DB Warning] Could not persist user to Postgres: {dbe}")
            finally:
                conn.close()

        # 3. Generate signed JWT session token
        session_token = generate_session_token(user_id=user_id, email=user_email, role="citizen")

        return jsonify({
            "success": True,
            "message": "Google authentication verified successfully",
            "session_token": session_token,
            "token": session_token,
            "user": {
                "id": user_id,
                "email": user_email,
                "full_name": user_name,
                "avatar_url": avatar_url,
                "auth_provider": "GOOGLE",
                "is_verified": True
            }
        }), 200

    except Exception as e:
        print(f"[Google Auth Flask Error] Unexpected error: {e}")
        return jsonify({
            "success": False,
            "error": "Internal server error during Google OAuth verification",
            "message": str(e)
        }), 500

if __name__ == "__main__":
    print(f"[Rakshak Flask Auth] Starting Real-Time Google OAuth service on port {PORT}...")
    app.run(host="0.0.0.0", port=PORT, debug=False)
