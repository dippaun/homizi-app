import 'package:flutter/material.dart';
import 'package:homizi/features/legal/legal_document.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Privacy Policy',
      intro:
          'HOMIZI is a way to look for a rental or a flatmate. This draft says what the current app actually collects. A build with no Supabase URL keeps data on the device. A build pointed at the staging project stores data in Supabase in Mumbai (ap-south-1). Sentry stays off unless the build was compiled with a SENTRY_DSN. Product analytics can be turned off in Settings.',
      sections: [
        LegalSection(
          heading: 'Where data is stored',
          body:
              'Demo mode is the default when SUPABASE_URL or the public client key is empty. Profiles, listings, messages, and photos then stay on the device and are not sent to a server. When both values are set, the app uses Supabase Auth, Postgres, and Storage. The staging project in this repository is loraalfiuklespaldotd, hosted in Mumbai (ap-south-1). A production region is not approved. The client key is the public publishable key. The service-role key is not in the app.',
        ),
        LegalSection(
          heading: 'Account and profile',
          body:
              'Sign-in uses an email address or, in demo mode, a phone number typed into the app. Hosted phone SMS is off. Staging emails a 6-digit code. The app stores a display name, an occupation, and a bio if you enter them. The profile row does not store your phone number or email. Aadhaar verification and a face scan run through Digio after you consent. HOMIZI stores the result, the time, the Digio request id, and the last 4 digits. It does not store the full Aadhaar number, the document, or the face image. The verified state is written by the server, not by the phone.',
        ),
        LegalSection(
          heading: 'Listings, requirements, and photos',
          body:
              'A requirement stores a city, a locality, a budget, occupancy, and a move-in date. It does not ask for gender, religion, caste, age, or a street address. A listing stores a title, city, locality, rent, deposit, furnishing, property type, and photos you choose from the gallery. The app does not open the camera. With Supabase connected, photos go to a private listing-photos bucket. In demo mode they stay on the device. The app does not request precise GPS and does not read an advertising id.',
        ),
        LegalSection(
          heading: 'Matches, chat, and contact',
          body:
              'The app stores likes, passes, saves, matches, chat messages, and visit times. Chat refuses a phone number or an email address. A visit is a time, not a street address. You can share your own phone or email for one match. The other person sees it only when the server says it is visible. A block hides contact. In-app notices store ids only. A push device token is stored only when a Firebase project is compiled into the build. Without that config, the app does not register a push device token.',
        ),
        LegalSection(
          heading: 'Product analytics',
          body:
              'There is no third-party analytics SDK. When a Supabase project is connected, the app can write an event to that same database: app_open, listing_view, interest_sent, match_opened, or message_sent, plus your account id and at most a listing id or a match id. Phone numbers, email addresses, and names are dropped. The Settings switch starts on. Turn product analytics off in Settings to stop new events for that session. The choice is not saved as an account setting in this build. Demo mode does not send those events to a server.',
        ),
        LegalSection(
          heading: 'Crash reports',
          body:
              'sentry_flutter is a dependency, and Sentry stays off unless the build was compiled with a SENTRY_DSN. That DSN is not in this repository, so the builds produced without it do not send crashes. When a DSN is present, the app turns off default personal data and strips the user record before a send. Rent payments can open a Razorpay test checkout when a test key is compiled in. Live keys are refused. Demo mode does not collect money. The app does not include an advertising SDK.',
        ),
        LegalSection(
          heading: 'Deletion and retention',
          body:
              'No retention period is approved. Until you delete the account, rows stay in the connected database. Deletion steps are on the Delete account page. Deletion does not call a payment provider, an identity vendor, or a backup system. A production backup is not part of this delete.',
        ),
      ],
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Terms',
      intro:
          'These draft terms describe how this build of HOMIZI behaves. They are not a finished contract. No liability cap, governing law, or venue is stated here.',
      sections: [
        LegalSection(
          heading: 'Using HOMIZI',
          body:
              'HOMIZI helps you look for a rental or a flatmate. An account can be a tenant, a host, or both. You are responsible for what you put in a profile, a requirement, a listing, a photo, and a chat message. Do not upload a photo you do not have the right to share. Do not put a phone number, an email address, or a street address in chat.',
        ),
        LegalSection(
          heading: 'Matches and contact',
          body:
              'A like can become a mutual match. A pass does not undo a match that already exists. Contact details stay hidden until the other person has shared them for that match. You can stop sharing your own contact. A block stops messages and contact in both directions.',
        ),
        LegalSection(
          heading: 'What this build is not',
          body:
              'Aadhaar and a face scan are verified by Digio after you consent. HOMIZI does not store the full Aadhaar number or a document. Rent and deposits on a listing are descriptions. A test-mode payment can be simulated, and that path does not collect money. It is not a staffed moderation promise. A report is stored, a block is enforced, and a staff account can review the queue. Nobody is named as the moderator in this build. Push stays off until Firebase is compiled in. Notices stay in the in-app inbox.',
        ),
        LegalSection(
          heading: 'Demo mode and ending an account',
          body:
              'When no project URL and public key are set, the app keeps data on the device. Deleting an account from Settings removes the signed-in account on the device, or on the connected database when Supabase is configured. The limits of that delete are on the Delete account page. Those limits are part of this draft.',
        ),
      ],
    );
  }
}

