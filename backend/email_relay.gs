/**
 * VoiceIQ email relay (Google Apps Script).
 * Sends verification / password-reset codes from your own Gmail account, so they reach the inbox.
 *
 * Setup: script.google.com -> New project -> paste this file -> set SECRET to the same value as
 * EMAIL_SCRIPT_SECRET on Render -> Deploy -> New deployment -> Web app
 * (Execute as: Me, Who has access: Anyone) -> copy the Web app URL into EMAIL_SCRIPT_URL on Render.
 * Free Gmail accounts can send about 100 emails per day this way.
 */
const SECRET = 'PASTE_EMAIL_SCRIPT_SECRET_HERE';

function doPost(e) {
  let data;
  try {
    data = JSON.parse(e.postData.contents);
  } catch (err) {
    return reply({ ok: false, error: 'invalid request' });
  }
  if (data.secret !== SECRET) {
    return reply({ ok: false, error: 'unauthorized' });
  }
  MailApp.sendEmail({
    to: data.to,
    subject: data.subject,
    htmlBody: data.html,
    name: 'VoiceIQ',
  });
  return reply({ ok: true, remainingQuota: MailApp.getRemainingDailyQuota() });
}

function reply(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
