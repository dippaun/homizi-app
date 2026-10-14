import 'package:flutter/material.dart';
import 'package:homizi/l10n/hi_lookup.dart';

/// English copy stays the source string. Hindi replaces it when the locale is `hi`.
String homiziText(BuildContext context, String english) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode;
  if (code != 'hi') {
    return english;
  }
  return hindiOf(english);
}

/// Lookup used by [homiziText] and by tests that do not need a widget tree.
String hindiOf(String english) {
  final exact = hiByEnglish[english];
  if (exact != null) {
    return exact;
  }
  if (english.startsWith('• ')) {
    return '• ${hindiOf(english.substring(2))}';
  }

  final bhk = RegExp(r'^(\d+) BHK$').firstMatch(english);
  if (bhk != null) {
    return '${bhk.group(1)} बीएचके';
  }

  final deposit = RegExp(r'^Deposit (₹[\d,]+)$').firstMatch(english);
  if (deposit != null) {
    return 'जमा ${deposit.group(1)}';
  }

  final perMonth = RegExp(r'^(₹[\d,]+) / month$').firstMatch(english);
  if (perMonth != null) {
    return '${perMonth.group(1)} / महीना';
  }

  final perMo = RegExp(r'^(₹[\d,]+)/mo$').firstMatch(english);
  if (perMo != null) {
    return '${perMo.group(1)}/माह';
  }

  final showing = RegExp(r'^Showing (\d+) of (\d+)$').firstMatch(english);
  if (showing != null) {
    return '${showing.group(2)} में से ${showing.group(1)} दिख रहे हैं';
  }

  final cityOk = RegExp(r'^City matches (.+)\.$').firstMatch(english);
  if (cityOk != null) {
    return 'शहर मेल खाता है: ${hindiOf(cityOk.group(1)!)}।';
  }
  final cityNo = RegExp(r'^City does not match (.+)\.$').firstMatch(english);
  if (cityNo != null) {
    return 'शहर मेल नहीं खाता: ${hindiOf(cityNo.group(1)!)}।';
  }
  final locOk = RegExp(r'^Locality matches (.+)\.$').firstMatch(english);
  if (locOk != null) {
    return 'इलाका मेल खाता है: ${hindiOf(locOk.group(1)!)}।';
  }
  final locNo = RegExp(r'^Locality does not match (.+)\.$').firstMatch(english);
  if (locNo != null) {
    return 'इलाका मेल नहीं खाता: ${hindiOf(locNo.group(1)!)}।';
  }

  final resend = RegExp(r'^Resend in (\d+)s$').firstMatch(english);
  if (resend != null) {
    return '${resend.group(1)} सेकंड में फिर भेजें';
  }

  final photos = RegExp(r'^(\d+) photos$').firstMatch(english);
  if (photos != null) {
    return '${photos.group(1)} फ़ोटो';
  }

  final onDevice = RegExp(
    r'^(\d+) on this device\. Publish needs 3, with one marked primary\.$',
  ).firstMatch(english);
  if (onDevice != null) {
    return 'इस डिवाइस पर ${onDevice.group(1)} फ़ोटो हैं। प्रकाशित करने के लिए 3 चाहिए, और एक प्राथमिक हो।';
  }

  final stillNeeded = RegExp(
    r'^Add at least 3 photos before publish\. (\d+) still needed\.$',
  ).firstMatch(english);
  if (stillNeeded != null) {
    return 'प्रकाशित करने से पहले कम से कम 3 फ़ोटो जोड़ें। अभी ${stillNeeded.group(1)} और चाहिए।';
  }

  final hostSaved = RegExp(
    r'^Host profile saved as (.+)\. No badge is shown, and contact details stay private\.$',
  ).firstMatch(english);
  if (hostSaved != null) {
    return 'होस्ट प्रोफ़ाइल ${hindiOf(hostSaved.group(1)!)} के रूप में सहेजी गई। कोई बैज नहीं दिखता, और संपर्क विवरण निजी रहते हैं।';
  }

  final devCode = RegExp(
    r'^Development code: (\d+)\. It is shown only in dev and staging, and it is never logged\.$',
  ).firstMatch(english);
  if (devCode != null) {
    return 'डेवलपमेंट कोड: ${devCode.group(1)}। यह केवल डेव और स्टेजिंग में दिखता है, और इसे कभी लॉग नहीं किया जाता।';
  }

  final shareTheirs = RegExp(
    r'^You are sharing your (.+) for this match\. Their contact still appears only if they share theirs\.$',
  ).firstMatch(english);
  if (shareTheirs != null) {
    return 'आप इस मैच के लिए अपना ${hindiOf(shareTheirs.group(1)!)} साझा कर रहे हैं। उनका संपर्क तभी दिखेगा जब वे अपना साझा करें।';
  }

  final marked = RegExp(
    r'^Marked on this device: (.+)\. Nothing was sent\.$',
  ).firstMatch(english);
  if (marked != null) {
    return 'इस डिवाइस पर चिह्नित: ${hindiOf(marked.group(1)!)}। कुछ नहीं भेजा गया।';
  }

  final sharingDetails = RegExp(
    r'^You are sharing (.+) for this match\. The details stay on the server\.$',
  ).firstMatch(english);
  if (sharingDetails != null) {
    return 'आप इस मैच के लिए ${hindiOf(sharingDetails.group(1)!)} साझा कर रहे हैं। विवरण सर्वर पर रहते हैं।';
  }

  final draftSaved = RegExp(r'^Saved as a draft\. (.+)$').firstMatch(english);
  if (draftSaved != null) {
    return 'ड्राफ्ट के रूप में सहेजा गया। ${hindiOf(draftSaved.group(1)!)}';
  }

  final cannotChange = RegExp(
    r'^This form cannot change (.+)\.$',
  ).firstMatch(english);
  if (cannotChange != null) {
    return 'यह फ़ॉर्म ${cannotChange.group(1)} नहीं बदल सकता।';
  }

  final agree = RegExp(
    r'^I agree to the HOMIZI terms and privacy notice \(draft (.+)\)\.$',
  ).firstMatch(english);
  if (agree != null) {
    return 'मैं HOMIZI की शर्तों और गोपनीयता सूचना (मसौदा ${agree.group(1)}) से सहमत हूँ।';
  }

  final fit = RegExp(
    r'^Fit with a sample Bengaluru budget: (\d+)/100$',
  ).firstMatch(english);
  if (fit != null) {
    return 'नमूना बेंगलुरु बजट से मेल: ${fit.group(1)}/100';
  }

  final ceiling = RegExp(r'^Budget ceiling · (.+)$').firstMatch(english);
  if (ceiling != null) {
    return 'बजट की ऊपरी सीमा · ${hindiOf(ceiling.group(1)!)}';
  }

  final people = RegExp(r'^₹(.+) to ₹(.+) · (\d+) people$').firstMatch(english);
  if (people != null) {
    return '₹${people.group(1)} से ₹${people.group(2)} · ${people.group(3)} लोग';
  }

  final rentLine = RegExp(r'^(.+) · (₹[\d,]+)/mo$').firstMatch(english);
  if (rentLine != null) {
    return '${hindiOf(rentLine.group(1)!)} · ${rentLine.group(2)}/माह';
  }

  final visit = RegExp(
    r'^(\d+) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec), (\d{2}:\d{2})$',
  ).firstMatch(english);
  if (visit != null) {
    const months = {
      'Jan': 'जनवरी',
      'Feb': 'फ़रवरी',
      'Mar': 'मार्च',
      'Apr': 'अप्रैल',
      'May': 'मई',
      'Jun': 'जून',
      'Jul': 'जुलाई',
      'Aug': 'अगस्त',
      'Sep': 'सितंबर',
      'Oct': 'अक्टूबर',
      'Nov': 'नवंबर',
      'Dec': 'दिसंबर',
    };
    return '${visit.group(1)} ${months[visit.group(2)]}, ${visit.group(3)}';
  }

  final triple = english.split(' · ');
  if (triple.length == 3 &&
      hiByEnglish.containsKey(triple[0]) &&
      hiByEnglish.containsKey(triple[1]) &&
      hiByEnglish.containsKey(triple[2])) {
    return '${hindiOf(triple[0])} · ${hindiOf(triple[1])} · ${hindiOf(triple[2])}';
  }

  final comma = english.split(', ');
  if (comma.length == 2 &&
      hiByEnglish.containsKey(comma[0]) &&
      hiByEnglish.containsKey(comma[1])) {
    return '${hindiOf(comma[0])}, ${hindiOf(comma[1])}';
  }

  final envLine = RegExp(
    r'^(.+) · (Supabase configured|demo mode, no project connected)$',
  ).firstMatch(english);
  if (envLine != null) {
    return '${envLine.group(1)} · ${hindiOf(envLine.group(2)!)}';
  }

  final reporting = RegExp(r'^You are reporting (.+)\.$').firstMatch(english);
  if (reporting != null) {
    return 'आप ${hindiOf(reporting.group(1)!)} की रिपोर्ट कर रहे हैं।';
  }

  return english;
}
