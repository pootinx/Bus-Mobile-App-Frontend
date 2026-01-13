
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// THIS IS A SAMPLE AND WILL NOT WORK UNLESS YOU HAVE A CONFIGURED SMTP SERVICE
// This is a placeholder for a function that sends a custom verification email.
// You would replace this with your actual email sending logic (e.g., using Nodemailer and an SMTP service like SendGrid, Mailgun, etc.)
// The function should send an email to the user with the provided verification link.
async function sendCustomVerificationEmail(email, link, locale) {
  // For demonstration purposes, we'll just log the information.
  console.log(`Sending verification email to ${email} with link: ${link} for locale: ${locale}`);
  
  // In a real implementation, you would have something like:
  /*
  const nodemailer = require('nodemailer');
  const transporter = nodemailer.createTransport({
    host: 'your_smtp_host',
    port: 587,
    secure: false, // true for 465, false for other ports
    auth: {
      user: 'your_smtp_user',
      pass: 'your_smtp_password'
    }
  });

  const mailOptions = {
    from: 'your_email@example.com',
    to: email,
    subject: 'Verify your email for My Awesome App',
    html: `Please click this link to verify your email: <a href="${link}">${link}</a>`
  };

  await transporter.sendMail(mailOptions);
  */

  return Promise.resolve();
}


exports.beforeCreate = functions.auth.user().beforeCreate((user, context) => {
  const locale = context.locale;
  if (user.email && !user.emailVerified) {
    // Send custom email verification on sign-up.
    return admin.auth().generateEmailVerificationLink(user.email).then((link) => {
      return sendCustomVerificationEmail(user.email, link, locale);
    });
  }
});

exports.beforeSignIn = functions.auth.user().beforeSignIn((user, context) => {
 if (user.email && !user.emailVerified) {
   throw new functions.auth.HttpsError(
     'invalid-argument', `"${user.email}" needs to be verified before access is granted.`);
  }
});
