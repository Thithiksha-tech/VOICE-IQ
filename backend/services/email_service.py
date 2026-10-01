import os
import json
import urllib.request
import urllib.error
from dotenv import load_dotenv

load_dotenv()

BREVO_URL = "https://api.brevo.com/v3/smtp/email"


def _post_json(url: str, payload: dict, headers: dict) -> bytes:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json", **headers},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def _send_via_gmail_script(script_url: str, to_email: str, subject: str, html: str) -> None:
    """Google Apps Script web app that sends from the owner's real Gmail (best inbox delivery)."""
    body = _post_json(script_url, {
        "secret": os.getenv("EMAIL_SCRIPT_SECRET", ""),
        "to": to_email,
        "subject": subject,
        "html": html,
    }, {})
    try:
        result = json.loads(body)
    except ValueError:
        raise RuntimeError(f"Email script returned an unexpected reply: {body[:200]!r}")
    if not result.get("ok"):
        raise RuntimeError(f"Email script refused the request: {result.get('error')}")


def _send_via_brevo(api_key: str, sender: str, to_email: str, subject: str, html: str) -> None:
    try:
        _post_json(BREVO_URL, {
            "sender": {"email": sender, "name": os.getenv("EMAIL_FROM_NAME", "VoiceIQ")},
            "to": [{"email": to_email}],
            "subject": subject,
            "htmlContent": html,
        }, {"api-key": api_key})
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Brevo rejected the email ({e.code}): {e.read().decode('utf-8', 'replace')[:300]}")


def send_email(to_email: str, subject: str, html: str) -> None:
    """
    Sends an email over HTTPS (Render's free tier blocks SMTP ports).
    Prefers the Gmail Apps Script relay (EMAIL_SCRIPT_URL), then Brevo (BREVO_API_KEY + EMAIL_FROM).
    With neither configured (local development) the message is printed to the server log.
    """
    script_url = os.getenv("EMAIL_SCRIPT_URL")
    if script_url:
        _send_via_gmail_script(script_url, to_email, subject, html)
        return

    api_key, sender = os.getenv("BREVO_API_KEY"), os.getenv("EMAIL_FROM")
    if api_key and sender:
        _send_via_brevo(api_key, sender, to_email, subject, html)
        return

    print(f"[Email] No email service configured; would send to {to_email}: {subject}\n{html}")
