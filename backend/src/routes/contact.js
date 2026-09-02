const router = require("express").Router();
const { z }  = require("zod");
const db     = require("../db");
const nodemailer = require("nodemailer");

const contactSchema = z.object({
  name: z.string().min(1, "Name is required"),
  email: z.string().email("Invalid email address"),
  message: z.string().min(1, "Message is required"),
});

function buildEmailHtml({ name, email, message }) {
  const initials = name.split(" ").map(w => w[0]).join("").toUpperCase().slice(0, 2);
  const date = new Date().toLocaleDateString("en-GB", { weekday: "long", year: "numeric", month: "long", day: "numeric" });

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>New Inquiry — Solstice Eyewear</title>
</head>
<body style="margin:0;padding:0;background:#f0ede8;font-family:'Helvetica Neue',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0ede8;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;">

          <!-- HEADER -->
          <tr>
            <td style="background:#1a1a1a;border-radius:16px 16px 0 0;padding:36px 40px;text-align:center;">
              <p style="margin:0 0 4px;font-size:11px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;color:#8a9e95;">Solstice Eyewear</p>
              <h1 style="margin:0;font-size:22px;font-weight:600;color:#f5f2ec;letter-spacing:-0.02em;">New Store Inquiry</h1>
              <p style="margin:10px 0 0;font-size:13px;color:#6b7f78;">${date}</p>
            </td>
          </tr>

          <!-- AVATAR BAND -->
          <tr>
            <td style="background:#2c2c2c;padding:24px 40px;border-bottom:1px solid #3a3a3a;">
              <table cellpadding="0" cellspacing="0">
                <tr>
                  <td style="vertical-align:middle;padding-right:16px;">
                    <div style="width:52px;height:52px;border-radius:50%;background:linear-gradient(135deg,#6f9686,#3f6b5c);display:flex;align-items:center;justify-content:center;font-size:18px;font-weight:700;color:#fff;text-align:center;line-height:52px;">${initials}</div>
                  </td>
                  <td style="vertical-align:middle;">
                    <p style="margin:0;font-size:16px;font-weight:600;color:#f5f2ec;">${name}</p>
                    <a href="mailto:${email}" style="margin:2px 0 0;font-size:13px;color:#8a9e95;text-decoration:none;">${email}</a>
                  </td>
                  <td style="vertical-align:middle;text-align:right;padding-left:16px;">
                    <span style="display:inline-block;padding:5px 14px;background:#3f6b5c;border-radius:20px;font-size:11px;font-weight:700;color:#c8e0d8;letter-spacing:0.06em;text-transform:uppercase;">New</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- MESSAGE BODY -->
          <tr>
            <td style="background:#fff;padding:36px 40px;">
              <p style="margin:0 0 12px;font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#b0a899;">Message</p>
              <div style="background:#faf9f7;border-left:3px solid #6f9686;border-radius:0 8px 8px 0;padding:20px 24px;">
                <p style="margin:0;font-size:15px;line-height:1.75;color:#2a2a2a;white-space:pre-wrap;">${message.replace(/</g, "&lt;").replace(/>/g, "&gt;")}</p>
              </div>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td style="background:#fff;padding:0 40px 36px;text-align:center;">
              <a href="mailto:${email}?subject=Re: Your Solstice Eyewear Inquiry" style="display:inline-block;padding:14px 36px;background:#1a1a1a;color:#f5f2ec;border-radius:40px;font-size:14px;font-weight:600;text-decoration:none;letter-spacing:0.02em;">Reply to ${name.split(" ")[0]}</a>
            </td>
          </tr>

          <!-- DIVIDER -->
          <tr>
            <td style="background:#fff;padding:0 40px;">
              <div style="height:1px;background:#ede9e2;"></div>
            </td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td style="background:#fff;border-radius:0 0 16px 16px;padding:24px 40px;text-align:center;">
              <p style="margin:0;font-size:12px;color:#b0a899;">This email was sent automatically by the <strong style="color:#6f9686;">Solstice Eyewear</strong> contact system.</p>
              <p style="margin:6px 0 0;font-size:12px;color:#c8c2bb;">© ${new Date().getFullYear()} Solstice Eyewear · All rights reserved.</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

router.post("/", async (req, res) => {
  try {
    const { name, email, message } = contactSchema.parse(req.body);

    // 1. Save to database (this is the critical step)
    await db.query(
      "INSERT INTO contact_messages (name, email, message) VALUES ($1, $2, $3)",
      [name, email, message]
    );

    // 2. Respond immediately — don't make the user wait for email
    res.status(201).json({ success: true, message: "Message received" });

    // 3. Send email in the background (fire-and-forget, never fails the request)
    if (process.env.SMTP_USER && process.env.SMTP_PASS && process.env.SMTP_PASS !== "your_gmail_app_password") {
      const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST || "smtp.gmail.com",
        port: parseInt(process.env.SMTP_PORT || "587"),
        secure: false,
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      });

      transporter.sendMail({
        from: `"Solstice Eyewear" <${process.env.SMTP_USER}>`,
        replyTo: email,
        to: "debbicheali04@gmail.com",
        subject: `✉️ New Inquiry from ${name} — Solstice Eyewear`,
        text: `Name: ${name}\nEmail: ${email}\n\nMessage:\n${message}`,
        html: buildEmailHtml({ name, email, message }),
      }).then(() => {
        console.log(`Email sent for inquiry from ${name}`);
      }).catch((err) => {
        console.error("Email dispatch failed (non-critical):", err.message);
      });
    }

  } catch (e) {
    console.error("Contact Error:", e);
    res.status(400).json({ error: e.message || "Bad Request" });
  }
});

module.exports = router;


