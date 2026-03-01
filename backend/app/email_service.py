"""Email notification service with HTML templates for Famba."""
import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional


SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
FROM_NAME = os.getenv("FROM_NAME", "Famba")
FROM_EMAIL = os.getenv("FROM_EMAIL", SMTP_USER or "noreply@famba.app")


def _base_html(title: str, body: str) -> str:
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>{title}</title>
<style>
  body {{ margin:0; padding:0; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; background:#f5f5f5; }}
  .wrap {{ max-width:560px; margin:24px auto; background:#fff; border-radius:12px; overflow:hidden; box-shadow:0 2px 12px rgba(0,0,0,.08); }}
  .header {{ background:linear-gradient(135deg,#ff6600,#ff8533); padding:28px 32px; text-align:center; }}
  .header h1 {{ color:#fff; margin:0; font-size:26px; letter-spacing:1px; }}
  .body {{ padding:32px; color:#333; line-height:1.6; }}
  .body h2 {{ margin-top:0; color:#222; }}
  .btn {{ display:inline-block; padding:12px 28px; background:#ff6600; color:#fff !important; text-decoration:none; border-radius:8px; font-weight:600; margin:16px 0; }}
  .footer {{ padding:20px 32px; background:#fafafa; text-align:center; font-size:12px; color:#999; }}
  .detail {{ background:#f9f9f9; border-radius:8px; padding:16px; margin:12px 0; }}
  .detail td {{ padding:4px 12px 4px 0; }}
  .detail .label {{ color:#888; font-size:13px; }}
  .detail .value {{ font-weight:600; }}
</style></head><body>
<div class="wrap">
  <div class="header"><h1>Famba</h1></div>
  <div class="body">{body}</div>
  <div class="footer">&copy; 2026 Famba &middot; Harare, Zimbabwe</div>
</div>
</body></html>"""


def welcome_email(name: str) -> tuple:
    subject = "Welcome to Famba! 🏍️"
    body = f"""
    <h2>Hey {name}!</h2>
    <p>Welcome to <strong>Famba</strong>, the fastest way to get around Harare.</p>
    <p>Whether you need a motorcycle ride across town or food delivered to your door, we've got you covered.</p>
    <a class="btn" href="https://famba.app">Open Famba</a>
    <p>Questions? Just reply to this email.</p>
    """
    return subject, _base_html(subject, body)


def ride_receipt_email(name: str, ride: dict) -> tuple:
    subject = f"Your Famba ride receipt - ${ride.get('fare_usd', 0):.2f}"
    body = f"""
    <h2>Ride complete</h2>
    <p>Thanks for riding with Famba, {name}!</p>
    <div class="detail"><table>
      <tr><td class="label">From</td><td class="value">{ride.get('pickup_text','')}</td></tr>
      <tr><td class="label">To</td><td class="value">{ride.get('drop_text','')}</td></tr>
      <tr><td class="label">Distance</td><td class="value">{ride.get('distance_km',0):.1f} km</td></tr>
      <tr><td class="label">Duration</td><td class="value">{ride.get('duration_min',0):.0f} min</td></tr>
      <tr><td class="label">Driver</td><td class="value">{ride.get('driver_name','')}</td></tr>
      <tr><td class="label">Fare</td><td class="value"><strong>${ride.get('fare_usd',0):.2f}</strong></td></tr>
    </table></div>
    <p>Have feedback? <a href="mailto:support@famba.app">Let us know</a>.</p>
    """
    return subject, _base_html(subject, body)


def food_order_receipt_email(name: str, order: dict) -> tuple:
    subject = f"Your Famba food order - ${order.get('total', 0):.2f}"
    items_html = "".join(
        f"<tr><td>{it.get('name','')}</td><td>×{it.get('qty',1)}</td>"
        f"<td>${it.get('price',0):.2f}</td></tr>"
        for it in order.get("items", [])
    )
    body = f"""
    <h2>Order confirmed</h2>
    <p>Hey {name}, your food order is on the way!</p>
    <div class="detail"><table>
      <tr><td class="label">Restaurant</td><td class="value">{order.get('restaurant_name','')}</td></tr>
      <tr><td class="label">Delivery to</td><td class="value">{order.get('delivery_address','')}</td></tr>
    </table>
    <table style="width:100%;margin-top:8px">
      <thead><tr><th style="text-align:left">Item</th><th>Qty</th><th>Price</th></tr></thead>
      <tbody>{items_html}</tbody>
      <tfoot><tr><td colspan="2" style="text-align:right;font-weight:600">Total</td>
        <td style="font-weight:600">${order.get('total',0):.2f}</td></tr></tfoot>
    </table></div>
    """
    return subject, _base_html(subject, body)


def dispute_update_email(name: str, dispute: dict) -> tuple:
    status = dispute.get("status", "updated")
    subject = f"Dispute {status} - Famba"
    body = f"""
    <h2>Dispute {status}</h2>
    <p>Hi {name},</p>
    <p>Your dispute <strong>#{dispute.get('id','')}</strong> has been <strong>{status}</strong>.</p>
    <div class="detail"><table>
      <tr><td class="label">Type</td><td class="value">{dispute.get('type','')}</td></tr>
      <tr><td class="label">Resolution</td><td class="value">{dispute.get('resolution','Pending')}</td></tr>
      <tr><td class="label">Refund</td><td class="value">${dispute.get('refund_amount',0):.2f}</td></tr>
    </table></div>
    <p>If you have questions, reply to this email.</p>
    """
    return subject, _base_html(subject, body)


def driver_verified_email(name: str) -> tuple:
    subject = "You're verified! - Famba"
    body = f"""
    <h2>Congratulations, {name}!</h2>
    <p>All your documents have been reviewed and approved. You're now a verified Famba driver.</p>
    <p>You can start accepting rides and food delivery jobs right away.</p>
    <a class="btn" href="https://famba.app/driver">Open Driver App</a>
    """
    return subject, _base_html(subject, body)


def password_reset_email(name: str, reset_code: str) -> tuple:
    subject = "Password reset - Famba"
    body = f"""
    <h2>Password reset request</h2>
    <p>Hi {name}, use the code below to reset your password:</p>
    <div style="text-align:center;margin:24px 0">
      <span style="font-size:32px;letter-spacing:8px;font-weight:700;color:#ff6600">{reset_code}</span>
    </div>
    <p>This code expires in 15 minutes. If you didn't request a reset, you can safely ignore this email.</p>
    """
    return subject, _base_html(subject, body)


def send_email(to: str, subject: str, html_body: str) -> bool:
    """Send an email via SMTP. Returns True on success."""
    if not SMTP_USER or not SMTP_PASS:
        print(f"[EMAIL STUB] To: {to} | Subject: {subject}")
        return True  # silent success in dev (no SMTP configured)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{FROM_NAME} <{FROM_EMAIL}>"
    msg["To"] = to
    msg.attach(MIMEText(html_body, "html"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.sendmail(FROM_EMAIL, [to], msg.as_string())
        return True
    except Exception as e:
        print(f"[EMAIL ERROR] {e}")
        return False


def notify(to_email: Optional[str], template: str, **kwargs) -> bool:
    """High-level notify function. Gracefully skips if email is missing."""
    if not to_email:
        return False

    templates = {
        "welcome": welcome_email,
        "ride_receipt": ride_receipt_email,
        "food_receipt": food_order_receipt_email,
        "dispute_update": dispute_update_email,
        "driver_verified": driver_verified_email,
        "password_reset": password_reset_email,
    }
    fn = templates.get(template)
    if not fn:
        return False

    subject, html = fn(**kwargs)
    return send_email(to_email, subject, html)
