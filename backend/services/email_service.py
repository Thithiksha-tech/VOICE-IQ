import os
import json
import urllib.request
import urllib.error
from dotenv import load_dotenv

load_dotenv()

BREVO_URL = "https://api.brevo.com/v3/smtp/email"


def send_email(to_email: str, subject: str, html: str) -> None:
    """
    Sends an email through Brevo's HTTPS API (Render's free tier blocks SMTP ports).
    Without BREVO_API_KEY (local development) the message is printed to the server log.
    """
    api_key = os.getenv("BREVO_API_KEY")
    sender = os.getenv("EMAIL_FROM")

    if not api_key or not sender:
        print(f"[Email] BREVO_API_KEY/EMAIL_FROM not set; would send to {to_email}: {subject}\n{html}")
        return

    payload = {
        "sender": {"email": sender, "name": os.getenv("EMAIL_FROM_NAME", "VoiceIQ")},
        "to": [{"email": to_email}],
        "subject": subject,
        "htmlContent": html,
    }
    request = urllib.request.Request(
        BREVO_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"api-key": api_key, "Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            response.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Brevo rejected the email ({e.code}): {e.read().decode('utf-8', 'replace')[:300]}")
