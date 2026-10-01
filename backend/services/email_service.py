import os
import json
import urllib.request
from dotenv import load_dotenv

load_dotenv()


def _post_json(url: str, payload: dict) -> bytes:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
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
    })
    try:
        result = json.loads(body)
    except ValueError:
        raise RuntimeError(f"Email script returned an unexpected reply: {body[:200]!r}")
    if not result.get("ok"):
        raise RuntimeError(f"Email script refused the request: {result.get('error')}")


def send_email(to_email: str, subject: str, html: str) -> None:
    """
    Sends an email through the Gmail Apps Script relay (EMAIL_SCRIPT_URL) over HTTPS,
    since Render's free tier blocks SMTP ports. Without it (local development) the
    message is printed to the server log.
    """
    script_url = os.getenv("EMAIL_SCRIPT_URL")
    if script_url:
        _send_via_gmail_script(script_url, to_email, subject, html)
        return

    print(f"[Email] EMAIL_SCRIPT_URL not set; would send to {to_email}: {subject}\n{html}")