class SupportSafetyPage extends StatelessWidget {
  const SupportSafetyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Support and safety',
      intro:
          'Support for this build is the project owner. This draft does not name a public support mailbox. In-app notices are for matches, messages, and visits. They are not a support inbox.',
      sections: [
        LegalSection(
          heading: 'Safety',
          body:
              'Do not share a sign-in code. Do not move money before you have seen the home through a channel you trust. A test-mode payment does not collect money. Chat refuses a phone number or an email address. Share contact only with the match control, and only your own contact. A visit request is a time, not a street address.',
        ),
        LegalSection(
          heading: 'Report and block',
          body:
              'Open a listing or a chat and use the flag icon. The report is stored for your account. Blocking is recorded with it and stops messages and contact in both directions. A staff account can hide a listing or suspend an account. No phone number or email is shown on that queue. No person is named as the moderator in this build.',
        ),
        LegalSection(
          heading: 'Account and privacy',
          body:
              'Sign-in on the staging project uses email. Hosted SMS is off. Product analytics can be turned off in Settings. Sentry stays off unless the build was compiled with a SENTRY_DSN. To remove an account, follow the Delete account page. Identity checks are mocked. The app does not collect Aadhaar or a face scan.',
        ),
      ],
    );
  }
}

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Delete account',
      intro:
          'You can delete the signed-in HOMIZI account from the app. The same Settings control is in the Android app and in this web app. This draft describes what that control does today.',
      sections: [
        LegalSection(
          heading: 'Steps',
          body:
              '1. Open HOMIZI and sign in. 2. Open Settings. 3. Tap Delete account. 4. Read the note and tick the box that says you understand it cannot be undone here. 5. Tap Delete account again. 6. The app then signs you out. If you cannot sign in, this draft has no separate mailbox yet. Contact the project owner who operates the account.',
        ),
        LegalSection(
          heading: 'What is removed',
          body:
              'On a build connected to Supabase, the app removes your listing photos from the private listing-photos bucket and calls delete_own_account. That database function deletes the signed-in auth user and the related rows it covers, including listings, matches, reports, and interests. The app then tells you the profile, listings, messages, and private contact row are gone. In demo mode, with no project connected, deletion clears the account on this device only and does not update a server.',
        ),
        LegalSection(
          heading: 'What this delete does not do',
          body:
              'It does not call a payment provider or an identity vendor. It does not restore or purge a production backup. Sentry stays off unless the build was compiled with a SENTRY_DSN, and this delete does not call Sentry. No retention job runs afterwards. Those limits stay until a reviewed deletion program exists.',
        ),
      ],
    );
  }
}
