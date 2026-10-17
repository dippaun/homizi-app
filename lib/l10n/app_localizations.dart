import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageHint.
  ///
  /// In en, this message translates to:
  /// **'English and Hindi cover the buttons, help, and messages in this app. Demo home titles follow the same language.'**
  String get languageHint;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @previewState.
  ///
  /// In en, this message translates to:
  /// **'Preview state'**
  String get previewState;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @guides.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get guides;

  /// No description provided for @safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @pass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get pass;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @like2.
  ///
  /// In en, this message translates to:
  /// **'LIKE'**
  String get like2;

  /// No description provided for @pass2.
  ///
  /// In en, this message translates to:
  /// **'PASS'**
  String get pass2;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @tenant.
  ///
  /// In en, this message translates to:
  /// **'Tenant'**
  String get tenant;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get both;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @broker.
  ///
  /// In en, this message translates to:
  /// **'Broker'**
  String get broker;

  /// No description provided for @company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get company;

  /// No description provided for @flatmate.
  ///
  /// In en, this message translates to:
  /// **'Flatmate'**
  String get flatmate;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @place.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get place;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @household.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get household;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @rent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get rent;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @locality.
  ///
  /// In en, this message translates to:
  /// **'Locality'**
  String get locality;

  /// No description provided for @furnishing.
  ///
  /// In en, this message translates to:
  /// **'Furnishing'**
  String get furnishing;

  /// No description provided for @apartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get apartment;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @primary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primary;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @declined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @rescheduled.
  ///
  /// In en, this message translates to:
  /// **'Rescheduled'**
  String get rescheduled;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phone2.
  ///
  /// In en, this message translates to:
  /// **'phone'**
  String get phone2;

  /// No description provided for @email2.
  ///
  /// In en, this message translates to:
  /// **'email'**
  String get email2;

  /// No description provided for @phoneAndEmail.
  ///
  /// In en, this message translates to:
  /// **'phone and email'**
  String get phoneAndEmail;

  /// No description provided for @yourPhone.
  ///
  /// In en, this message translates to:
  /// **'your phone'**
  String get yourPhone;

  /// No description provided for @yourEmail.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get yourEmail;

  /// No description provided for @yourPhoneAndEmail.
  ///
  /// In en, this message translates to:
  /// **'your phone and email'**
  String get yourPhoneAndEmail;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @removeSave.
  ///
  /// In en, this message translates to:
  /// **'Remove save'**
  String get removeSave;

  /// No description provided for @mcontinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get mcontinue;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @publishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing…'**
  String get publishing;

  /// No description provided for @interested.
  ///
  /// In en, this message translates to:
  /// **'Interested'**
  String get interested;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupation;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visits;

  /// No description provided for @listing.
  ///
  /// In en, this message translates to:
  /// **'Listing'**
  String get listing;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @notChosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen'**
  String get notChosen;

  /// No description provided for @tenantAndHost.
  ///
  /// In en, this message translates to:
  /// **'Tenant and host'**
  String get tenantAndHost;

  /// No description provided for @supabaseConfigured.
  ///
  /// In en, this message translates to:
  /// **'Supabase configured'**
  String get supabaseConfigured;

  /// No description provided for @demoModeNoProjectConnected.
  ///
  /// In en, this message translates to:
  /// **'demo mode, no project connected'**
  String get demoModeNoProjectConnected;

  /// No description provided for @localityNotSet.
  ///
  /// In en, this message translates to:
  /// **'locality not set'**
  String get localityNotSet;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @environment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environment;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get signedInAs;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @policyVersion.
  ///
  /// In en, this message translates to:
  /// **'Policy version'**
  String get policyVersion;

  /// No description provided for @notAccepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get notAccepted;

  /// No description provided for @yourRequirement.
  ///
  /// In en, this message translates to:
  /// **'Your requirement'**
  String get yourRequirement;

  /// No description provided for @createAListing.
  ///
  /// In en, this message translates to:
  /// **'Create a listing'**
  String get createAListing;

  /// No description provided for @helpAndSafety.
  ///
  /// In en, this message translates to:
  /// **'Help and safety'**
  String get helpAndSafety;

  /// No description provided for @showHomes.
  ///
  /// In en, this message translates to:
  /// **'Show homes'**
  String get showHomes;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @allFilters.
  ///
  /// In en, this message translates to:
  /// **'All filters'**
  String get allFilters;

  /// No description provided for @showMoreHomes.
  ///
  /// In en, this message translates to:
  /// **'Show more homes'**
  String get showMoreHomes;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @rentLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Rent, low to high'**
  String get rentLowToHigh;

  /// No description provided for @rentHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Rent, high to low'**
  String get rentHighToLow;

  /// No description provided for @searchLocalityOrHome.
  ///
  /// In en, this message translates to:
  /// **'Search locality or home'**
  String get searchLocalityOrHome;

  /// No description provided for @m1BHK.
  ///
  /// In en, this message translates to:
  /// **'1 BHK'**
  String get m1BHK;

  /// No description provided for @m2BHK.
  ///
  /// In en, this message translates to:
  /// **'2 BHK'**
  String get m2BHK;

  /// No description provided for @m3BHK.
  ///
  /// In en, this message translates to:
  /// **'3 BHK'**
  String get m3BHK;

  /// No description provided for @unfurnished.
  ///
  /// In en, this message translates to:
  /// **'Unfurnished'**
  String get unfurnished;

  /// No description provided for @semiFurnished.
  ///
  /// In en, this message translates to:
  /// **'Semi-furnished'**
  String get semiFurnished;

  /// No description provided for @furnished.
  ///
  /// In en, this message translates to:
  /// **'Furnished'**
  String get furnished;

  /// No description provided for @privateRoom.
  ///
  /// In en, this message translates to:
  /// **'Private room'**
  String get privateRoom;

  /// No description provided for @sharedRoom.
  ///
  /// In en, this message translates to:
  /// **'Shared room'**
  String get sharedRoom;

  /// No description provided for @studio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get studio;

  /// No description provided for @independentHouse.
  ///
  /// In en, this message translates to:
  /// **'Independent house'**
  String get independentHouse;

  /// No description provided for @villa.
  ///
  /// In en, this message translates to:
  /// **'Villa'**
  String get villa;

  /// No description provided for @pg.
  ///
  /// In en, this message translates to:
  /// **'PG'**
  String get pg;

  /// No description provided for @propertyType.
  ///
  /// In en, this message translates to:
  /// **'Property type'**
  String get propertyType;

  /// No description provided for @livingRoom.
  ///
  /// In en, this message translates to:
  /// **'Living room'**
  String get livingRoom;

  /// No description provided for @bedroom.
  ///
  /// In en, this message translates to:
  /// **'Bedroom'**
  String get bedroom;

  /// No description provided for @kitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get kitchen;

  /// No description provided for @bathroom.
  ///
  /// In en, this message translates to:
  /// **'Bathroom'**
  String get bathroom;

  /// No description provided for @exterior.
  ///
  /// In en, this message translates to:
  /// **'Exterior'**
  String get exterior;

  /// No description provided for @spam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get spam;

  /// No description provided for @harassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get harassment;

  /// No description provided for @scam.
  ///
  /// In en, this message translates to:
  /// **'Scam'**
  String get scam;

  /// No description provided for @fakeListing.
  ///
  /// In en, this message translates to:
  /// **'Fake listing'**
  String get fakeListing;

  /// No description provided for @inappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate'**
  String get inappropriate;

  /// No description provided for @aPerson.
  ///
  /// In en, this message translates to:
  /// **'a person'**
  String get aPerson;

  /// No description provided for @aListing.
  ///
  /// In en, this message translates to:
  /// **'a listing'**
  String get aListing;

  /// No description provided for @aRequirement.
  ///
  /// In en, this message translates to:
  /// **'a requirement'**
  String get aRequirement;

  /// No description provided for @aMessage.
  ///
  /// In en, this message translates to:
  /// **'a message'**
  String get aMessage;

  /// No description provided for @thisItem.
  ///
  /// In en, this message translates to:
  /// **'this item'**
  String get thisItem;

  /// No description provided for @fewerPeople.
  ///
  /// In en, this message translates to:
  /// **'Fewer people'**
  String get fewerPeople;

  /// No description provided for @morePeople.
  ///
  /// In en, this message translates to:
  /// **'More people'**
  String get morePeople;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @markRead.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get markRead;

  /// No description provided for @openChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get openChat;

  /// No description provided for @loadingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications…'**
  String get loadingNotifications;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @addEmptySlot.
  ///
  /// In en, this message translates to:
  /// **'Add empty slot'**
  String get addEmptySlot;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @setPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set primary'**
  String get setPrimary;

  /// No description provided for @noPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet.'**
  String get noPhotosYet;

  /// No description provided for @onThisDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get onThisDevice;

  /// No description provided for @storedPrivately.
  ///
  /// In en, this message translates to:
  /// **'Stored privately'**
  String get storedPrivately;

  /// No description provided for @emptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty slot'**
  String get emptySlot;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get pendingReview;

  /// No description provided for @thisBrowserCouldNotOpenThePhotoLibrary.
  ///
  /// In en, this message translates to:
  /// **'This browser could not open the photo library. Nothing was uploaded.'**
  String get thisBrowserCouldNotOpenThePhotoLibrary;

  /// No description provided for @useAJPEGPNGOrWebPPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use a JPEG, PNG, or WebP photo.'**
  String get useAJPEGPNGOrWebPPhoto;

  /// No description provided for @managePhotos.
  ///
  /// In en, this message translates to:
  /// **'Manage photos'**
  String get managePhotos;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get saveDraft;

  /// No description provided for @previewListing.
  ///
  /// In en, this message translates to:
  /// **'Preview listing'**
  String get previewListing;

  /// No description provided for @agreeAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get agreeAndContinue;

  /// No description provided for @whatYouNeed.
  ///
  /// In en, this message translates to:
  /// **'What you need'**
  String get whatYouNeed;

  /// No description provided for @chooseACity.
  ///
  /// In en, this message translates to:
  /// **'Choose a city'**
  String get chooseACity;

  /// No description provided for @chooseACity2.
  ///
  /// In en, this message translates to:
  /// **'Choose a city.'**
  String get chooseACity2;

  /// No description provided for @addAtLeastOneLocality.
  ///
  /// In en, this message translates to:
  /// **'Add at least one locality'**
  String get addAtLeastOneLocality;

  /// No description provided for @addAtLeastOneLocality2.
  ///
  /// In en, this message translates to:
  /// **'Add at least one locality.'**
  String get addAtLeastOneLocality2;

  /// No description provided for @chooseAMoveInDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a move-in date'**
  String get chooseAMoveInDate;

  /// No description provided for @koramangala.
  ///
  /// In en, this message translates to:
  /// **'Koramangala'**
  String get koramangala;

  /// No description provided for @thisDeviceIsOfflineHomesAlreadyOnThis.
  ///
  /// In en, this message translates to:
  /// **'This device is offline. Homes already on this phone stay here. Nothing was sent.'**
  String get thisDeviceIsOfflineHomesAlreadyOnThis;

  /// No description provided for @failedHostLookup.
  ///
  /// In en, this message translates to:
  /// **'Failed host lookup'**
  String get failedHostLookup;

  /// No description provided for @networkIsUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Network is unreachable'**
  String get networkIsUnreachable;

  /// No description provided for @connectionRefused.
  ///
  /// In en, this message translates to:
  /// **'Connection refused'**
  String get connectionRefused;

  /// No description provided for @connectionReset.
  ///
  /// In en, this message translates to:
  /// **'Connection reset'**
  String get connectionReset;

  /// No description provided for @softwareCausedConnectionAbort.
  ///
  /// In en, this message translates to:
  /// **'Software caused connection abort'**
  String get softwareCausedConnectionAbort;

  /// No description provided for @pageNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Page not available'**
  String get pageNotAvailable;

  /// No description provided for @unknownRoute.
  ///
  /// In en, this message translates to:
  /// **'Unknown route'**
  String get unknownRoute;

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get notStarted;

  /// No description provided for @mockPending.
  ///
  /// In en, this message translates to:
  /// **'Mock pending'**
  String get mockPending;

  /// No description provided for @mockVerified.
  ///
  /// In en, this message translates to:
  /// **'Mock verified'**
  String get mockVerified;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @mockCheckQueuedNoIdentityDocumentPhotoOr.
  ///
  /// In en, this message translates to:
  /// **'Mock check queued. No identity document, photo, or government ID was collected.'**
  String get mockCheckQueuedNoIdentityDocumentPhotoOr;

  /// No description provided for @howWillYouUseHOMIZI.
  ///
  /// In en, this message translates to:
  /// **'How will you use HOMIZI?'**
  String get howWillYouUseHOMIZI;

  /// No description provided for @oneAccountTwoWaysIn.
  ///
  /// In en, this message translates to:
  /// **'One account, two ways in.'**
  String get oneAccountTwoWaysIn;

  /// No description provided for @oneAccountCanBeATenantAHost.
  ///
  /// In en, this message translates to:
  /// **'One account can be a tenant, a host, or both. This is a product decision for the owner to confirm. When Supabase is configured, the choice is saved on your account.'**
  String get oneAccountCanBeATenantAHost;

  /// No description provided for @postWhatYouNeedAndDiscoverHomesOr.
  ///
  /// In en, this message translates to:
  /// **'Post what you need and discover homes or flatmates.'**
  String get postWhatYouNeedAndDiscoverHomesOr;

  /// No description provided for @listAHomeYouHaveAvailableBrokerOwner.
  ///
  /// In en, this message translates to:
  /// **'List a home you have available. Broker, owner, or flatmate.'**
  String get listAHomeYouHaveAvailableBrokerOwner;

  /// No description provided for @lookForAPlaceAndAlsoListA.
  ///
  /// In en, this message translates to:
  /// **'Look for a place and also list a room or a flat.'**
  String get lookForAPlaceAndAlsoListA;

  /// No description provided for @otpDeliveryIsNotConfiguredForProductionBuilds.
  ///
  /// In en, this message translates to:
  /// **'OTP delivery is not configured for production builds. No code was sent.'**
  String get otpDeliveryIsNotConfiguredForProductionBuilds;

  /// No description provided for @yourNumberStaysOnThisScreen.
  ///
  /// In en, this message translates to:
  /// **'Your number stays on this screen.'**
  String get yourNumberStaysOnThisScreen;

  /// No description provided for @useAnEmailOrAnIndianMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Use an email or an Indian mobile number. No SMS or email is sent. The development code opens a Supabase session with the local fixture password.'**
  String get useAnEmailOrAnIndianMobileNumber;

  /// No description provided for @useAnEmailOrAnIndianMobileNumber2.
  ///
  /// In en, this message translates to:
  /// **'Use an email or an Indian mobile number. No SMS or email is sent. This session stays on the device until Supabase is configured.'**
  String get useAnEmailOrAnIndianMobileNumber2;

  /// No description provided for @enterYourEmailStagingEmailsA6Digit.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. Staging emails a 6-digit code. Type that code below. If the email contains a link, opening it on this phone still signs you in. Phone SMS is not connected.'**
  String get enterYourEmailStagingEmailsA6Digit;

  /// No description provided for @enterYourEmailStagingEmailsA6Digit2.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. Staging emails a 6-digit code. Type that code in this browser. A link to in.homizi.app:// is not required. Phone SMS is not connected.'**
  String get enterYourEmailStagingEmailsA6Digit2;

  /// No description provided for @phoneSMSIsNotConnectedOnStagingEnter.
  ///
  /// In en, this message translates to:
  /// **'Phone SMS is not connected on staging. Enter an email address. No SMS was sent.'**
  String get phoneSMSIsNotConnectedOnStagingEnter;

  /// No description provided for @thatCodeWasNotAcceptedNoSessionWas.
  ///
  /// In en, this message translates to:
  /// **'That code was not accepted. No session was started.'**
  String get thatCodeWasNotAcceptedNoSessionWas;

  /// No description provided for @aSignInEmailIsSentOnlyFor.
  ///
  /// In en, this message translates to:
  /// **'A sign-in email is sent only for the staging project.'**
  String get aSignInEmailIsSentOnlyFor;

  /// No description provided for @aSignInEmailIsUsedOnlyFor.
  ///
  /// In en, this message translates to:
  /// **'A sign-in email is used only for staging with Supabase configured.'**
  String get aSignInEmailIsUsedOnlyFor;

  /// No description provided for @emailOrMobile.
  ///
  /// In en, this message translates to:
  /// **'Email or mobile'**
  String get emailOrMobile;

  /// No description provided for @youExampleTest.
  ///
  /// In en, this message translates to:
  /// **'you@example.test'**
  String get youExampleTest;

  /// No description provided for @sendSignInEmail.
  ///
  /// In en, this message translates to:
  /// **'Send sign-in email'**
  String get sendSignInEmail;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @enterThe6DigitCodeFromTheEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from the email.'**
  String get enterThe6DigitCodeFromTheEmail;

  /// No description provided for @enterThe6DigitCodeFromTheEmail2.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from the email. No session was started.'**
  String get enterThe6DigitCodeFromTheEmail2;

  /// No description provided for @thatCodeWasNotAcceptedCheckThe6.
  ///
  /// In en, this message translates to:
  /// **'That code was not accepted. Check the 6 digits from the email and try again. No session was started.'**
  String get thatCodeWasNotAcceptedCheckThe6;

  /// No description provided for @thatSignInWasNotAcceptedCheckThe.
  ///
  /// In en, this message translates to:
  /// **'That sign-in was not accepted. Check the email and code. No session was started.'**
  String get thatSignInWasNotAcceptedCheckThe;

  /// No description provided for @thatEmailAddressWasNotAcceptedCheckIt.
  ///
  /// In en, this message translates to:
  /// **'That email address was not accepted. Check it and try again. No message was sent.'**
  String get thatEmailAddressWasNotAcceptedCheckIt;

  /// No description provided for @theStagingTestLoginIsNotConfiguredIn.
  ///
  /// In en, this message translates to:
  /// **'The staging test login is not configured in this build. No session was started.'**
  String get theStagingTestLoginIsNotConfiguredIn;

  /// No description provided for @useDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Use demo mode'**
  String get useDemoMode;

  /// No description provided for @useStagingSignIn.
  ///
  /// In en, this message translates to:
  /// **'Use staging sign-in'**
  String get useStagingSignIn;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @atLeast8CharactersThePasswordIsNot.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters. The password is not logged.'**
  String get atLeast8CharactersThePasswordIsNot;

  /// No description provided for @signInWithPassword.
  ///
  /// In en, this message translates to:
  /// **'Sign in with password'**
  String get signInWithPassword;

  /// No description provided for @createAccountWithPassword.
  ///
  /// In en, this message translates to:
  /// **'Create account with password'**
  String get createAccountWithPassword;

  /// No description provided for @supabaseRateLimitTooManyEmailsWereSent.
  ///
  /// In en, this message translates to:
  /// **'Supabase rate limit: too many emails were sent. Wait a few minutes and try again. No new message was sent.'**
  String get supabaseRateLimitTooManyEmailsWereSent;

  /// No description provided for @supabaseRejectedTheRedirectAddInHomiziApp.
  ///
  /// In en, this message translates to:
  /// **'Supabase rejected the redirect. Add in.homizi.app://login-callback under Authentication, URL Configuration, Redirect URLs.'**
  String get supabaseRejectedTheRedirectAddInHomiziApp;

  /// No description provided for @emailNotConfirmedOpenTheConfirmationMessageThen.
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed. Open the confirmation message, then sign in again.'**
  String get emailNotConfirmedOpenTheConfirmationMessageThen;

  /// No description provided for @emailSignUpIsDisabledInTheSupabase.
  ///
  /// In en, this message translates to:
  /// **'Email sign-up is disabled in the Supabase dashboard. Turn the Email provider on.'**
  String get emailSignUpIsDisabledInTheSupabase;

  /// No description provided for @accountCreatedEmailNotConfirmedYetOpenThe.
  ///
  /// In en, this message translates to:
  /// **'Account created. Email not confirmed yet. Open the confirmation message, then sign in with the password.'**
  String get accountCreatedEmailNotConfirmedYetOpenThe;

  /// No description provided for @chooseAPasswordOfAtLeast8Characters.
  ///
  /// In en, this message translates to:
  /// **'Choose a password of at least 8 characters. It is not logged.'**
  String get chooseAPasswordOfAtLeast8Characters;

  /// No description provided for @thatPasswordIsReservedForLocalDevelopmentChoose.
  ///
  /// In en, this message translates to:
  /// **'That password is reserved for local development. Choose another. No account was changed.'**
  String get thatPasswordIsReservedForLocalDevelopmentChoose;

  /// No description provided for @passwordSignInIsOnlyForStagingWith.
  ///
  /// In en, this message translates to:
  /// **'Password sign-in is only for staging with the flag on.'**
  String get passwordSignInIsOnlyForStagingWith;

  /// No description provided for @thatPasswordWasNotAcceptedNoSessionWas.
  ///
  /// In en, this message translates to:
  /// **'That password was not accepted. No session was started.'**
  String get thatPasswordWasNotAcceptedNoSessionWas;

  /// No description provided for @m6DigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get m6DigitCode;

  /// No description provided for @checkingCode.
  ///
  /// In en, this message translates to:
  /// **'Checking code…'**
  String get checkingCode;

  /// No description provided for @verifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get verifyAndContinue;

  /// No description provided for @enterAValidEmailOrA10Digit.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email or a 10-digit Indian mobile number.'**
  String get enterAValidEmailOrA10Digit;

  /// No description provided for @acceptTheTermsAndPrivacyNoticeBeforeSigning.
  ///
  /// In en, this message translates to:
  /// **'Accept the terms and privacy notice before signing in.'**
  String get acceptTheTermsAndPrivacyNoticeBeforeSigning;

  /// No description provided for @theDevelopmentCodeIsRefusedInProductionSign.
  ///
  /// In en, this message translates to:
  /// **'The development code is refused in production. Sign-in is not connected to an OTP provider in this build.'**
  String get theDevelopmentCodeIsRefusedInProductionSign;

  /// No description provided for @thatCodeIsNotValidInDevelopmentUse.
  ///
  /// In en, this message translates to:
  /// **'That code is not valid. In development, use the code shown on this screen.'**
  String get thatCodeIsNotValidInDevelopmentUse;

  /// No description provided for @hostProfile.
  ///
  /// In en, this message translates to:
  /// **'Host profile'**
  String get hostProfile;

  /// No description provided for @loadingYourHostProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your host profile'**
  String get loadingYourHostProfile;

  /// No description provided for @noHostProfileYet.
  ///
  /// In en, this message translates to:
  /// **'No host profile yet'**
  String get noHostProfileYet;

  /// No description provided for @saveACategoryWhenYouAreReadyTo.
  ///
  /// In en, this message translates to:
  /// **'Save a category when you are ready to list a home.'**
  String get saveACategoryWhenYouAreReadyTo;

  /// No description provided for @hostProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Host profile unavailable'**
  String get hostProfileUnavailable;

  /// No description provided for @theHostProfileCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'The host profile could not be loaded.'**
  String get theHostProfileCouldNotBeLoaded;

  /// No description provided for @hostCategoryIsAClaimVerificationBadgesBelow.
  ///
  /// In en, this message translates to:
  /// **'Host category is a claim. Verification badges below are mock checks only. No identity document is collected. Contact details stay in the private contact record.'**
  String get hostCategoryIsAClaimVerificationBadgesBelow;

  /// No description provided for @hostCategory.
  ///
  /// In en, this message translates to:
  /// **'Host category'**
  String get hostCategory;

  /// No description provided for @companyNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Company name (optional)'**
  String get companyNameOptional;

  /// No description provided for @saveHostProfile.
  ///
  /// In en, this message translates to:
  /// **'Save host profile'**
  String get saveHostProfile;

  /// No description provided for @profileSavedContactDetailsWereNotPartOf.
  ///
  /// In en, this message translates to:
  /// **'Profile saved. Contact details were not part of this form.'**
  String get profileSavedContactDetailsWereNotPartOf;

  /// No description provided for @tenantProfile.
  ///
  /// In en, this message translates to:
  /// **'Tenant profile'**
  String get tenantProfile;

  /// No description provided for @loadingYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile'**
  String get loadingYourProfile;

  /// No description provided for @noProfileYet.
  ///
  /// In en, this message translates to:
  /// **'No profile yet'**
  String get noProfileYet;

  /// No description provided for @signInToCreateYourTenantProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create your tenant profile.'**
  String get signInToCreateYourTenantProfile;

  /// No description provided for @profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile unavailable'**
  String get profileUnavailable;

  /// No description provided for @theProfileCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'The profile could not be loaded.'**
  String get theProfileCouldNotBeLoaded;

  /// No description provided for @onlyFieldsAMatchNeedsDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Only fields a match needs. Date of birth and contact details are not on this form.'**
  String get onlyFieldsAMatchNeedsDateOfBirth;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @publicBio.
  ///
  /// In en, this message translates to:
  /// **'Public bio'**
  String get publicBio;

  /// No description provided for @verificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Verification status'**
  String get verificationStatus;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @startMockVerification.
  ///
  /// In en, this message translates to:
  /// **'Start mock verification'**
  String get startMockVerification;

  /// No description provided for @thisDoesNotCallAVerificationProviderAnd.
  ///
  /// In en, this message translates to:
  /// **'This does not call a verification provider and does not upload a document. The server only moves the status to mock pending.'**
  String get thisDoesNotCallAVerificationProviderAnd;

  /// No description provided for @shufflingHomes.
  ///
  /// In en, this message translates to:
  /// **'Shuffling homes…'**
  String get shufflingHomes;

  /// No description provided for @noHomesMatch.
  ///
  /// In en, this message translates to:
  /// **'No homes match'**
  String get noHomesMatch;

  /// No description provided for @nothingLeftToReview.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to review'**
  String get nothingLeftToReview;

  /// No description provided for @tryAWiderBudgetOrClearTheFilters.
  ///
  /// In en, this message translates to:
  /// **'Try a wider budget or clear the filters.'**
  String get tryAWiderBudgetOrClearTheFilters;

  /// No description provided for @publishedHomesShowUpHereAPassDoes.
  ///
  /// In en, this message translates to:
  /// **'Published homes show up here. A pass does not remove a match.'**
  String get publishedHomesShowUpHereAPassDoes;

  /// No description provided for @discoverIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Discover is unavailable'**
  String get discoverIsUnavailable;

  /// No description provided for @retryToSeeTheSampleDeckAgain.
  ///
  /// In en, this message translates to:
  /// **'Retry to see the sample deck again.'**
  String get retryToSeeTheSampleDeckAgain;

  /// No description provided for @youAreCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You are caught up'**
  String get youAreCaughtUp;

  /// No description provided for @likesAndPassesWereSentAnExistingMatch.
  ///
  /// In en, this message translates to:
  /// **'Likes and passes were sent. An existing match stays in place.'**
  String get likesAndPassesWereSentAnExistingMatch;

  /// No description provided for @checkingMutualInterest.
  ///
  /// In en, this message translates to:
  /// **'Checking mutual interest…'**
  String get checkingMutualInterest;

  /// No description provided for @noMutualMatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No mutual matches yet'**
  String get noMutualMatchesYet;

  /// No description provided for @aMatchIsCreatedOnlyWhenBothSides.
  ///
  /// In en, this message translates to:
  /// **'A match is created only when both sides like each other. Like the Koramangala demo home to see a sample card. Passing later does not remove it. Contact appears only when the server says it is visible.'**
  String get aMatchIsCreatedOnlyWhenBothSides;

  /// No description provided for @matchesDidNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Matches did not load'**
  String get matchesDidNotLoad;

  /// No description provided for @retryToReadMatchesFromTheServer.
  ///
  /// In en, this message translates to:
  /// **'Retry to read matches from the server.'**
  String get retryToReadMatchesFromTheServer;

  /// No description provided for @mutualMatch.
  ///
  /// In en, this message translates to:
  /// **'Mutual match'**
  String get mutualMatch;

  /// No description provided for @openingTheConversation.
  ///
  /// In en, this message translates to:
  /// **'Opening the conversation…'**
  String get openingTheConversation;

  /// No description provided for @messagesStayOnTheMatchPhoneNumbersAnd.
  ///
  /// In en, this message translates to:
  /// **'Messages stay on the match. Phone numbers and email addresses are refused. A visit time is not a street address.'**
  String get messagesStayOnTheMatchPhoneNumbersAnd;

  /// No description provided for @demoModeKeepsThisChatOnTheDevice.
  ///
  /// In en, this message translates to:
  /// **'Demo mode keeps this chat on the device. Nothing is sent, and contact details are still refused.'**
  String get demoModeKeepsThisChatOnTheDevice;

  /// No description provided for @noMessagesYetSayHelloWithoutAPhone.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello without a phone number or an email address.'**
  String get noMessagesYetSayHelloWithoutAPhone;

  /// No description provided for @writeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get writeAMessage;

  /// No description provided for @proposeATimeTheStreetAddressIsNot.
  ///
  /// In en, this message translates to:
  /// **'Propose a time. The street address is not part of this request.'**
  String get proposeATimeTheStreetAddressIsNot;

  /// No description provided for @noVisitRequestedYet.
  ///
  /// In en, this message translates to:
  /// **'No visit requested yet.'**
  String get noVisitRequestedYet;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// No description provided for @requestAVisit.
  ///
  /// In en, this message translates to:
  /// **'Request a visit'**
  String get requestAVisit;

  /// No description provided for @checkingYourSession.
  ///
  /// In en, this message translates to:
  /// **'Checking your session'**
  String get checkingYourSession;

  /// No description provided for @theStreetAddressStaysOffThisMapUntil.
  ///
  /// In en, this message translates to:
  /// **'The street address stays off this map until a visit is agreed.'**
  String get theStreetAddressStaysOffThisMapUntil;

  /// No description provided for @draftKeptOnThisDevicePhotoFilesStay.
  ///
  /// In en, this message translates to:
  /// **'Draft kept on this device. Photo files stay on this device, and nothing is uploaded.'**
  String get draftKeptOnThisDevicePhotoFilesStay;

  /// No description provided for @draftKeptOnThisDeviceTheServerDid.
  ///
  /// In en, this message translates to:
  /// **'Draft kept on this device. The server did not publish this listing.'**
  String get draftKeptOnThisDeviceTheServerDid;

  /// No description provided for @draftSavedEmptyPhotoSlotsAreRecordsOnly.
  ///
  /// In en, this message translates to:
  /// **'Draft saved. Empty photo slots are records only, and review stays pending.'**
  String get draftSavedEmptyPhotoSlotsAreRecordsOnly;

  /// No description provided for @draftSavedPhotosAreInThePrivateListing.
  ///
  /// In en, this message translates to:
  /// **'Draft saved. Photos are in the private listing-photos bucket under your account. Review stays pending.'**
  String get draftSavedPhotosAreInThePrivateListing;

  /// No description provided for @photoUploadWasRefusedTheListingPhotosPolicies.
  ///
  /// In en, this message translates to:
  /// **'Photo upload was refused. The listing-photos policies are not installed on this project yet.'**
  String get photoUploadWasRefusedTheListingPhotosPolicies;

  /// No description provided for @theListingPhotosBucketIsMissingOnThis.
  ///
  /// In en, this message translates to:
  /// **'The listing-photos bucket is missing on this project.'**
  String get theListingPhotosBucketIsMissingOnThis;

  /// No description provided for @thePhotoCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be saved.'**
  String get thePhotoCouldNotBeSaved;

  /// No description provided for @theServerPublishedThisListing.
  ///
  /// In en, this message translates to:
  /// **'The server published this listing.'**
  String get theServerPublishedThisListing;

  /// No description provided for @draftKeptOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Draft kept on this device.'**
  String get draftKeptOnThisDevice;

  /// No description provided for @draftKeptOnThisDeviceTheServerDid2.
  ///
  /// In en, this message translates to:
  /// **'Draft kept on this device. The server did not publish this requirement.'**
  String get draftKeptOnThisDeviceTheServerDid2;

  /// No description provided for @draftSavedOnTheServer.
  ///
  /// In en, this message translates to:
  /// **'Draft saved on the server.'**
  String get draftSavedOnTheServer;

  /// No description provided for @theServerPublishedThisRequirement.
  ///
  /// In en, this message translates to:
  /// **'The server published this requirement.'**
  String get theServerPublishedThisRequirement;

  /// No description provided for @signInBeforePublishing.
  ///
  /// In en, this message translates to:
  /// **'Sign in before publishing.'**
  String get signInBeforePublishing;

  /// No description provided for @youCanOnlyPublishYourOwnListing.
  ///
  /// In en, this message translates to:
  /// **'You can only publish your own listing.'**
  String get youCanOnlyPublishYourOwnListing;

  /// No description provided for @youCanOnlyPublishYourOwnRequirement.
  ///
  /// In en, this message translates to:
  /// **'You can only publish your own requirement.'**
  String get youCanOnlyPublishYourOwnRequirement;

  /// No description provided for @theServerRejectedThisAsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The server rejected this as incomplete.'**
  String get theServerRejectedThisAsIncomplete;

  /// No description provided for @theServerNeedsAtLeast3PhotoSlots.
  ///
  /// In en, this message translates to:
  /// **'The server needs at least 3 photo slots before publish.'**
  String get theServerNeedsAtLeast3PhotoSlots;

  /// No description provided for @theServerDidNotPublishThis.
  ///
  /// In en, this message translates to:
  /// **'The server did not publish this.'**
  String get theServerDidNotPublishThis;

  /// No description provided for @photoPathsStayUnderYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Photo paths stay under your account.'**
  String get photoPathsStayUnderYourAccount;

  /// No description provided for @signInBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Sign in before saving.'**
  String get signInBeforeSaving;

  /// No description provided for @theListingRequestFailedContactDetailsStayOn.
  ///
  /// In en, this message translates to:
  /// **'The listing request failed. Contact details stay on the server.'**
  String get theListingRequestFailedContactDetailsStayOn;

  /// No description provided for @theServerResponseWasNotReadable.
  ///
  /// In en, this message translates to:
  /// **'The server response was not readable.'**
  String get theServerResponseWasNotReadable;

  /// No description provided for @minimumOf3PhotosIsMet.
  ///
  /// In en, this message translates to:
  /// **'Minimum of 3 photos is met.'**
  String get minimumOf3PhotosIsMet;

  /// No description provided for @filesGoIntoThePrivateListingPhotosBucket.
  ///
  /// In en, this message translates to:
  /// **'Files go into the private listing-photos bucket, under your account only. Review stays pending. A listing card still shows locality, not a street address or a phone number.'**
  String get filesGoIntoThePrivateListingPhotosBucket;

  /// No description provided for @demoModeKeepsPhotoFilesOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Demo mode keeps photo files on this device. Nothing is uploaded until a project URL and public key are set.'**
  String get demoModeKeepsPhotoFilesOnThisDevice;

  /// No description provided for @propertyListing.
  ///
  /// In en, this message translates to:
  /// **'Property listing'**
  String get propertyListing;

  /// No description provided for @saveStoresADraftPublishIsASeparate.
  ///
  /// In en, this message translates to:
  /// **'Save stores a draft. Publish is a separate server check. This form cannot set listing status, verification, or payments.'**
  String get saveStoresADraftPublishIsASeparate;

  /// No description provided for @monthlyRent.
  ///
  /// In en, this message translates to:
  /// **'Monthly rent (₹)'**
  String get monthlyRent;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit (₹)'**
  String get deposit;

  /// No description provided for @noPhotosYetAddAtLeast3Before.
  ///
  /// In en, this message translates to:
  /// **'No photos yet. Add at least 3 before publish.'**
  String get noPhotosYetAddAtLeast3Before;

  /// No description provided for @untitledHome.
  ///
  /// In en, this message translates to:
  /// **'Untitled home'**
  String get untitledHome;

  /// No description provided for @rentNotSet.
  ///
  /// In en, this message translates to:
  /// **'Rent not set'**
  String get rentNotSet;

  /// No description provided for @othersWouldSeeTheLocalityNotAStreet.
  ///
  /// In en, this message translates to:
  /// **'Others would see the locality, not a street address. Contact details are not part of this preview.'**
  String get othersWouldSeeTheLocalityNotAStreet;

  /// No description provided for @localChecksPassedTheServerStillHasTo.
  ///
  /// In en, this message translates to:
  /// **'Local checks passed. The server still has to accept publish.'**
  String get localChecksPassedTheServerStillHasTo;

  /// No description provided for @publishStaysOffUntilTheseAreFixed.
  ///
  /// In en, this message translates to:
  /// **'Publish stays off until these are fixed:'**
  String get publishStaysOffUntilTheseAreFixed;

  /// No description provided for @addATitleOfAtLeast3Characters.
  ///
  /// In en, this message translates to:
  /// **'Add a title of at least 3 characters.'**
  String get addATitleOfAtLeast3Characters;

  /// No description provided for @keepTheTitleTo120CharactersOrFewer.
  ///
  /// In en, this message translates to:
  /// **'Keep the title to 120 characters or fewer.'**
  String get keepTheTitleTo120CharactersOrFewer;

  /// No description provided for @addALocality.
  ///
  /// In en, this message translates to:
  /// **'Add a locality.'**
  String get addALocality;

  /// No description provided for @enterAMonthlyRentInRupees.
  ///
  /// In en, this message translates to:
  /// **'Enter a monthly rent in rupees.'**
  String get enterAMonthlyRentInRupees;

  /// No description provided for @enterADepositInRupeesOrLeaveIt.
  ///
  /// In en, this message translates to:
  /// **'Enter a deposit in rupees, or leave it blank.'**
  String get enterADepositInRupeesOrLeaveIt;

  /// No description provided for @addAtLeast3Photos.
  ///
  /// In en, this message translates to:
  /// **'Add at least 3 photos.'**
  String get addAtLeast3Photos;

  /// No description provided for @markAPrimaryPhoto.
  ///
  /// In en, this message translates to:
  /// **'Mark a primary photo.'**
  String get markAPrimaryPhoto;

  /// No description provided for @supportForThisFoundationBuildIsTheProject.
  ///
  /// In en, this message translates to:
  /// **'Support for this foundation build is the project owner. In-app notifications are for matches, messages, and visits. They are not a support inbox.'**
  String get supportForThisFoundationBuildIsTheProject;

  /// No description provided for @whenCanSomeoneSeeMyPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'When can someone see my phone number?'**
  String get whenCanSomeoneSeeMyPhoneNumber;

  /// No description provided for @onlyAfterAMutualMatchAndOnlyFor.
  ///
  /// In en, this message translates to:
  /// **'Only after a mutual match, and only for the part you share. Share and stop sharing call grant_contact_consent and revoke_contact_consent. The app shows a phone or email only when get_contact_visibility returns one.'**
  String get onlyAfterAMutualMatchAndOnlyFor;

  /// No description provided for @isIdentityVerificationReal.
  ///
  /// In en, this message translates to:
  /// **'Is identity verification real?'**
  String get isIdentityVerificationReal;

  /// No description provided for @noTheAppExposesAMockInterfaceIt.
  ///
  /// In en, this message translates to:
  /// **'No. The app exposes a mock interface. It does not collect Aadhaar, passport, or a face scan. A provider needs legal approval before any real check.'**
  String get noTheAppExposesAMockInterfaceIt;

  /// No description provided for @canISendMyPhoneNumberInChat.
  ///
  /// In en, this message translates to:
  /// **'Can I send my phone number in chat?'**
  String get canISendMyPhoneNumberInChat;

  /// No description provided for @noChatRefusesAPhoneNumberOrAn.
  ///
  /// In en, this message translates to:
  /// **'No. Chat refuses a phone number or an email address, on the server and in demo mode. Share contact only with the match control, which still does not put those details in the thread. A visit request is a time, not a street address.'**
  String get noChatRefusesAPhoneNumberOrAn;

  /// No description provided for @whatCanANotificationInclude.
  ///
  /// In en, this message translates to:
  /// **'What can a notification include?'**
  String get whatCanANotificationInclude;

  /// No description provided for @aMatchAMessageOrAVisitThe.
  ///
  /// In en, this message translates to:
  /// **'A match, a message, or a visit. The row stores ids only. It never includes a phone number, an email address, or a street address. Marking one read updates that timestamp and nothing else.'**
  String get aMatchAMessageOrAVisitThe;

  /// No description provided for @canIPayForAListingHere.
  ///
  /// In en, this message translates to:
  /// **'Can I pay for a listing here?'**
  String get canIPayForAListingHere;

  /// No description provided for @paymentsAreDeferredThereIsNoCheckoutAnd.
  ///
  /// In en, this message translates to:
  /// **'Payments are deferred. There is no checkout, and the client cannot mark a plan as paid.'**
  String get paymentsAreDeferredThereIsNoCheckoutAnd;

  /// No description provided for @howDoIReportSomeone.
  ///
  /// In en, this message translates to:
  /// **'How do I report someone?'**
  String get howDoIReportSomeone;

  /// No description provided for @openAListingOrAChatAndUse.
  ///
  /// In en, this message translates to:
  /// **'Open a listing or a chat and use the flag icon. The report is stored for your account. Blocking is recorded with it and stops messages and contact in both directions. A staff account can review the report. No one is named as moderator in this build.'**
  String get openAListingOrAChatAndUse;

  /// No description provided for @howDoIDeleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'How do I delete my account?'**
  String get howDoIDeleteMyAccount;

  /// No description provided for @settingsHasDeleteAccountOnThisDeviceIt.
  ///
  /// In en, this message translates to:
  /// **'Settings has Delete account. On this device it clears the local profile. With the local server connected it removes the auth user, profile, listings, photos, messages, and the private contact row. It does not call a payment provider, an identity provider, or a production backup.'**
  String get settingsHasDeleteAccountOnThisDeviceIt;

  /// No description provided for @safetyDoNotShareAnOTPAndDo.
  ///
  /// In en, this message translates to:
  /// **'Safety: do not share an OTP, and do not move money before you have met or verified the home through a channel you trust.'**
  String get safetyDoNotShareAnOTPAndDo;

  /// No description provided for @choosePhoneEmailOrBoth.
  ///
  /// In en, this message translates to:
  /// **'Choose phone, email, or both.'**
  String get choosePhoneEmailOrBoth;

  /// No description provided for @thatMatchIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'That match is not available.'**
  String get thatMatchIsNotAvailable;

  /// No description provided for @thatListingIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'That listing is not available.'**
  String get thatListingIsNotAvailable;

  /// No description provided for @thatListingIsNotPublished.
  ///
  /// In en, this message translates to:
  /// **'That listing is not published.'**
  String get thatListingIsNotPublished;

  /// No description provided for @youCannotLikeYourOwnListing.
  ///
  /// In en, this message translates to:
  /// **'You cannot like your own listing.'**
  String get youCannotLikeYourOwnListing;

  /// No description provided for @thisPersonIsBlocked.
  ///
  /// In en, this message translates to:
  /// **'This person is blocked.'**
  String get thisPersonIsBlocked;

  /// No description provided for @tooManyActionsTryAgainInALittle.
  ///
  /// In en, this message translates to:
  /// **'Too many actions. Try again in a little while.'**
  String get tooManyActionsTryAgainInALittle;

  /// No description provided for @theServerDidNotRecordThatAction.
  ///
  /// In en, this message translates to:
  /// **'The server did not record that action.'**
  String get theServerDidNotRecordThatAction;

  /// No description provided for @signInBeforeSharingContact.
  ///
  /// In en, this message translates to:
  /// **'Sign in before sharing contact.'**
  String get signInBeforeSharingContact;

  /// No description provided for @youCanOnlyShareContactOnAnActive.
  ///
  /// In en, this message translates to:
  /// **'You can only share contact on an active match.'**
  String get youCanOnlyShareContactOnAnActive;

  /// No description provided for @theServerDidNotUpdateYourContactShare.
  ///
  /// In en, this message translates to:
  /// **'The server did not update your contact share.'**
  String get theServerDidNotUpdateYourContactShare;

  /// No description provided for @signInBeforeBrowsingHomes.
  ///
  /// In en, this message translates to:
  /// **'Sign in before browsing homes.'**
  String get signInBeforeBrowsingHomes;

  /// No description provided for @theDiscoveryRequestFailedContactDetailsStayOn.
  ///
  /// In en, this message translates to:
  /// **'The discovery request failed. Contact details stay on the server.'**
  String get theDiscoveryRequestFailedContactDetailsStayOn;

  /// No description provided for @contactStaysHiddenBecauseOneOfYouBlocked.
  ///
  /// In en, this message translates to:
  /// **'Contact stays hidden because one of you blocked the other.'**
  String get contactStaysHiddenBecauseOneOfYouBlocked;

  /// No description provided for @contactStaysHiddenThisMatchIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Contact stays hidden. This match is not available to you.'**
  String get contactStaysHiddenThisMatchIsNotAvailable;

  /// No description provided for @contactStaysHiddenTheMatchIsNotActive.
  ///
  /// In en, this message translates to:
  /// **'Contact stays hidden. The match is not active.'**
  String get contactStaysHiddenTheMatchIsNotActive;

  /// No description provided for @contactStaysHiddenUntilYouSignIn.
  ///
  /// In en, this message translates to:
  /// **'Contact stays hidden until you sign in.'**
  String get contactStaysHiddenUntilYouSignIn;

  /// No description provided for @youMatchedContactStaysHiddenUntilTheyShare.
  ///
  /// In en, this message translates to:
  /// **'You matched. Contact stays hidden until they share theirs. This screen does not hold a phone number or an email address.'**
  String get youMatchedContactStaysHiddenUntilTheyShare;

  /// No description provided for @contactStaysHiddenUntilYouBothMatchAnd.
  ///
  /// In en, this message translates to:
  /// **'Contact stays hidden until you both match and they consent. This screen does not hold a phone number or an email address.'**
  String get contactStaysHiddenUntilYouBothMatchAnd;

  /// No description provided for @youMatchedContactStaysHiddenUntilTheyShare2.
  ///
  /// In en, this message translates to:
  /// **'You matched. Contact stays hidden until they share theirs.'**
  String get youMatchedContactStaysHiddenUntilTheyShare2;

  /// No description provided for @likeKeptOnThisDeviceTheServerDid.
  ///
  /// In en, this message translates to:
  /// **'Like kept on this device. The server did not record it.'**
  String get likeKeptOnThisDeviceTheServerDid;

  /// No description provided for @demoMatchOnlyTheServerDidNotShare.
  ///
  /// In en, this message translates to:
  /// **'Demo match only. The server did not share a phone or an email.'**
  String get demoMatchOnlyTheServerDidNotShare;

  /// No description provided for @passKeptOnThisDeviceAnExistingMatch.
  ///
  /// In en, this message translates to:
  /// **'Pass kept on this device. An existing match stays in place.'**
  String get passKeptOnThisDeviceAnExistingMatch;

  /// No description provided for @savedOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device.'**
  String get savedOnThisDevice;

  /// No description provided for @removedOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Removed on this device.'**
  String get removedOnThisDevice;

  /// No description provided for @likeSavedAMatchAppearsWhenTheyLike.
  ///
  /// In en, this message translates to:
  /// **'Like saved. A match appears when they like you back.'**
  String get likeSavedAMatchAppearsWhenTheyLike;

  /// No description provided for @passSavedAnExistingMatchStaysInPlace.
  ///
  /// In en, this message translates to:
  /// **'Pass saved. An existing match stays in place.'**
  String get passSavedAnExistingMatchStaysInPlace;

  /// No description provided for @savedOnTheServer.
  ///
  /// In en, this message translates to:
  /// **'Saved on the server.'**
  String get savedOnTheServer;

  /// No description provided for @thisSaveStaysOnTheServer.
  ///
  /// In en, this message translates to:
  /// **'This save stays on the server.'**
  String get thisSaveStaysOnTheServer;

  /// No description provided for @keptOnThisDeviceTheServerDidNot.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device. The server did not share your contact.'**
  String get keptOnThisDeviceTheServerDidNot;

  /// No description provided for @stoppedOnThisDeviceTheServerWasNot.
  ///
  /// In en, this message translates to:
  /// **'Stopped on this device. The server was not asked.'**
  String get stoppedOnThisDeviceTheServerWasNot;

  /// No description provided for @youStoppedSharingYourContactForThisMatch.
  ///
  /// In en, this message translates to:
  /// **'You stopped sharing your contact for this match.'**
  String get youStoppedSharingYourContactForThisMatch;

  /// No description provided for @youHaveNotSharedYourContactDemoMode.
  ///
  /// In en, this message translates to:
  /// **'You have not shared your contact. Demo mode does not send it.'**
  String get youHaveNotSharedYourContactDemoMode;

  /// No description provided for @youHaveNotSharedYourContactForThis.
  ///
  /// In en, this message translates to:
  /// **'You have not shared your contact for this match.'**
  String get youHaveNotSharedYourContactForThis;

  /// No description provided for @shareYourOwnContactThisDoesNotReveal.
  ///
  /// In en, this message translates to:
  /// **'Share your own contact. This does not reveal theirs.'**
  String get shareYourOwnContactThisDoesNotReveal;

  /// No description provided for @updateWhatIShare.
  ///
  /// In en, this message translates to:
  /// **'Update what I share'**
  String get updateWhatIShare;

  /// No description provided for @shareMyContact.
  ///
  /// In en, this message translates to:
  /// **'Share my contact'**
  String get shareMyContact;

  /// No description provided for @stopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get stopSharing;

  /// No description provided for @previewScopeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Preview scope is required.'**
  String get previewScopeIsRequired;

  /// No description provided for @sharedForThisMatch.
  ///
  /// In en, this message translates to:
  /// **'Shared for this match.'**
  String get sharedForThisMatch;

  /// No description provided for @narrowTheDeckGenderReligionCasteAndAge.
  ///
  /// In en, this message translates to:
  /// **'Narrow the deck. Gender, religion, caste, and age are not filters.'**
  String get narrowTheDeckGenderReligionCasteAndAge;

  /// No description provided for @openingTheListing.
  ///
  /// In en, this message translates to:
  /// **'Opening the listing…'**
  String get openingTheListing;

  /// No description provided for @thatListingIsNotInThePublishedFeed.
  ///
  /// In en, this message translates to:
  /// **'That listing is not in the published feed.'**
  String get thatListingIsNotInThePublishedFeed;

  /// No description provided for @identityCheckInThisBuildIsAMock.
  ///
  /// In en, this message translates to:
  /// **'Identity check in this build is a mock. No Aadhaar number or face scan is collected.'**
  String get identityCheckInThisBuildIsAMock;

  /// No description provided for @lookingForPublishedHomes.
  ///
  /// In en, this message translates to:
  /// **'Looking for published homes…'**
  String get lookingForPublishedHomes;

  /// No description provided for @publishedListingsWillShowUpHere.
  ///
  /// In en, this message translates to:
  /// **'Published listings will show up here.'**
  String get publishedListingsWillShowUpHere;

  /// No description provided for @couldNotLoadHomes.
  ///
  /// In en, this message translates to:
  /// **'Could not load homes'**
  String get couldNotLoadHomes;

  /// No description provided for @theDemoFeedFailedOnPurposeRetryReturns.
  ///
  /// In en, this message translates to:
  /// **'The demo feed failed on purpose. Retry returns to the sample listings.'**
  String get theDemoFeedFailedOnPurposeRetryReturns;

  /// No description provided for @findAHomeWithoutTheNoise.
  ///
  /// In en, this message translates to:
  /// **'Find a home without the noise.'**
  String get findAHomeWithoutTheNoise;

  /// No description provided for @findAHomeOrAFlatmateWithContact.
  ///
  /// In en, this message translates to:
  /// **'Find a home, or a flatmate, with contact details that stay hidden until you both agree.'**
  String get findAHomeOrAFlatmateWithContact;

  /// No description provided for @profilesWithAVerificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Profiles with a verification status'**
  String get profilesWithAVerificationStatus;

  /// No description provided for @identityChecksAreMockedInThisBuildNo.
  ///
  /// In en, this message translates to:
  /// **'Identity checks are mocked in this build. No Aadhaar number or face scan is collected.'**
  String get identityChecksAreMockedInThisBuildNo;

  /// No description provided for @listingsAndRequirements.
  ///
  /// In en, this message translates to:
  /// **'Listings and requirements'**
  String get listingsAndRequirements;

  /// No description provided for @tenantsDescribeWhatTheyNeedHostsPublishA.
  ///
  /// In en, this message translates to:
  /// **'Tenants describe what they need. Hosts publish a home with rent, deposit, and photos.'**
  String get tenantsDescribeWhatTheyNeedHostsPublishA;

  /// No description provided for @aServerSideContactGate.
  ///
  /// In en, this message translates to:
  /// **'A server-side contact gate'**
  String get aServerSideContactGate;

  /// No description provided for @aPhoneOrEmailIsReturnedOnlyAfter.
  ///
  /// In en, this message translates to:
  /// **'A phone or email is returned only after a mutual match and explicit consent.'**
  String get aPhoneOrEmailIsReturnedOnlyAfter;

  /// No description provided for @legalTextIsNotApprovedYetDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Legal text is not approved yet. Demo mode keeps the acceptance in this session. With Supabase configured, the draft version is stored on your account after you sign in.'**
  String get legalTextIsNotApprovedYetDemoMode;

  /// No description provided for @deleteThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete this account?'**
  String get deleteThisAccount;

  /// No description provided for @thisRemovesTheProfileListingsPhotosMessagesAnd.
  ///
  /// In en, this message translates to:
  /// **'This removes the profile, listings, photos, messages, and contact row on this device, or on the connected local server. It does not call a payment provider, an identity provider, or a production backup.'**
  String get thisRemovesTheProfileListingsPhotosMessagesAnd;

  /// No description provided for @iUnderstandThisCannotBeUndoneHere.
  ///
  /// In en, this message translates to:
  /// **'I understand this cannot be undone here.'**
  String get iUnderstandThisCannotBeUndoneHere;

  /// No description provided for @matchesMessagesAndVisitsNoPhoneEmailOr.
  ///
  /// In en, this message translates to:
  /// **'Matches, messages, and visits. No phone, email, or street address.'**
  String get matchesMessagesAndVisitsNoPhoneEmailOr;

  /// No description provided for @matchAlertsOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Match alerts on this device'**
  String get matchAlertsOnThisDevice;

  /// No description provided for @pushDeliveryIsNotConnectedThisPreferenceStays.
  ///
  /// In en, this message translates to:
  /// **'Push delivery is not connected. This preference stays on this screen.'**
  String get pushDeliveryIsNotConnectedThisPreferenceStays;

  /// No description provided for @removesThisAccountOnTheDeviceOrThe.
  ///
  /// In en, this message translates to:
  /// **'Removes this account on the device or the connected local server. Production backups and vendors are not included.'**
  String get removesThisAccountOnTheDeviceOrThe;

  /// No description provided for @theAccountWasNotDeletedContactDetailsStay.
  ///
  /// In en, this message translates to:
  /// **'The account was not deleted. Contact details stay on the server.'**
  String get theAccountWasNotDeletedContactDetailsStay;

  /// No description provided for @deletedOnThisServerProfileListingsMessagesAnd.
  ///
  /// In en, this message translates to:
  /// **'Deleted on this server. Profile, listings, messages, and the private contact row are gone. A production backup is not part of this delete.'**
  String get deletedOnThisServerProfileListingsMessagesAnd;

  /// No description provided for @yourProfileRowIsMissingSignOutAnd.
  ///
  /// In en, this message translates to:
  /// **'Your profile row is missing. Sign out and try the development code again.'**
  String get yourProfileRowIsMissingSignOutAnd;

  /// No description provided for @supabaseDidNotStartASessionEmailConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Supabase did not start a session. Email confirmation is on, so this build stopped. No message was sent.'**
  String get supabaseDidNotStartASessionEmailConfirmation;

  /// No description provided for @thatEmailIsAlreadyRegisteredAndTheDevelopment.
  ///
  /// In en, this message translates to:
  /// **'That email is already registered, and the development password did not match. No account was changed.'**
  String get thatEmailIsAlreadyRegisteredAndTheDevelopment;

  /// No description provided for @thePhoneCouldNotBeStoredOnYour.
  ///
  /// In en, this message translates to:
  /// **'The phone could not be stored on your private contact record. Sign-in was cancelled.'**
  String get thePhoneCouldNotBeStoredOnYour;

  /// No description provided for @signInBeforeUpdatingYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in before updating your account.'**
  String get signInBeforeUpdatingYourAccount;

  /// No description provided for @signInFailedNoCodeWasSent.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. No code was sent.'**
  String get signInFailedNoCodeWasSent;

  /// No description provided for @theAccountRequestFailedContactDetailsStayOn.
  ///
  /// In en, this message translates to:
  /// **'The account request failed. Contact details stay on the server.'**
  String get theAccountRequestFailedContactDetailsStayOn;

  /// No description provided for @theAccountResponseWasNotReadableContactDetails.
  ///
  /// In en, this message translates to:
  /// **'The account response was not readable. Contact details were not shown.'**
  String get theAccountResponseWasNotReadableContactDetails;

  /// No description provided for @deletedOnThisDeviceTheServerWasNot.
  ///
  /// In en, this message translates to:
  /// **'Deleted on this device. The server was not updated.'**
  String get deletedOnThisDeviceTheServerWasNot;

  /// No description provided for @keptOnThisDeviceTheServerWasNot.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device. The server was not updated.'**
  String get keptOnThisDeviceTheServerWasNot;

  /// No description provided for @markedRead.
  ///
  /// In en, this message translates to:
  /// **'Marked read.'**
  String get markedRead;

  /// No description provided for @noNotificationsYetALikeMatchMessageOr.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet. A like, match, message, or visit will show up here.'**
  String get noNotificationsYetALikeMatchMessageOr;

  /// No description provided for @aNotificationNeverIncludesAPhoneNumberAn.
  ///
  /// In en, this message translates to:
  /// **'A notification never includes a phone number, an email address, or a street address.'**
  String get aNotificationNeverIncludesAPhoneNumberAn;

  /// No description provided for @somethingChangedOnAMatch.
  ///
  /// In en, this message translates to:
  /// **'Something changed on a match.'**
  String get somethingChangedOnAMatch;

  /// No description provided for @youHaveANewMatch.
  ///
  /// In en, this message translates to:
  /// **'You have a new match.'**
  String get youHaveANewMatch;

  /// No description provided for @someoneLikedAListing.
  ///
  /// In en, this message translates to:
  /// **'Someone liked a listing.'**
  String get someoneLikedAListing;

  /// No description provided for @viewListing.
  ///
  /// In en, this message translates to:
  /// **'View listing'**
  String get viewListing;

  /// No description provided for @newMessageOnAMatch.
  ///
  /// In en, this message translates to:
  /// **'New message on a match.'**
  String get newMessageOnAMatch;

  /// No description provided for @someoneRequestedAVisit.
  ///
  /// In en, this message translates to:
  /// **'Someone requested a visit.'**
  String get someoneRequestedAVisit;

  /// No description provided for @aVisitWasAccepted.
  ///
  /// In en, this message translates to:
  /// **'A visit was accepted.'**
  String get aVisitWasAccepted;

  /// No description provided for @aVisitWasDeclined.
  ///
  /// In en, this message translates to:
  /// **'A visit was declined.'**
  String get aVisitWasDeclined;

  /// No description provided for @aVisitWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'A visit was cancelled.'**
  String get aVisitWasCancelled;

  /// No description provided for @thatNotificationIsNotOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'That notification is not on this device.'**
  String get thatNotificationIsNotOnThisDevice;

  /// No description provided for @thisMessageWasHiddenBecauseItIncludedContact.
  ///
  /// In en, this message translates to:
  /// **'This message was hidden because it included contact details.'**
  String get thisMessageWasHiddenBecauseItIncludedContact;

  /// No description provided for @chooseOneToThreeVisitTimes.
  ///
  /// In en, this message translates to:
  /// **'Choose one to three visit times.'**
  String get chooseOneToThreeVisitTimes;

  /// No description provided for @removeThePhoneNumberOrEmailBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Remove the phone number or email before sending. Chat cannot carry contact details.'**
  String get removeThePhoneNumberOrEmailBeforeSending;

  /// No description provided for @writeAMessageOf1To4000Characters.
  ///
  /// In en, this message translates to:
  /// **'Write a message of 1 to 4000 characters, without contact details.'**
  String get writeAMessageOf1To4000Characters;

  /// No description provided for @signInBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Sign in before continuing.'**
  String get signInBeforeContinuing;

  /// No description provided for @chatAndVisitsAreOnlyAvailableOnAn.
  ///
  /// In en, this message translates to:
  /// **'Chat and visits are only available on an active match.'**
  String get chatAndVisitsAreOnlyAvailableOnAn;

  /// No description provided for @chatIsClosedBecauseOneOfYouBlocked.
  ///
  /// In en, this message translates to:
  /// **'Chat is closed because one of you blocked the other.'**
  String get chatIsClosedBecauseOneOfYouBlocked;

  /// No description provided for @chooseOneToThreeVisitTimesDoNot.
  ///
  /// In en, this message translates to:
  /// **'Choose one to three visit times. Do not include an address or a phone number.'**
  String get chooseOneToThreeVisitTimesDoNot;

  /// No description provided for @youCannotSetThatVisitStatus.
  ///
  /// In en, this message translates to:
  /// **'You cannot set that visit status.'**
  String get youCannotSetThatVisitStatus;

  /// No description provided for @thisVisitRequestIsAlreadyDecided.
  ///
  /// In en, this message translates to:
  /// **'This visit request is already decided.'**
  String get thisVisitRequestIsAlreadyDecided;

  /// No description provided for @theServerDidNotSaveThat.
  ///
  /// In en, this message translates to:
  /// **'The server did not save that.'**
  String get theServerDidNotSaveThat;

  /// No description provided for @keptOnThisDeviceTheServerDidNot2.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device. The server did not store this.'**
  String get keptOnThisDeviceTheServerDidNot2;

  /// No description provided for @messageSentContactDetailsStayOutOfChat.
  ///
  /// In en, this message translates to:
  /// **'Message sent. Contact details stay out of chat.'**
  String get messageSentContactDetailsStayOutOfChat;

  /// No description provided for @visitRequestedTheStreetAddressIsNotPart.
  ///
  /// In en, this message translates to:
  /// **'Visit requested. The street address is not part of this request.'**
  String get visitRequestedTheStreetAddressIsNotPart;

  /// No description provided for @visitUpdatedTheStreetAddressIsStillNot.
  ///
  /// In en, this message translates to:
  /// **'Visit updated. The street address is still not shown here.'**
  String get visitUpdatedTheStreetAddressIsStillNot;

  /// No description provided for @rentSitsInsideYourBudget.
  ///
  /// In en, this message translates to:
  /// **'Rent sits inside your budget.'**
  String get rentSitsInsideYourBudget;

  /// No description provided for @rentIsCloseToYourBudget.
  ///
  /// In en, this message translates to:
  /// **'Rent is close to your budget.'**
  String get rentIsCloseToYourBudget;

  /// No description provided for @rentIsOutsideYourBudget.
  ///
  /// In en, this message translates to:
  /// **'Rent is outside your budget.'**
  String get rentIsOutsideYourBudget;

  /// No description provided for @noLocalityPreferenceSet.
  ///
  /// In en, this message translates to:
  /// **'No locality preference set.'**
  String get noLocalityPreferenceSet;

  /// No description provided for @noFurnishingPreferenceSet.
  ///
  /// In en, this message translates to:
  /// **'No furnishing preference set.'**
  String get noFurnishingPreferenceSet;

  /// No description provided for @furnishingMatches.
  ///
  /// In en, this message translates to:
  /// **'Furnishing matches.'**
  String get furnishingMatches;

  /// No description provided for @furnishingDoesNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Furnishing does not match.'**
  String get furnishingDoesNotMatch;

  /// No description provided for @noPropertyTypePreferenceSet.
  ///
  /// In en, this message translates to:
  /// **'No property type preference set.'**
  String get noPropertyTypePreferenceSet;

  /// No description provided for @propertyTypeMatches.
  ///
  /// In en, this message translates to:
  /// **'Property type matches.'**
  String get propertyTypeMatches;

  /// No description provided for @propertyTypeDoesNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Property type does not match.'**
  String get propertyTypeDoesNotMatch;

  /// No description provided for @enterAMinimumBudget.
  ///
  /// In en, this message translates to:
  /// **'Enter a minimum budget.'**
  String get enterAMinimumBudget;

  /// No description provided for @enterAMaximumBudget.
  ///
  /// In en, this message translates to:
  /// **'Enter a maximum budget.'**
  String get enterAMaximumBudget;

  /// No description provided for @minimumBudgetCannotExceedTheMaximum.
  ///
  /// In en, this message translates to:
  /// **'Minimum budget cannot exceed the maximum.'**
  String get minimumBudgetCannotExceedTheMaximum;

  /// No description provided for @occupancyMustBeBetween1And20.
  ///
  /// In en, this message translates to:
  /// **'Occupancy must be between 1 and 20.'**
  String get occupancyMustBeBetween1And20;

  /// No description provided for @moveInDateCannotBeInThePast.
  ///
  /// In en, this message translates to:
  /// **'Move-in date cannot be in the past.'**
  String get moveInDateCannotBeInThePast;

  /// No description provided for @cityAndLocalityOnlyAStreetAddressIs.
  ///
  /// In en, this message translates to:
  /// **'City and locality only. A street address is not collected.'**
  String get cityAndLocalityOnlyAStreetAddressIs;

  /// No description provided for @minimumBudget.
  ///
  /// In en, this message translates to:
  /// **'Minimum budget (₹)'**
  String get minimumBudget;

  /// No description provided for @maximumBudget.
  ///
  /// In en, this message translates to:
  /// **'Maximum budget (₹)'**
  String get maximumBudget;

  /// No description provided for @occupancy.
  ///
  /// In en, this message translates to:
  /// **'Occupancy'**
  String get occupancy;

  /// No description provided for @occupancyIsAHeadcountGenderReligionCasteAnd.
  ///
  /// In en, this message translates to:
  /// **'Occupancy is a headcount. Gender, religion, caste, and age are not asked.'**
  String get occupancyIsAHeadcountGenderReligionCasteAnd;

  /// No description provided for @savingDoesNotPublishPublishKeepsTheRequirement.
  ///
  /// In en, this message translates to:
  /// **'Saving does not publish. Publish keeps the requirement on this device until a server accepts it.'**
  String get savingDoesNotPublishPublishKeepsTheRequirement;

  /// No description provided for @loadingSavedHomes.
  ///
  /// In en, this message translates to:
  /// **'Loading saved homes…'**
  String get loadingSavedHomes;

  /// No description provided for @noSavedHomes.
  ///
  /// In en, this message translates to:
  /// **'No saved homes'**
  String get noSavedHomes;

  /// No description provided for @bookmarkAListingFromExploreInDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Bookmark a listing from Explore. In demo mode the bookmark stays on this device. A server save cannot be deleted from this build.'**
  String get bookmarkAListingFromExploreInDemoMode;

  /// No description provided for @savedHomesDidNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Saved homes did not load'**
  String get savedHomesDidNotLoad;

  /// No description provided for @retryToLoadSavedHomes.
  ///
  /// In en, this message translates to:
  /// **'Retry to load saved homes.'**
  String get retryToLoadSavedHomes;

  /// No description provided for @thePersonYouReportIsNotToldWho.
  ///
  /// In en, this message translates to:
  /// **'The person you report is not told who filed it. A staff account can review the report. The report is stored for your account, without a phone number, an email address, or a street address.'**
  String get thePersonYouReportIsNotToldWho;

  /// No description provided for @detailsOptional.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get detailsOptional;

  /// No description provided for @doNotIncludeAPhoneNumberOrAn.
  ///
  /// In en, this message translates to:
  /// **'Do not include a phone number or an email address.'**
  String get doNotIncludeAPhoneNumberOrAn;

  /// No description provided for @alsoBlockThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Also block this account'**
  String get alsoBlockThisAccount;

  /// No description provided for @aBlockStopsNewInterestMessagesAndContact.
  ///
  /// In en, this message translates to:
  /// **'A block stops new interest, messages, and contact visibility in both directions.'**
  String get aBlockStopsNewInterestMessagesAndContact;

  /// No description provided for @thisReportHasNoAccountIdToBlock.
  ///
  /// In en, this message translates to:
  /// **'This report has no account id to block.'**
  String get thisReportHasNoAccountIdToBlock;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get submitReport;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @removeThePhoneNumberOrEmailBeforeSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Remove the phone number or email before submitting. A report cannot carry contact details.'**
  String get removeThePhoneNumberOrEmailBeforeSubmitting;

  /// No description provided for @thatReportCouldNotBeStored.
  ///
  /// In en, this message translates to:
  /// **'That report could not be stored.'**
  String get thatReportCouldNotBeStored;

  /// No description provided for @keptOnThisDeviceAndTheAccountIs.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device, and the account is blocked here. The server was not updated. Demo mode does not open the staff queue.'**
  String get keptOnThisDeviceAndTheAccountIs;

  /// No description provided for @keptOnThisDeviceTheServerWasNot2.
  ///
  /// In en, this message translates to:
  /// **'Kept on this device. The server was not updated. Demo mode does not open the staff queue.'**
  String get keptOnThisDeviceTheServerWasNot2;

  /// No description provided for @signInBeforeSendingAReport.
  ///
  /// In en, this message translates to:
  /// **'Sign in before sending a report.'**
  String get signInBeforeSendingAReport;

  /// No description provided for @thatReportNeedsAServerIdDemoListings.
  ///
  /// In en, this message translates to:
  /// **'That report needs a server id. Demo listings stay on the device.'**
  String get thatReportNeedsAServerIdDemoListings;

  /// No description provided for @aReportCannotChangeStatusOrCarryContact.
  ///
  /// In en, this message translates to:
  /// **'A report cannot change status or carry contact details.'**
  String get aReportCannotChangeStatusOrCarryContact;

  /// No description provided for @reportStoredAndTheAccountIsBlockedA.
  ///
  /// In en, this message translates to:
  /// **'Report stored, and the account is blocked. A staff account can review the report. No phone number or email is included.'**
  String get reportStoredAndTheAccountIsBlockedA;

  /// No description provided for @reportStoredAStaffAccountCanReviewThe.
  ///
  /// In en, this message translates to:
  /// **'Report stored. A staff account can review the report. No phone number or email is included.'**
  String get reportStoredAStaffAccountCanReviewThe;

  /// No description provided for @theReportWasNotStoredContactDetailsStay.
  ///
  /// In en, this message translates to:
  /// **'The report was not stored. Contact details stay on the server.'**
  String get theReportWasNotStoredContactDetailsStay;

  /// No description provided for @reportFieldsAreNotAcceptable.
  ///
  /// In en, this message translates to:
  /// **'Report fields are not acceptable.'**
  String get reportFieldsAreNotAcceptable;

  /// No description provided for @blockFieldsAreNotAcceptable.
  ///
  /// In en, this message translates to:
  /// **'Block fields are not acceptable.'**
  String get blockFieldsAreNotAcceptable;

  /// No description provided for @theNotificationRequestFailedContactDetailsStayOn.
  ///
  /// In en, this message translates to:
  /// **'The notification request failed. Contact details stay on the server.'**
  String get theNotificationRequestFailedContactDetailsStayOn;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @budgetCeilingAny.
  ///
  /// In en, this message translates to:
  /// **'Budget ceiling · Any'**
  String get budgetCeilingAny;

  /// No description provided for @bengaluru.
  ///
  /// In en, this message translates to:
  /// **'Bengaluru'**
  String get bengaluru;

  /// No description provided for @pune.
  ///
  /// In en, this message translates to:
  /// **'Pune'**
  String get pune;

  /// No description provided for @hyderabad.
  ///
  /// In en, this message translates to:
  /// **'Hyderabad'**
  String get hyderabad;

  /// No description provided for @mumbai.
  ///
  /// In en, this message translates to:
  /// **'Mumbai'**
  String get mumbai;

  /// No description provided for @delhiNCR.
  ///
  /// In en, this message translates to:
  /// **'Delhi NCR'**
  String get delhiNCR;

  /// No description provided for @andheriWest.
  ///
  /// In en, this message translates to:
  /// **'Andheri West'**
  String get andheriWest;

  /// No description provided for @aundh.
  ///
  /// In en, this message translates to:
  /// **'Aundh'**
  String get aundh;

  /// No description provided for @btmLayout.
  ///
  /// In en, this message translates to:
  /// **'BTM Layout'**
  String get btmLayout;

  /// No description provided for @bandraWest.
  ///
  /// In en, this message translates to:
  /// **'Bandra West'**
  String get bandraWest;

  /// No description provided for @baner.
  ///
  /// In en, this message translates to:
  /// **'Baner'**
  String get baner;

  /// No description provided for @banjaraHills.
  ///
  /// In en, this message translates to:
  /// **'Banjara Hills'**
  String get banjaraHills;

  /// No description provided for @bellandur.
  ///
  /// In en, this message translates to:
  /// **'Bellandur'**
  String get bellandur;

  /// No description provided for @chembur.
  ///
  /// In en, this message translates to:
  /// **'Chembur'**
  String get chembur;

  /// No description provided for @dwarka.
  ///
  /// In en, this message translates to:
  /// **'Dwarka'**
  String get dwarka;

  /// No description provided for @electronicCity.
  ///
  /// In en, this message translates to:
  /// **'Electronic City'**
  String get electronicCity;

  /// No description provided for @gachibowli.
  ///
  /// In en, this message translates to:
  /// **'Gachibowli'**
  String get gachibowli;

  /// No description provided for @goregaonEast.
  ///
  /// In en, this message translates to:
  /// **'Goregaon East'**
  String get goregaonEast;

  /// No description provided for @greaterNoida.
  ///
  /// In en, this message translates to:
  /// **'Greater Noida'**
  String get greaterNoida;

  /// No description provided for @gurugram.
  ///
  /// In en, this message translates to:
  /// **'Gurugram'**
  String get gurugram;

  /// No description provided for @hsrLayout.
  ///
  /// In en, this message translates to:
  /// **'HSR Layout'**
  String get hsrLayout;

  /// No description provided for @hebbal.
  ///
  /// In en, this message translates to:
  /// **'Hebbal'**
  String get hebbal;

  /// No description provided for @hinjewadi.
  ///
  /// In en, this message translates to:
  /// **'Hinjewadi'**
  String get hinjewadi;

  /// No description provided for @hitechCity.
  ///
  /// In en, this message translates to:
  /// **'Hitech City'**
  String get hitechCity;

  /// No description provided for @indiranagar.
  ///
  /// In en, this message translates to:
  /// **'Indiranagar'**
  String get indiranagar;

  /// No description provided for @indirapuram.
  ///
  /// In en, this message translates to:
  /// **'Indirapuram'**
  String get indirapuram;

  /// No description provided for @jpNagar.
  ///
  /// In en, this message translates to:
  /// **'JP Nagar'**
  String get jpNagar;

  /// No description provided for @jayanagar.
  ///
  /// In en, this message translates to:
  /// **'Jayanagar'**
  String get jayanagar;

  /// No description provided for @kharadi.
  ///
  /// In en, this message translates to:
  /// **'Kharadi'**
  String get kharadi;

  /// No description provided for @kondapur.
  ///
  /// In en, this message translates to:
  /// **'Kondapur'**
  String get kondapur;

  /// No description provided for @koregaonPark.
  ///
  /// In en, this message translates to:
  /// **'Koregaon Park'**
  String get koregaonPark;

  /// No description provided for @kothrud.
  ///
  /// In en, this message translates to:
  /// **'Kothrud'**
  String get kothrud;

  /// No description provided for @kukatpally.
  ///
  /// In en, this message translates to:
  /// **'Kukatpally'**
  String get kukatpally;

  /// No description provided for @madhapur.
  ///
  /// In en, this message translates to:
  /// **'Madhapur'**
  String get madhapur;

  /// No description provided for @maladWest.
  ///
  /// In en, this message translates to:
  /// **'Malad West'**
  String get maladWest;

  /// No description provided for @marathahalli.
  ///
  /// In en, this message translates to:
  /// **'Marathahalli'**
  String get marathahalli;

  /// No description provided for @mulund.
  ///
  /// In en, this message translates to:
  /// **'Mulund'**
  String get mulund;

  /// No description provided for @noidaSector62.
  ///
  /// In en, this message translates to:
  /// **'Noida Sector 62'**
  String get noidaSector62;

  /// No description provided for @powai.
  ///
  /// In en, this message translates to:
  /// **'Powai'**
  String get powai;

  /// No description provided for @saket.
  ///
  /// In en, this message translates to:
  /// **'Saket'**
  String get saket;

  /// No description provided for @thane.
  ///
  /// In en, this message translates to:
  /// **'Thane'**
  String get thane;

  /// No description provided for @vimanNagar.
  ///
  /// In en, this message translates to:
  /// **'Viman Nagar'**
  String get vimanNagar;

  /// No description provided for @wakad.
  ///
  /// In en, this message translates to:
  /// **'Wakad'**
  String get wakad;

  /// No description provided for @whitefield.
  ///
  /// In en, this message translates to:
  /// **'Whitefield'**
  String get whitefield;

  /// No description provided for @balcony.
  ///
  /// In en, this message translates to:
  /// **'Balcony'**
  String get balcony;

  /// No description provided for @cctv.
  ///
  /// In en, this message translates to:
  /// **'CCTV'**
  String get cctv;

  /// No description provided for @clubhouse.
  ///
  /// In en, this message translates to:
  /// **'Clubhouse'**
  String get clubhouse;

  /// No description provided for @coveredParking.
  ///
  /// In en, this message translates to:
  /// **'Covered parking'**
  String get coveredParking;

  /// No description provided for @gasPipeline.
  ///
  /// In en, this message translates to:
  /// **'Gas pipeline'**
  String get gasPipeline;

  /// No description provided for @gym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get gym;

  /// No description provided for @lift.
  ///
  /// In en, this message translates to:
  /// **'Lift'**
  String get lift;

  /// No description provided for @modularKitchen.
  ///
  /// In en, this message translates to:
  /// **'Modular kitchen'**
  String get modularKitchen;

  /// No description provided for @parking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get parking;

  /// No description provided for @pool.
  ///
  /// In en, this message translates to:
  /// **'Pool'**
  String get pool;

  /// No description provided for @powerBackup.
  ///
  /// In en, this message translates to:
  /// **'Power backup'**
  String get powerBackup;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @servantRoom.
  ///
  /// In en, this message translates to:
  /// **'Servant room'**
  String get servantRoom;

  /// No description provided for @twoBathrooms.
  ///
  /// In en, this message translates to:
  /// **'Two bathrooms'**
  String get twoBathrooms;

  /// No description provided for @wardrobes.
  ///
  /// In en, this message translates to:
  /// **'Wardrobes'**
  String get wardrobes;

  /// No description provided for @washingMachine.
  ///
  /// In en, this message translates to:
  /// **'Washing machine'**
  String get washingMachine;

  /// No description provided for @waterPurifier.
  ///
  /// In en, this message translates to:
  /// **'Water purifier'**
  String get waterPurifier;

  /// No description provided for @wifi.
  ///
  /// In en, this message translates to:
  /// **'Wifi'**
  String get wifi;

  /// No description provided for @accountant.
  ///
  /// In en, this message translates to:
  /// **'Accountant'**
  String get accountant;

  /// No description provided for @architect.
  ///
  /// In en, this message translates to:
  /// **'Architect'**
  String get architect;

  /// No description provided for @bankOfficer.
  ///
  /// In en, this message translates to:
  /// **'Bank officer'**
  String get bankOfficer;

  /// No description provided for @brandManager.
  ///
  /// In en, this message translates to:
  /// **'Brand manager'**
  String get brandManager;

  /// No description provided for @charteredAccountant.
  ///
  /// In en, this message translates to:
  /// **'Chartered accountant'**
  String get charteredAccountant;

  /// No description provided for @chef.
  ///
  /// In en, this message translates to:
  /// **'Chef'**
  String get chef;

  /// No description provided for @civilEngineer.
  ///
  /// In en, this message translates to:
  /// **'Civil engineer'**
  String get civilEngineer;

  /// No description provided for @civilServant.
  ///
  /// In en, this message translates to:
  /// **'Civil servant'**
  String get civilServant;

  /// No description provided for @clinicAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Clinic administrator'**
  String get clinicAdministrator;

  /// No description provided for @commercialPilot.
  ///
  /// In en, this message translates to:
  /// **'Commercial pilot'**
  String get commercialPilot;

  /// No description provided for @consultant.
  ///
  /// In en, this message translates to:
  /// **'Consultant'**
  String get consultant;

  /// No description provided for @contentLead.
  ///
  /// In en, this message translates to:
  /// **'Content lead'**
  String get contentLead;

  /// No description provided for @dataAnalyst.
  ///
  /// In en, this message translates to:
  /// **'Data analyst'**
  String get dataAnalyst;

  /// No description provided for @engineeringManager.
  ///
  /// In en, this message translates to:
  /// **'Engineering manager'**
  String get engineeringManager;

  /// No description provided for @filmEditor.
  ///
  /// In en, this message translates to:
  /// **'Film editor'**
  String get filmEditor;

  /// No description provided for @financeLead.
  ///
  /// In en, this message translates to:
  /// **'Finance lead'**
  String get financeLead;

  /// No description provided for @graduateStudent.
  ///
  /// In en, this message translates to:
  /// **'Graduate student'**
  String get graduateStudent;

  /// No description provided for @hrGeneralist.
  ///
  /// In en, this message translates to:
  /// **'HR generalist'**
  String get hrGeneralist;

  /// No description provided for @interiorDesigner.
  ///
  /// In en, this message translates to:
  /// **'Interior designer'**
  String get interiorDesigner;

  /// No description provided for @marketingLead.
  ///
  /// In en, this message translates to:
  /// **'Marketing lead'**
  String get marketingLead;

  /// No description provided for @nurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get nurse;

  /// No description provided for @operationsLead.
  ///
  /// In en, this message translates to:
  /// **'Operations lead'**
  String get operationsLead;

  /// No description provided for @pharmacist.
  ///
  /// In en, this message translates to:
  /// **'Pharmacist'**
  String get pharmacist;

  /// No description provided for @photographer.
  ///
  /// In en, this message translates to:
  /// **'Photographer'**
  String get photographer;

  /// No description provided for @productDesigner.
  ///
  /// In en, this message translates to:
  /// **'Product designer'**
  String get productDesigner;

  /// No description provided for @productManager.
  ///
  /// In en, this message translates to:
  /// **'Product manager'**
  String get productManager;

  /// No description provided for @qaEngineer.
  ///
  /// In en, this message translates to:
  /// **'QA engineer'**
  String get qaEngineer;

  /// No description provided for @researchAssistant.
  ///
  /// In en, this message translates to:
  /// **'Research assistant'**
  String get researchAssistant;

  /// No description provided for @schoolTeacher.
  ///
  /// In en, this message translates to:
  /// **'School teacher'**
  String get schoolTeacher;

  /// No description provided for @softwareEngineer.
  ///
  /// In en, this message translates to:
  /// **'Software engineer'**
  String get softwareEngineer;

  /// No description provided for @teacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacher;

  /// No description provided for @uxDesigner.
  ///
  /// In en, this message translates to:
  /// **'UX designer'**
  String get uxDesigner;

  /// No description provided for @uxResearcher.
  ///
  /// In en, this message translates to:
  /// **'UX researcher'**
  String get uxResearcher;

  /// No description provided for @sunlit2BHKInKoramangala.
  ///
  /// In en, this message translates to:
  /// **'Sunlit 2BHK in Koramangala'**
  String get sunlit2BHKInKoramangala;

  /// No description provided for @m2BHKNearHSRLayoutBDA.
  ///
  /// In en, this message translates to:
  /// **'2 BHK near HSR Layout BDA'**
  String get m2BHKNearHSRLayoutBDA;

  /// No description provided for @studioNearIndiranagarMetro.
  ///
  /// In en, this message translates to:
  /// **'Studio near Indiranagar metro'**
  String get studioNearIndiranagarMetro;

  /// No description provided for @privateRoomInBaner.
  ///
  /// In en, this message translates to:
  /// **'Private room in Baner'**
  String get privateRoomInBaner;

  /// No description provided for @furnished3BHKInKharadi.
  ///
  /// In en, this message translates to:
  /// **'Furnished 3 BHK in Kharadi'**
  String get furnished3BHKInKharadi;

  /// No description provided for @sharedRoomInKothrud.
  ///
  /// In en, this message translates to:
  /// **'Shared room in Kothrud'**
  String get sharedRoomInKothrud;

  /// No description provided for @m1BHKInAndheriWest.
  ///
  /// In en, this message translates to:
  /// **'1 BHK in Andheri West'**
  String get m1BHKInAndheriWest;

  /// No description provided for @m3BHKWithAPowaiView.
  ///
  /// In en, this message translates to:
  /// **'3 BHK with a Powai view'**
  String get m3BHKWithAPowaiView;

  /// No description provided for @m2BHKInGachibowli.
  ///
  /// In en, this message translates to:
  /// **'2 BHK in Gachibowli'**
  String get m2BHKInGachibowli;

  /// No description provided for @m3BHKInGurugram.
  ///
  /// In en, this message translates to:
  /// **'3 BHK in Gurugram'**
  String get m3BHKInGurugram;

  /// No description provided for @furnished2BHKInWhitefield.
  ///
  /// In en, this message translates to:
  /// **'Furnished 2BHK in Whitefield'**
  String get furnished2BHKInWhitefield;

  /// No description provided for @m3BHKNearJayanagar4thBlock.
  ///
  /// In en, this message translates to:
  /// **'3 BHK near Jayanagar 4th Block'**
  String get m3BHKNearJayanagar4thBlock;

  /// No description provided for @privateRoomInBellandur.
  ///
  /// In en, this message translates to:
  /// **'Private room in Bellandur'**
  String get privateRoomInBellandur;

  /// No description provided for @m1BHKInMarathahalli.
  ///
  /// In en, this message translates to:
  /// **'1 BHK in Marathahalli'**
  String get m1BHKInMarathahalli;

  /// No description provided for @unfurnished2BHKInJPNagar.
  ///
  /// In en, this message translates to:
  /// **'Unfurnished 2 BHK in JP Nagar'**
  String get unfurnished2BHKInJPNagar;

  /// No description provided for @studioNearHebbal.
  ///
  /// In en, this message translates to:
  /// **'Studio near Hebbal'**
  String get studioNearHebbal;

  /// No description provided for @sharedRoomInBTMLayout.
  ///
  /// In en, this message translates to:
  /// **'Shared room in BTM Layout'**
  String get sharedRoomInBTMLayout;

  /// No description provided for @m2BHKInElectronicCity.
  ///
  /// In en, this message translates to:
  /// **'2 BHK in Electronic City'**
  String get m2BHKInElectronicCity;

  /// No description provided for @furnished2BHKInVimanNagar.
  ///
  /// In en, this message translates to:
  /// **'Furnished 2 BHK in Viman Nagar'**
  String get furnished2BHKInVimanNagar;

  /// No description provided for @m1BHKInWakad.
  ///
  /// In en, this message translates to:
  /// **'1 BHK in Wakad'**
  String get m1BHKInWakad;

  /// No description provided for @privateRoomInHinjewadi.
  ///
  /// In en, this message translates to:
  /// **'Private room in Hinjewadi'**
  String get privateRoomInHinjewadi;

  /// No description provided for @m3BHKInKoregaonPark.
  ///
  /// In en, this message translates to:
  /// **'3 BHK in Koregaon Park'**
  String get m3BHKInKoregaonPark;

  /// No description provided for @semiFurnished2BHKInAundh.
  ///
  /// In en, this message translates to:
  /// **'Semi-furnished 2 BHK in Aundh'**
  String get semiFurnished2BHKInAundh;

  /// No description provided for @privateRoomInKothrud.
  ///
  /// In en, this message translates to:
  /// **'Private room in Kothrud'**
  String get privateRoomInKothrud;

  /// No description provided for @m2BHKInBandraWest.
  ///
  /// In en, this message translates to:
  /// **'2 BHK in Bandra West'**
  String get m2BHKInBandraWest;

  /// No description provided for @m1BHKInGoregaonEast.
  ///
  /// In en, this message translates to:
  /// **'1 BHK in Goregaon East'**
  String get m1BHKInGoregaonEast;

  /// No description provided for @unfurnished2BHKInChembur.
  ///
  /// In en, this message translates to:
  /// **'Unfurnished 2 BHK in Chembur'**
  String get unfurnished2BHKInChembur;

  /// No description provided for @m2BHKInThane.
  ///
  /// In en, this message translates to:
  /// **'2 BHK in Thane'**
  String get m2BHKInThane;

  /// No description provided for @privateRoomInMulund.
  ///
  /// In en, this message translates to:
  /// **'Private room in Mulund'**
  String get privateRoomInMulund;

  /// No description provided for @furnished1BHKInMaladWest.
  ///
  /// In en, this message translates to:
  /// **'Furnished 1 BHK in Malad West'**
  String get furnished1BHKInMaladWest;

  /// No description provided for @m2BHKInMadhapur.
  ///
  /// In en, this message translates to:
  /// **'2 BHK in Madhapur'**
  String get m2BHKInMadhapur;

  /// No description provided for @m3BHKInKondapur.
  ///
  /// In en, this message translates to:
  /// **'3 BHK in Kondapur'**
  String get m3BHKInKondapur;

  /// No description provided for @studioInHitechCity.
  ///
  /// In en, this message translates to:
  /// **'Studio in Hitech City'**
  String get studioInHitechCity;

  /// No description provided for @m3BHKInBanjaraHills.
  ///
  /// In en, this message translates to:
  /// **'3 BHK in Banjara Hills'**
  String get m3BHKInBanjaraHills;

  /// No description provided for @unfurnished2BHKInKukatpally.
  ///
  /// In en, this message translates to:
  /// **'Unfurnished 2 BHK in Kukatpally'**
  String get unfurnished2BHKInKukatpally;

  /// No description provided for @m2BHKInNoidaSector62.
  ///
  /// In en, this message translates to:
  /// **'2 BHK in Noida Sector 62'**
  String get m2BHKInNoidaSector62;

  /// No description provided for @m3BHKInDwarka.
  ///
  /// In en, this message translates to:
  /// **'3 BHK in Dwarka'**
  String get m3BHKInDwarka;

  /// No description provided for @furnished2BHKInSaket.
  ///
  /// In en, this message translates to:
  /// **'Furnished 2 BHK in Saket'**
  String get furnished2BHKInSaket;

  /// No description provided for @m1BHKInGreaterNoida.
  ///
  /// In en, this message translates to:
  /// **'1 BHK in Greater Noida'**
  String get m1BHKInGreaterNoida;

  /// No description provided for @privateRoomInIndirapuram.
  ///
  /// In en, this message translates to:
  /// **'Private room in Indirapuram'**
  String get privateRoomInIndirapuram;

  /// No description provided for @aFurnished2BHKWithMorningLightIn.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK with morning light in the living room and a balcony off the second bedroom. The exact address stays off this card.'**
  String get aFurnished2BHKWithMorningLightIn;

  /// No description provided for @semiFurnished2BHKInAQuietResidential.
  ///
  /// In en, this message translates to:
  /// **'Semi-furnished 2 BHK in a quiet residential block. One room is free for a working flatmate. Brokerage is zero in this demo.'**
  String get semiFurnished2BHKInAQuietResidential;

  /// No description provided for @aCompactFurnishedStudioForOnePersonA.
  ///
  /// In en, this message translates to:
  /// **'A compact furnished studio for one person, a short walk from the metro. Maintenance is separate from the rent shown here.'**
  String get aCompactFurnishedStudioForOnePersonA;

  /// No description provided for @aPrivateRoomInASharedFlatWith.
  ///
  /// In en, this message translates to:
  /// **'A private room in a shared flat with two bathrooms. Pets and smoking are the only lifestyle notes on this demo.'**
  String get aPrivateRoomInASharedFlatWith;

  /// No description provided for @aFurnished3BHKAimedAtASmall.
  ///
  /// In en, this message translates to:
  /// **'A furnished 3 BHK aimed at a small family or three working people. The society has a clubhouse. The street address is not published.'**
  String get aFurnished3BHKAimedAtASmall;

  /// No description provided for @anUnfurnishedSharedRoomAtALowerRent.
  ///
  /// In en, this message translates to:
  /// **'An unfurnished shared room at a lower rent, useful when a budget filter is tight. Bring your own mattress.'**
  String get anUnfurnishedSharedRoomAtALowerRent;

  /// No description provided for @aFurnished1BHKInAndheriWestSized.
  ///
  /// In en, this message translates to:
  /// **'A furnished 1 BHK in Andheri West, sized for one person or a couple. Deposit is higher, which is typical for this pocket.'**
  String get aFurnished1BHKInAndheriWestSized;

  /// No description provided for @aSemiFurnished3BHKInALarge.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 3 BHK in a large Powai complex. The rent is the asking rent. Contact stays behind the match gate.'**
  String get aSemiFurnished3BHKInALarge;

  /// No description provided for @aFurnished2BHKNearTheOfficeCorridor.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK near the office corridor in Gachibowli. Suitable for two people sharing. No brokerage in this demo.'**
  String get aFurnished2BHKNearTheOfficeCorridor;

  /// No description provided for @aSemiFurnished3BHKOnTheGurugram.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 3 BHK on the Gurugram side of Delhi NCR, with a servant room and two parking spots. The tower name stays private.'**
  String get aSemiFurnished3BHKOnTheGurugram;

  /// No description provided for @aFurnished2BHKInWhitefieldForTwo.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK in Whitefield for two working people. The society has a gym. The tower and street stay off this card.'**
  String get aFurnished2BHKInWhitefieldForTwo;

  /// No description provided for @aSemiFurnished3BHKInAResidential.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 3 BHK in a residential pocket of Jayanagar. One bedroom faces the balcony. Brokerage is zero in this demo.'**
  String get aSemiFurnished3BHKInAResidential;

  /// No description provided for @aPrivateRoomInASharedBellandurFlat.
  ///
  /// In en, this message translates to:
  /// **'A private room in a shared Bellandur flat, a short ride from the office parks. The other rooms are already occupied. No street address is shown.'**
  String get aPrivateRoomInASharedBellandurFlat;

  /// No description provided for @aFurnished1BHKSizedForOnePerson.
  ///
  /// In en, this message translates to:
  /// **'A furnished 1 BHK sized for one person, near the Marathahalli junction. Maintenance is separate from the rent shown here.'**
  String get aFurnished1BHKSizedForOnePerson;

  /// No description provided for @anUnfurnished2BHKInJPNagarBring.
  ///
  /// In en, this message translates to:
  /// **'An unfurnished 2 BHK in JP Nagar. Bring your own furniture. The exact address stays off this card.'**
  String get anUnfurnished2BHKInJPNagarBring;

  /// No description provided for @aCompactFurnishedStudioNearHebbalForOne.
  ///
  /// In en, this message translates to:
  /// **'A compact furnished studio near Hebbal for one person. A work desk is already in the room. Contact stays behind the match gate.'**
  String get aCompactFurnishedStudioNearHebbalForOne;

  /// No description provided for @anUnfurnishedSharedRoomInBTMLayoutAt.
  ///
  /// In en, this message translates to:
  /// **'An unfurnished shared room in BTM Layout at a lower rent. The kitchen is common. Bring your own mattress.'**
  String get anUnfurnishedSharedRoomInBTMLayoutAt;

  /// No description provided for @aSemiFurnished2BHKInElectronicCity.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 2 BHK in Electronic City with one room free. Suitable for a working flatmate. No brokerage in this demo.'**
  String get aSemiFurnished2BHKInElectronicCity;

  /// No description provided for @aFurnished2BHKInVimanNagarOn.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK in Viman Nagar, on the airport side of the city. The society has a gym. The street address is not published.'**
  String get aFurnished2BHKInVimanNagarOn;

  /// No description provided for @aSemiFurnished1BHKInWakadFor.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 1 BHK in Wakad for one person or a couple. Deposit is two months in this demo.'**
  String get aSemiFurnished1BHKInWakadFor;

  /// No description provided for @aFurnishedPrivateRoomInAHinjewadiFlat.
  ///
  /// In en, this message translates to:
  /// **'A furnished private room in a Hinjewadi flat shared with one other working person. The office parks are a short ride away.'**
  String get aFurnishedPrivateRoomInAHinjewadiFlat;

  /// No description provided for @aFurnished3BHKInKoregaonParkWith.
  ///
  /// In en, this message translates to:
  /// **'A furnished 3 BHK in Koregaon Park with a modular kitchen. Aimed at a small family. The tower name stays private.'**
  String get aFurnished3BHKInKoregaonParkWith;

  /// No description provided for @aSemiFurnished2BHKInAundhWith.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 2 BHK in Aundh with one room free for a flatmate. Pets are noted as not allowed. Contact stays behind the match gate.'**
  String get aSemiFurnished2BHKInAundhWith;

  /// No description provided for @aPrivateRoomInASharedKothrudFlat.
  ///
  /// In en, this message translates to:
  /// **'A private room in a shared Kothrud flat, separate from the lower-rent shared room already in this demo. The street stays off the card.'**
  String get aPrivateRoomInASharedKothrudFlat;

  /// No description provided for @aFurnished2BHKInBandraWestDeposit.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK in Bandra West. Deposit is higher, which is typical for this pocket. Contact stays behind the match gate.'**
  String get aFurnished2BHKInBandraWestDeposit;

  /// No description provided for @aSemiFurnished1BHKInGoregaonEast.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 1 BHK in Goregaon East, sized for one person. Maintenance is separate from the rent shown here.'**
  String get aSemiFurnished1BHKInGoregaonEast;

  /// No description provided for @anUnfurnished2BHKInChemburBringYour.
  ///
  /// In en, this message translates to:
  /// **'An unfurnished 2 BHK in Chembur. Bring your own furniture. The exact address stays off this card.'**
  String get anUnfurnished2BHKInChemburBringYour;

  /// No description provided for @aFurnished2BHKInThaneWithOne.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK in Thane with one room free. The society has a gym. No brokerage in this demo.'**
  String get aFurnished2BHKInThaneWithOne;

  /// No description provided for @aPrivateRoomInASharedMulundFlat.
  ///
  /// In en, this message translates to:
  /// **'A private room in a shared Mulund flat with a common kitchen. Suitable for one working person. No street address is shown.'**
  String get aPrivateRoomInASharedMulundFlat;

  /// No description provided for @aFurnished1BHKInMaladWestFor.
  ///
  /// In en, this message translates to:
  /// **'A furnished 1 BHK in Malad West for one person or a couple. The kitchen is modular. Contact stays behind the match gate.'**
  String get aFurnished1BHKInMaladWestFor;

  /// No description provided for @aFurnished2BHKInMadhapurNearThe.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK in Madhapur, near the office corridor. Suitable for two people sharing. Brokerage is zero in this demo.'**
  String get aFurnished2BHKInMadhapurNearThe;

  /// No description provided for @aSemiFurnished3BHKInKondapurAimed.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 3 BHK in Kondapur aimed at three working people. The society has a clubhouse. The street address is not published.'**
  String get aSemiFurnished3BHKInKondapurAimed;

  /// No description provided for @aCompactFurnishedStudioInHitechCityFor.
  ///
  /// In en, this message translates to:
  /// **'A compact furnished studio in Hitech City for one person. A work desk is included. Maintenance is separate from the rent shown here.'**
  String get aCompactFurnishedStudioInHitechCityFor;

  /// No description provided for @aFurnished3BHKInBanjaraHillsWith.
  ///
  /// In en, this message translates to:
  /// **'A furnished 3 BHK in Banjara Hills with a balcony off the living room. Aimed at a small family. The tower name stays private.'**
  String get aFurnished3BHKInBanjaraHillsWith;

  /// No description provided for @anUnfurnished2BHKInKukatpallyWithOne.
  ///
  /// In en, this message translates to:
  /// **'An unfurnished 2 BHK in Kukatpally with one room free. Bring your own mattress. Contact stays behind the match gate.'**
  String get anUnfurnished2BHKInKukatpallyWithOne;

  /// No description provided for @aFurnished2BHKInNoidaSector62.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK in Noida Sector 62, near the office blocks. Suitable for two people. The exact address stays off this card.'**
  String get aFurnished2BHKInNoidaSector62;

  /// No description provided for @aSemiFurnished3BHKInDwarkaWith.
  ///
  /// In en, this message translates to:
  /// **'A semi-furnished 3 BHK in Dwarka with covered parking. Aimed at a small family. Contact stays behind the match gate.'**
  String get aSemiFurnished3BHKInDwarkaWith;

  /// No description provided for @aFurnished2BHKInSaketWithA.
  ///
  /// In en, this message translates to:
  /// **'A furnished 2 BHK in Saket with a modular kitchen. Deposit is three months in this demo. The street address is not published.'**
  String get aFurnished2BHKInSaketWithA;

  /// No description provided for @anUnfurnished1BHKInGreaterNoidaAt.
  ///
  /// In en, this message translates to:
  /// **'An unfurnished 1 BHK in Greater Noida at a lower rent. Bring your own furniture. No brokerage in this demo.'**
  String get anUnfurnished1BHKInGreaterNoidaAt;

  /// No description provided for @aPrivateRoomInASharedIndirapuramFlat.
  ///
  /// In en, this message translates to:
  /// **'A private room in a shared Indirapuram flat. The kitchen is common. The tower name stays private.'**
  String get aPrivateRoomInASharedIndirapuramFlat;

  /// No description provided for @mapPreview.
  ///
  /// In en, this message translates to:
  /// **'Map preview'**
  String get mapPreview;

  /// No description provided for @productAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Product analytics'**
  String get productAnalytics;

  /// No description provided for @countsOfScreensAndActionsStayInThis.
  ///
  /// In en, this message translates to:
  /// **'Counts of screens and actions stay in this database. Phone numbers, email addresses, and names are not included. Turn this off to stop new events.'**
  String get countsOfScreensAndActionsStayInThis;

  /// No description provided for @reviewReports.
  ///
  /// In en, this message translates to:
  /// **'Review reports'**
  String get reviewReports;

  /// No description provided for @staffAccountsCanHideAListingOrSuspend.
  ///
  /// In en, this message translates to:
  /// **'Staff accounts can hide a listing or suspend an account. No phone number or email is shown.'**
  String get staffAccountsCanHideAListingOrSuspend;

  /// No description provided for @openReportsForAStaffAccountNoPhone.
  ///
  /// In en, this message translates to:
  /// **'Open reports for a staff account. No phone number or email is shown.'**
  String get openReportsForAStaffAccountNoPhone;

  /// No description provided for @noReportsAreWaiting.
  ///
  /// In en, this message translates to:
  /// **'No reports are waiting.'**
  String get noReportsAreWaiting;

  /// No description provided for @hideListing.
  ///
  /// In en, this message translates to:
  /// **'Hide listing'**
  String get hideListing;

  /// No description provided for @suspendAccount.
  ///
  /// In en, this message translates to:
  /// **'Suspend account'**
  String get suspendAccount;

  /// No description provided for @markReviewing.
  ///
  /// In en, this message translates to:
  /// **'Mark reviewing'**
  String get markReviewing;

  /// No description provided for @resolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolve;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @theListingIsHiddenFromTheFeed.
  ///
  /// In en, this message translates to:
  /// **'The listing is hidden from the feed.'**
  String get theListingIsHiddenFromTheFeed;

  /// No description provided for @theAccountIsSuspended.
  ///
  /// In en, this message translates to:
  /// **'The account is suspended.'**
  String get theAccountIsSuspended;

  /// No description provided for @reportUpdated.
  ///
  /// In en, this message translates to:
  /// **'Report updated.'**
  String get reportUpdated;

  /// No description provided for @youAreNotAStaffAccount.
  ///
  /// In en, this message translates to:
  /// **'You are not a staff account.'**
  String get youAreNotAStaffAccount;

  /// No description provided for @messagesStayOnTheMatchAndArriveAs.
  ///
  /// In en, this message translates to:
  /// **'Messages stay on the match and arrive as they are sent. Phone numbers and email addresses are refused. A visit time is not a street address.'**
  String get messagesStayOnTheMatchAndArriveAs;

  /// No description provided for @thisAccountIsSuspended.
  ///
  /// In en, this message translates to:
  /// **'This account is suspended.'**
  String get thisAccountIsSuspended;

  /// No description provided for @thatReportOrListingIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'That report or listing is not available.'**
  String get thatReportOrListingIsNotAvailable;

  /// No description provided for @thatActionIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'That action is not available.'**
  String get thatActionIsNotAvailable;

  /// No description provided for @openingTheQueue.
  ///
  /// In en, this message translates to:
  /// **'Opening the queue…'**
  String get openingTheQueue;

  /// No description provided for @demoModeDoesNotOpenTheStaffQueue.
  ///
  /// In en, this message translates to:
  /// **'Demo mode does not open the staff queue.'**
  String get demoModeDoesNotOpenTheStaffQueue;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @requirement.
  ///
  /// In en, this message translates to:
  /// **'Requirement'**
  String get requirement;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @reviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing'**
  String get reviewing;

  /// No description provided for @resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get resolved;

  /// No description provided for @dismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get dismissed;

  /// No description provided for @budgetMinimumINR.
  ///
  /// In en, this message translates to:
  /// **'Budget minimum (INR)'**
  String get budgetMinimumINR;

  /// No description provided for @budgetMaximumINR.
  ///
  /// In en, this message translates to:
  /// **'Budget maximum (INR)'**
  String get budgetMaximumINR;

  /// No description provided for @localitiesCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Localities, comma separated'**
  String get localitiesCommaSeparated;

  /// No description provided for @leaveLocalitiesBlankWhenYouHaveNoPreference.
  ///
  /// In en, this message translates to:
  /// **'Leave localities blank when you have no preference. Published homes stay in Discover and Explore.'**
  String get leaveLocalitiesBlankWhenYouHaveNoPreference;

  /// No description provided for @propertyTypes.
  ///
  /// In en, this message translates to:
  /// **'Property types'**
  String get propertyTypes;

  /// No description provided for @lifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get lifestyle;

  /// No description provided for @petsOk.
  ///
  /// In en, this message translates to:
  /// **'Pets ok'**
  String get petsOk;

  /// No description provided for @nonSmoker.
  ///
  /// In en, this message translates to:
  /// **'Non-smoker'**
  String get nonSmoker;

  /// No description provided for @earlyRiser.
  ///
  /// In en, this message translates to:
  /// **'Early riser'**
  String get earlyRiser;

  /// No description provided for @nightOwl.
  ///
  /// In en, this message translates to:
  /// **'Night owl'**
  String get nightOwl;

  /// No description provided for @worksFromHome.
  ///
  /// In en, this message translates to:
  /// **'Works from home'**
  String get worksFromHome;

  /// No description provided for @profileSavedNameBioAndPreferencesWereStored.
  ///
  /// In en, this message translates to:
  /// **'Profile saved. Name, bio, and preferences were stored. Contact details were not part of this form.'**
  String get profileSavedNameBioAndPreferencesWereStored;

  /// No description provided for @enterABudgetMinimumThatIsNotAbove.
  ///
  /// In en, this message translates to:
  /// **'Enter a budget minimum that is not above the maximum.'**
  String get enterABudgetMinimumThatIsNotAbove;

  /// No description provided for @enterABudgetInWholeRupeesOrLeave.
  ///
  /// In en, this message translates to:
  /// **'Enter a budget in whole rupees, or leave it blank.'**
  String get enterABudgetInWholeRupeesOrLeave;

  /// No description provided for @eachLocalityMustBe80CharactersOrFewer.
  ///
  /// In en, this message translates to:
  /// **'Each locality must be 80 characters or fewer.'**
  String get eachLocalityMustBe80CharactersOrFewer;

  /// No description provided for @theProfileWasNotSavedTheServerUpdated.
  ///
  /// In en, this message translates to:
  /// **'The profile was not saved. The server updated no row.'**
  String get theProfileWasNotSavedTheServerUpdated;

  /// No description provided for @preferencesWereNotSavedTheServerUpdatedNo.
  ///
  /// In en, this message translates to:
  /// **'Preferences were not saved. The server updated no row.'**
  String get preferencesWereNotSavedTheServerUpdatedNo;

  /// No description provided for @forOwners.
  ///
  /// In en, this message translates to:
  /// **'For owners'**
  String get forOwners;

  /// No description provided for @listYourHomeFree.
  ///
  /// In en, this message translates to:
  /// **'List your home free'**
  String get listYourHomeFree;

  /// No description provided for @postARentalOnHOMIZIAndMeetTenants.
  ///
  /// In en, this message translates to:
  /// **'Post a rental on HOMIZI and meet tenants who already verified a phone or an email. There is no brokerage.'**
  String get postARentalOnHOMIZIAndMeetTenants;

  /// No description provided for @zeroBrokerageHOMIZIDoesNotChargeAFee.
  ///
  /// In en, this message translates to:
  /// **'Zero brokerage. HOMIZI does not charge a fee to list a home or to rent one. Any other monthly charge you type is shown on its own.'**
  String get zeroBrokerageHOMIZIDoesNotChargeAFee;

  /// No description provided for @threeSteps.
  ///
  /// In en, this message translates to:
  /// **'Three steps'**
  String get threeSteps;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @addTheHomeTheRentHouseRulesAnd.
  ///
  /// In en, this message translates to:
  /// **'Add the home, the rent, house rules, and photos. A draft is saved as you go and you can come back to it.'**
  String get addTheHomeTheRentHouseRulesAnd;

  /// No description provided for @matchWithVerifiedTenants.
  ///
  /// In en, this message translates to:
  /// **'Match with verified tenants'**
  String get matchWithVerifiedTenants;

  /// No description provided for @peopleWhoFitTheHomeCanShowInterest.
  ///
  /// In en, this message translates to:
  /// **'People who fit the home can show interest. You see mock verification badges, not their phone number.'**
  String get peopleWhoFitTheHomeCanShowInterest;

  /// No description provided for @meetAndFinalise.
  ///
  /// In en, this message translates to:
  /// **'Meet and finalise'**
  String get meetAndFinalise;

  /// No description provided for @agreeAVisitInTheAppThenDecide.
  ///
  /// In en, this message translates to:
  /// **'Agree a visit in the app, then decide together. The street address stays hidden until you accept the visit.'**
  String get agreeAVisitInTheAppThenDecide;

  /// No description provided for @startAListing.
  ///
  /// In en, this message translates to:
  /// **'Start a listing'**
  String get startAListing;

  /// No description provided for @continueYourDraft.
  ///
  /// In en, this message translates to:
  /// **'Continue your draft'**
  String get continueYourDraft;

  /// No description provided for @myListings.
  ///
  /// In en, this message translates to:
  /// **'My listings'**
  String get myListings;

  /// No description provided for @listingsDidNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Listings did not load'**
  String get listingsDidNotLoad;

  /// No description provided for @retryToReadYourListings.
  ///
  /// In en, this message translates to:
  /// **'Retry to read your listings.'**
  String get retryToReadYourListings;

  /// No description provided for @noListingsYet.
  ///
  /// In en, this message translates to:
  /// **'No listings yet'**
  String get noListingsYet;

  /// No description provided for @listYourHomeFreeADraftStaysPrivate.
  ///
  /// In en, this message translates to:
  /// **'List your home free. A draft stays private until you publish.'**
  String get listYourHomeFreeADraftStaysPrivate;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @markRented.
  ///
  /// In en, this message translates to:
  /// **'Mark rented'**
  String get markRented;

  /// No description provided for @renew.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get renew;

  /// No description provided for @deleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get deleteDraft;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @inReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get inReview;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @rented.
  ///
  /// In en, this message translates to:
  /// **'Rented'**
  String get rented;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @listingPaused.
  ///
  /// In en, this message translates to:
  /// **'Listing paused.'**
  String get listingPaused;

  /// No description provided for @listingIsLiveAgain.
  ///
  /// In en, this message translates to:
  /// **'Listing is live again.'**
  String get listingIsLiveAgain;

  /// No description provided for @markedAsRented.
  ///
  /// In en, this message translates to:
  /// **'Marked as rented.'**
  String get markedAsRented;

  /// No description provided for @theListingWindowIsExtendedBy30Days.
  ///
  /// In en, this message translates to:
  /// **'The listing window is extended by 30 days.'**
  String get theListingWindowIsExtendedBy30Days;

  /// No description provided for @submittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review.'**
  String get submittedForReview;

  /// No description provided for @draftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted.'**
  String get draftDeleted;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated.'**
  String get updated;

  /// No description provided for @signInBeforeManagingAListing.
  ///
  /// In en, this message translates to:
  /// **'Sign in before managing a listing.'**
  String get signInBeforeManagingAListing;

  /// No description provided for @youCanOnlyManageYourOwnListing.
  ///
  /// In en, this message translates to:
  /// **'You can only manage your own listing.'**
  String get youCanOnlyManageYourOwnListing;

  /// No description provided for @addATitleACityALocalityAnd.
  ///
  /// In en, this message translates to:
  /// **'Add a title, a city, a locality, and the rent first.'**
  String get addATitleACityALocalityAnd;

  /// No description provided for @onlyADraftCanBeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Only a draft can be deleted.'**
  String get onlyADraftCanBeDeleted;

  /// No description provided for @thatActionIsNotAvailableForThisListing.
  ///
  /// In en, this message translates to:
  /// **'That action is not available for this listing.'**
  String get thatActionIsNotAvailableForThisListing;

  /// No description provided for @theDemoIdentityBadgeIsNotAvailableHere.
  ///
  /// In en, this message translates to:
  /// **'The demo identity badge is not available here.'**
  String get theDemoIdentityBadgeIsNotAvailableHere;

  /// No description provided for @theServerDidNotUpdateThisListing.
  ///
  /// In en, this message translates to:
  /// **'The server did not update this listing.'**
  String get theServerDidNotUpdateThisListing;

  /// No description provided for @listingPerformance.
  ///
  /// In en, this message translates to:
  /// **'Listing performance'**
  String get listingPerformance;

  /// No description provided for @statsDidNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Stats did not load.'**
  String get statsDidNotLoad;

  /// No description provided for @viewsSavesAndInterestsForThisListingOnly.
  ///
  /// In en, this message translates to:
  /// **'Views, saves, and interests for this listing. Only you can see this.'**
  String get viewsSavesAndInterestsForThisListingOnly;

  /// No description provided for @m7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get m7Days;

  /// No description provided for @m30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get m30Days;

  /// No description provided for @phoneVerified.
  ///
  /// In en, this message translates to:
  /// **'Phone verified'**
  String get phoneVerified;

  /// No description provided for @emailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get emailVerified;

  /// No description provided for @profileComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile complete'**
  String get profileComplete;

  /// No description provided for @idVerifiedDemo.
  ///
  /// In en, this message translates to:
  /// **'ID verified (demo)'**
  String get idVerifiedDemo;

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verification;

  /// No description provided for @theseBadgesAreMockChecksHOMIZIDoesNot.
  ///
  /// In en, this message translates to:
  /// **'These badges are mock checks. HOMIZI does not collect an Aadhaar number, a passport, or a face scan.'**
  String get theseBadgesAreMockChecksHOMIZIDoesNot;

  /// No description provided for @demoIDBadgeIsOnNoIdentityDocument.
  ///
  /// In en, this message translates to:
  /// **'Demo ID badge is on. No identity document was collected.'**
  String get demoIDBadgeIsOnNoIdentityDocument;

  /// No description provided for @demoIDBadgeIsOff.
  ///
  /// In en, this message translates to:
  /// **'Demo ID badge is off.'**
  String get demoIDBadgeIsOff;

  /// No description provided for @stagingOnlyTurningThisOnDoesNotVerify.
  ///
  /// In en, this message translates to:
  /// **'Staging only. Turning this on does not verify an identity document.'**
  String get stagingOnlyTurningThisOnDoesNotVerify;

  /// No description provided for @listYourHome.
  ///
  /// In en, this message translates to:
  /// **'List your home'**
  String get listYourHome;

  /// No description provided for @basics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get basics;

  /// No description provided for @rentAndDeposit.
  ///
  /// In en, this message translates to:
  /// **'Rent and deposit'**
  String get rentAndDeposit;

  /// No description provided for @amenitiesAndHouseRules.
  ///
  /// In en, this message translates to:
  /// **'Amenities and house rules'**
  String get amenitiesAndHouseRules;

  /// No description provided for @preferredTenants.
  ///
  /// In en, this message translates to:
  /// **'Preferred tenants'**
  String get preferredTenants;

  /// No description provided for @reviewAndPublish.
  ///
  /// In en, this message translates to:
  /// **'Review and publish'**
  String get reviewAndPublish;

  /// No description provided for @brokerageStaysZeroUseOtherMonthlyChargesOnly.
  ///
  /// In en, this message translates to:
  /// **'Brokerage stays zero. Use other monthly charges only for society or utility amounts you want shown.'**
  String get brokerageStaysZeroUseOtherMonthlyChargesOnly;

  /// No description provided for @houseRules.
  ///
  /// In en, this message translates to:
  /// **'House rules'**
  String get houseRules;

  /// No description provided for @chooseWhoTheHomeSuitsThisIsA.
  ///
  /// In en, this message translates to:
  /// **'Choose who the home suits. This is a preference, not a filter on gender, religion, or caste.'**
  String get chooseWhoTheHomeSuitsThisIsA;

  /// No description provided for @noneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get noneYet;

  /// No description provided for @readyToPublishTheServerStillChecksAt.
  ///
  /// In en, this message translates to:
  /// **'Ready to publish. The server still checks at least 3 photos and a room as the primary photo.'**
  String get readyToPublishTheServerStillChecksAt;

  /// No description provided for @listYourHomeFreeZeroBrokerage.
  ///
  /// In en, this message translates to:
  /// **'List your home free. Zero brokerage.'**
  String get listYourHomeFreeZeroBrokerage;

  /// No description provided for @draftsLiveHomesPausesAndRentedListings.
  ///
  /// In en, this message translates to:
  /// **'Drafts, live homes, pauses, and rented listings.'**
  String get draftsLiveHomesPausesAndRentedListings;

  /// No description provided for @forOwnersZeroBrokerageFromListToVisit.
  ///
  /// In en, this message translates to:
  /// **'For owners. Zero brokerage, from list to visit.'**
  String get forOwnersZeroBrokerageFromListToVisit;

  /// No description provided for @chennai.
  ///
  /// In en, this message translates to:
  /// **'Chennai'**
  String get chennai;

  /// No description provided for @submitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get submitForReview;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @moveInEarliest.
  ///
  /// In en, this message translates to:
  /// **'Move-in, earliest'**
  String get moveInEarliest;

  /// No description provided for @mostViewed.
  ///
  /// In en, this message translates to:
  /// **'Most viewed'**
  String get mostViewed;

  /// No description provided for @searchSaved.
  ///
  /// In en, this message translates to:
  /// **'Search saved.'**
  String get searchSaved;

  /// No description provided for @nameThisSearchIn80CharactersOrFewer.
  ///
  /// In en, this message translates to:
  /// **'Name this search in 80 characters or fewer.'**
  String get nameThisSearchIn80CharactersOrFewer;

  /// No description provided for @groupByLocality.
  ///
  /// In en, this message translates to:
  /// **'Group by locality'**
  String get groupByLocality;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @savedSearches.
  ///
  /// In en, this message translates to:
  /// **'Saved searches'**
  String get savedSearches;

  /// No description provided for @recentlyViewed.
  ///
  /// In en, this message translates to:
  /// **'Recently viewed'**
  String get recentlyViewed;

  /// No description provided for @findAHome.
  ///
  /// In en, this message translates to:
  /// **'Find a home'**
  String get findAHome;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @saveThisSearch.
  ///
  /// In en, this message translates to:
  /// **'Save this search'**
  String get saveThisSearch;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @groupedByLocalityAMapNeedsAMaps.
  ///
  /// In en, this message translates to:
  /// **'Grouped by locality. A map needs a maps provider, so homes are listed by area.'**
  String get groupedByLocalityAMapNeedsAMaps;

  /// No description provided for @openingViewedHomes.
  ///
  /// In en, this message translates to:
  /// **'Opening viewed homes…'**
  String get openingViewedHomes;

  /// No description provided for @couldNotLoadViewedHomes.
  ///
  /// In en, this message translates to:
  /// **'Could not load viewed homes'**
  String get couldNotLoadViewedHomes;

  /// No description provided for @noHomesViewedYet.
  ///
  /// In en, this message translates to:
  /// **'No homes viewed yet'**
  String get noHomesViewedYet;

  /// No description provided for @openAListingAndItWillShowUp.
  ///
  /// In en, this message translates to:
  /// **'Open a listing and it will show up here.'**
  String get openAListingAndItWillShowUp;

  /// No description provided for @openingSavedSearches.
  ///
  /// In en, this message translates to:
  /// **'Opening saved searches…'**
  String get openingSavedSearches;

  /// No description provided for @couldNotLoadSavedSearches.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved searches'**
  String get couldNotLoadSavedSearches;

  /// No description provided for @noSavedSearchesYet.
  ///
  /// In en, this message translates to:
  /// **'No saved searches yet'**
  String get noSavedSearchesYet;

  /// No description provided for @saveASearchFromExploreAndNewHomes.
  ///
  /// In en, this message translates to:
  /// **'Save a search from Explore and new homes will be counted here.'**
  String get saveASearchFromExploreAndNewHomes;

  /// No description provided for @markChecked.
  ///
  /// In en, this message translates to:
  /// **'Mark checked'**
  String get markChecked;

  /// No description provided for @deleteSearch.
  ///
  /// In en, this message translates to:
  /// **'Delete search'**
  String get deleteSearch;

  /// No description provided for @requestPhotos.
  ///
  /// In en, this message translates to:
  /// **'Request photos'**
  String get requestPhotos;

  /// No description provided for @theHostWasAskedForMorePhotos.
  ///
  /// In en, this message translates to:
  /// **'The host was asked for more photos.'**
  String get theHostWasAskedForMorePhotos;

  /// No description provided for @youAlreadyAskedForPhotosOnThisHome.
  ///
  /// In en, this message translates to:
  /// **'You already asked for photos on this home today.'**
  String get youAlreadyAskedForPhotosOnThisHome;

  /// No description provided for @thisHomeAlreadyHasEnoughPhotos.
  ///
  /// In en, this message translates to:
  /// **'This home already has enough photos.'**
  String get thisHomeAlreadyHasEnoughPhotos;

  /// No description provided for @builtUpAreaSqFt.
  ///
  /// In en, this message translates to:
  /// **'Built-up area (sq ft)'**
  String get builtUpAreaSqFt;

  /// No description provided for @floor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floor;

  /// No description provided for @totalFloors.
  ///
  /// In en, this message translates to:
  /// **'Total floors'**
  String get totalFloors;

  /// No description provided for @petsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Pets allowed'**
  String get petsAllowed;

  /// No description provided for @nonVegAllowed.
  ///
  /// In en, this message translates to:
  /// **'Non-veg allowed'**
  String get nonVegAllowed;

  /// No description provided for @gatedSociety.
  ///
  /// In en, this message translates to:
  /// **'Gated society'**
  String get gatedSociety;

  /// No description provided for @family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get family;

  /// No description provided for @bachelors.
  ///
  /// In en, this message translates to:
  /// **'Bachelors'**
  String get bachelors;

  /// No description provided for @women.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get women;

  /// No description provided for @photosOnly.
  ///
  /// In en, this message translates to:
  /// **'Photos only'**
  String get photosOnly;

  /// No description provided for @verifiedHostsOnly.
  ///
  /// In en, this message translates to:
  /// **'Verified hosts only'**
  String get verifiedHostsOnly;

  /// No description provided for @builtUpAreaAny.
  ///
  /// In en, this message translates to:
  /// **'Built-up area · Any'**
  String get builtUpAreaAny;

  /// No description provided for @floorAny.
  ///
  /// In en, this message translates to:
  /// **'Floor · Any'**
  String get floorAny;

  /// No description provided for @m1RK.
  ///
  /// In en, this message translates to:
  /// **'1 RK'**
  String get m1RK;

  /// No description provided for @fullHouse.
  ///
  /// In en, this message translates to:
  /// **'Full house'**
  String get fullHouse;

  /// No description provided for @homes.
  ///
  /// In en, this message translates to:
  /// **'Homes'**
  String get homes;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @tool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get tool;

  /// No description provided for @signInBeforeSearching.
  ///
  /// In en, this message translates to:
  /// **'Sign in before searching.'**
  String get signInBeforeSearching;

  /// No description provided for @someoneAskedForMorePhotosOnAListing.
  ///
  /// In en, this message translates to:
  /// **'Someone asked for more photos on a listing.'**
  String get someoneAskedForMorePhotosOnAListing;

  /// No description provided for @enterBuiltUpAreaBetween50And20000.
  ///
  /// In en, this message translates to:
  /// **'Enter built-up area between 50 and 20000 sq ft, or leave it blank.'**
  String get enterBuiltUpAreaBetween50And20000;

  /// No description provided for @enterAFloorFrom0To60Or.
  ///
  /// In en, this message translates to:
  /// **'Enter a floor from 0 to 60, or leave it blank.'**
  String get enterAFloorFrom0To60Or;

  /// No description provided for @enterTotalFloorsFrom1To60Or.
  ///
  /// In en, this message translates to:
  /// **'Enter total floors from 1 to 60, or leave it blank.'**
  String get enterTotalFloorsFrom1To60Or;

  /// No description provided for @floorCannotBeAboveTheTopFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor cannot be above the top floor.'**
  String get floorCannotBeAboveTheTopFloor;

  /// No description provided for @choosePreferredTenantsFromTheList.
  ///
  /// In en, this message translates to:
  /// **'Choose preferred tenants from the list.'**
  String get choosePreferredTenantsFromTheList;

  /// No description provided for @rentReceipts.
  ///
  /// In en, this message translates to:
  /// **'Rent receipts'**
  String get rentReceipts;

  /// No description provided for @agreementDraft.
  ///
  /// In en, this message translates to:
  /// **'Agreement draft'**
  String get agreementDraft;

  /// No description provided for @rentSplit.
  ///
  /// In en, this message translates to:
  /// **'Rent split'**
  String get rentSplit;

  /// No description provided for @moveInChecklist.
  ///
  /// In en, this message translates to:
  /// **'Move-in checklist'**
  String get moveInChecklist;

  /// No description provided for @depositTracker.
  ///
  /// In en, this message translates to:
  /// **'Deposit tracker'**
  String get depositTracker;

  /// No description provided for @malleswaram.
  ///
  /// In en, this message translates to:
  /// **'Malleswaram'**
  String get malleswaram;

  /// No description provided for @dadar.
  ///
  /// In en, this message translates to:
  /// **'Dadar'**
  String get dadar;

  /// No description provided for @juhu.
  ///
  /// In en, this message translates to:
  /// **'Juhu'**
  String get juhu;

  /// No description provided for @kalyaniNagar.
  ///
  /// In en, this message translates to:
  /// **'Kalyani Nagar'**
  String get kalyaniNagar;

  /// No description provided for @hadapsar.
  ///
  /// In en, this message translates to:
  /// **'Hadapsar'**
  String get hadapsar;

  /// No description provided for @noida.
  ///
  /// In en, this message translates to:
  /// **'Noida'**
  String get noida;

  /// No description provided for @rohini.
  ///
  /// In en, this message translates to:
  /// **'Rohini'**
  String get rohini;

  /// No description provided for @jubileeHills.
  ///
  /// In en, this message translates to:
  /// **'Jubilee Hills'**
  String get jubileeHills;

  /// No description provided for @manikonda.
  ///
  /// In en, this message translates to:
  /// **'Manikonda'**
  String get manikonda;

  /// No description provided for @adyar.
  ///
  /// In en, this message translates to:
  /// **'Adyar'**
  String get adyar;

  /// No description provided for @tNagar.
  ///
  /// In en, this message translates to:
  /// **'T. Nagar'**
  String get tNagar;

  /// No description provided for @velachery.
  ///
  /// In en, this message translates to:
  /// **'Velachery'**
  String get velachery;

  /// No description provided for @annaNagar.
  ///
  /// In en, this message translates to:
  /// **'Anna Nagar'**
  String get annaNagar;

  /// No description provided for @omr.
  ///
  /// In en, this message translates to:
  /// **'OMR'**
  String get omr;

  /// No description provided for @porur.
  ///
  /// In en, this message translates to:
  /// **'Porur'**
  String get porur;

  /// No description provided for @besantNagar.
  ///
  /// In en, this message translates to:
  /// **'Besant Nagar'**
  String get besantNagar;

  /// No description provided for @mylapore.
  ///
  /// In en, this message translates to:
  /// **'Mylapore'**
  String get mylapore;

  /// No description provided for @tambaram.
  ///
  /// In en, this message translates to:
  /// **'Tambaram'**
  String get tambaram;

  /// No description provided for @guindy.
  ///
  /// In en, this message translates to:
  /// **'Guindy'**
  String get guindy;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @activityRoleAndLanguage.
  ///
  /// In en, this message translates to:
  /// **'Activity, role, and language.'**
  String get activityRoleAndLanguage;

  /// No description provided for @receiptsAgreementDraftSplitChecklistAndDeposit.
  ///
  /// In en, this message translates to:
  /// **'Receipts, agreement draft, split, checklist, and deposit.'**
  String get receiptsAgreementDraftSplitChecklistAndDeposit;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @listings.
  ///
  /// In en, this message translates to:
  /// **'Listings'**
  String get listings;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @searchHelp.
  ///
  /// In en, this message translates to:
  /// **'Search help'**
  String get searchHelp;

  /// No description provided for @renting.
  ///
  /// In en, this message translates to:
  /// **'Renting'**
  String get renting;

  /// No description provided for @flatmates.
  ///
  /// In en, this message translates to:
  /// **'Flatmates'**
  String get flatmates;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @noMatchingQuestions.
  ///
  /// In en, this message translates to:
  /// **'No matching questions.'**
  String get noMatchingQuestions;

  /// No description provided for @safetyTips.
  ///
  /// In en, this message translates to:
  /// **'Safety tips'**
  String get safetyTips;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @topic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// No description provided for @thisNoteStaysOnYourAccountDoNot.
  ///
  /// In en, this message translates to:
  /// **'This note stays on your account. Do not include a phone number or an email address.'**
  String get thisNoteStaysOnYourAccountDoNot;

  /// No description provided for @ticketSavedAPersonOnTheHOMIZIProject.
  ///
  /// In en, this message translates to:
  /// **'Ticket saved. A person on the HOMIZI project can read it. No phone number or email is stored in the ticket.'**
  String get ticketSavedAPersonOnTheHOMIZIProject;

  /// No description provided for @writeBetween10And1000Characters.
  ///
  /// In en, this message translates to:
  /// **'Write between 10 and 1000 characters.'**
  String get writeBetween10And1000Characters;

  /// No description provided for @leaveOutPhoneNumbersAndEmailAddresses.
  ///
  /// In en, this message translates to:
  /// **'Leave out phone numbers and email addresses.'**
  String get leaveOutPhoneNumbersAndEmailAddresses;

  /// No description provided for @chooseATopic.
  ///
  /// In en, this message translates to:
  /// **'Choose a topic.'**
  String get chooseATopic;

  /// No description provided for @signInBeforeContactingSupport.
  ///
  /// In en, this message translates to:
  /// **'Sign in before contacting support.'**
  String get signInBeforeContactingSupport;

  /// No description provided for @theSupportNoteCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'The support note could not be saved.'**
  String get theSupportNoteCouldNotBeSaved;

  /// No description provided for @theSupportReplyWasNotReadable.
  ///
  /// In en, this message translates to:
  /// **'The support reply was not readable.'**
  String get theSupportReplyWasNotReadable;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notificationPreferences;

  /// No description provided for @turnACategoryOffToStopNewAlerts.
  ///
  /// In en, this message translates to:
  /// **'Turn a category off to stop new alerts of that kind. This does not send a phone alert.'**
  String get turnACategoryOffToStopNewAlerts;

  /// No description provided for @notificationPreferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences saved.'**
  String get notificationPreferencesSaved;

  /// No description provided for @nothingInThisCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this category.'**
  String get nothingInThisCategory;

  /// No description provided for @removedOnThisDeviceTheServerWasNot.
  ///
  /// In en, this message translates to:
  /// **'Removed on this device. The server was not updated.'**
  String get removedOnThisDeviceTheServerWasNot;

  /// No description provided for @dismissed2.
  ///
  /// In en, this message translates to:
  /// **'Dismissed.'**
  String get dismissed2;

  /// No description provided for @depositRefundReminder.
  ///
  /// In en, this message translates to:
  /// **'Deposit refund reminder.'**
  String get depositRefundReminder;

  /// No description provided for @yourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get yourProfile;

  /// No description provided for @addWhatYouDo.
  ///
  /// In en, this message translates to:
  /// **'Add what you do'**
  String get addWhatYouDo;

  /// No description provided for @nameWorkAShortBioABudgetA.
  ///
  /// In en, this message translates to:
  /// **'Name, work, a short bio, a budget, a locality, and a role.'**
  String get nameWorkAShortBioABudgetA;

  /// No description provided for @loading2.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading2;

  /// No description provided for @myActivity.
  ///
  /// In en, this message translates to:
  /// **'My activity'**
  String get myActivity;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get nothingHereYet;

  /// No description provided for @noHomesViewedYet2.
  ///
  /// In en, this message translates to:
  /// **'No homes viewed yet.'**
  String get noHomesViewedYet2;

  /// No description provided for @recentlyViewedIsNotOnThisProjectYet.
  ///
  /// In en, this message translates to:
  /// **'Recently viewed is not on this project yet.'**
  String get recentlyViewedIsNotOnThisProjectYet;

  /// No description provided for @paperworkForARentalHOMIZIDoesNotCollect.
  ///
  /// In en, this message translates to:
  /// **'Paperwork for a rental. HOMIZI does not collect rent or stamp an agreement.'**
  String get paperworkForARentalHOMIZIDoesNotCollect;

  /// No description provided for @rentReceipt.
  ///
  /// In en, this message translates to:
  /// **'Rent receipt'**
  String get rentReceipt;

  /// No description provided for @writeAReceiptForRentYouAlreadyPaid.
  ///
  /// In en, this message translates to:
  /// **'Write a receipt for rent you already paid, then download the PDF.'**
  String get writeAReceiptForRentYouAlreadyPaid;

  /// No description provided for @splitRentDepositMaintenanceAndUtilitiesByRoom.
  ///
  /// In en, this message translates to:
  /// **'Split rent, deposit, maintenance, and utilities by room.'**
  String get splitRentDepositMaintenanceAndUtilitiesByRoom;

  /// No description provided for @fillAn11MonthLeaveAndLicenceDraft.
  ///
  /// In en, this message translates to:
  /// **'Fill an 11-month leave-and-licence draft. It is not stamped.'**
  String get fillAn11MonthLeaveAndLicenceDraft;

  /// No description provided for @noteEachRoomItsConditionAndAnOptional.
  ///
  /// In en, this message translates to:
  /// **'Note each room, its condition, and an optional photo.'**
  String get noteEachRoomItsConditionAndAnOptional;

  /// No description provided for @trackTheDepositDeductionsAndARefundReminder.
  ///
  /// In en, this message translates to:
  /// **'Track the deposit, deductions, and a refund reminder in the app.'**
  String get trackTheDepositDeductionsAndARefundReminder;

  /// No description provided for @forAPaymentYouAlreadyMadeHOMIZIDoes.
  ///
  /// In en, this message translates to:
  /// **'For a payment you already made. HOMIZI does not collect the rent.'**
  String get forAPaymentYouAlreadyMadeHOMIZIDoes;

  /// No description provided for @ananyaIyer.
  ///
  /// In en, this message translates to:
  /// **'Ananya Iyer'**
  String get ananyaIyer;

  /// No description provided for @rohanMehta.
  ///
  /// In en, this message translates to:
  /// **'Rohan Mehta'**
  String get rohanMehta;

  /// No description provided for @propertyAddress.
  ///
  /// In en, this message translates to:
  /// **'Property address'**
  String get propertyAddress;

  /// No description provided for @m184thCrossKoramangala5thBlockBengaluru.
  ///
  /// In en, this message translates to:
  /// **'18, 4th Cross, Koramangala 5th Block, Bengaluru'**
  String get m184thCrossKoramangala5thBlockBengaluru;

  /// No description provided for @monthlyRent2.
  ///
  /// In en, this message translates to:
  /// **'Monthly rent'**
  String get monthlyRent2;

  /// No description provided for @ownerPANOptional.
  ///
  /// In en, this message translates to:
  /// **'Owner PAN, optional'**
  String get ownerPANOptional;

  /// No description provided for @paymentMode.
  ///
  /// In en, this message translates to:
  /// **'Payment mode'**
  String get paymentMode;

  /// No description provided for @upi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get upi;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get bankTransfer;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @cheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get cheque;

  /// No description provided for @generatePDF.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF'**
  String get generatePDF;

  /// No description provided for @pastReceipts.
  ///
  /// In en, this message translates to:
  /// **'Past receipts'**
  String get pastReceipts;

  /// No description provided for @noReceiptsYetAReceiptStaysOnYour.
  ///
  /// In en, this message translates to:
  /// **'No receipts yet. A receipt stays on your account so you can download it again.'**
  String get noReceiptsYetAReceiptStaysOnYour;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @receiptSavedYouCanDownloadItAgainBelow.
  ///
  /// In en, this message translates to:
  /// **'Receipt saved. You can download it again below.'**
  String get receiptSavedYouCanDownloadItAgainBelow;

  /// No description provided for @receiptSavedThePDFShareSheetDidNot.
  ///
  /// In en, this message translates to:
  /// **'Receipt saved. The PDF share sheet did not open.'**
  String get receiptSavedThePDFShareSheetDidNot;

  /// No description provided for @thePDFShareSheetDidNotOpen.
  ///
  /// In en, this message translates to:
  /// **'The PDF share sheet did not open.'**
  String get thePDFShareSheetDidNotOpen;

  /// No description provided for @enterTheTenantNameBetween2And80.
  ///
  /// In en, this message translates to:
  /// **'Enter the tenant name, between 2 and 80 characters.'**
  String get enterTheTenantNameBetween2And80;

  /// No description provided for @enterTheOwnerNameBetween2And80.
  ///
  /// In en, this message translates to:
  /// **'Enter the owner name, between 2 and 80 characters.'**
  String get enterTheOwnerNameBetween2And80;

  /// No description provided for @enterThePropertyAddressBetween8And240.
  ///
  /// In en, this message translates to:
  /// **'Enter the property address, between 8 and 240 characters.'**
  String get enterThePropertyAddressBetween8And240;

  /// No description provided for @enterTheMonthlyRentInWholeRupees.
  ///
  /// In en, this message translates to:
  /// **'Enter the monthly rent in whole rupees.'**
  String get enterTheMonthlyRentInWholeRupees;

  /// No description provided for @theEndMonthCannotBeBeforeTheStart.
  ///
  /// In en, this message translates to:
  /// **'The end month cannot be before the start month.'**
  String get theEndMonthCannotBeBeforeTheStart;

  /// No description provided for @ownerPANMustLookLikeABCDE1234FOrStay.
  ///
  /// In en, this message translates to:
  /// **'Owner PAN must look like ABCDE1234F, or stay blank.'**
  String get ownerPANMustLookLikeABCDE1234FOrStay;

  /// No description provided for @chooseAPaymentMode.
  ///
  /// In en, this message translates to:
  /// **'Choose a payment mode.'**
  String get chooseAPaymentMode;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// No description provided for @aLargerRoomCanTakeAHigherWeight.
  ///
  /// In en, this message translates to:
  /// **'A larger room can take a higher weight. The shares add back to the amounts you enter.'**
  String get aLargerRoomCanTakeAHigherWeight;

  /// No description provided for @deposit2.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit2;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @utilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get utilities;

  /// No description provided for @householdTakeHomeOptional.
  ///
  /// In en, this message translates to:
  /// **'Household take-home, optional'**
  String get householdTakeHomeOptional;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @addFlatmate.
  ///
  /// In en, this message translates to:
  /// **'Add flatmate'**
  String get addFlatmate;

  /// No description provided for @calculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get calculate;

  /// No description provided for @enterWholeRupeesForEachAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter whole rupees for each amount.'**
  String get enterWholeRupeesForEachAmount;

  /// No description provided for @eachRoomShareMustBeAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'Each room share must be at least 1.'**
  String get eachRoomShareMustBeAtLeast1;

  /// No description provided for @theSplitCouldNotBeCalculated.
  ///
  /// In en, this message translates to:
  /// **'The split could not be calculated.'**
  String get theSplitCouldNotBeCalculated;

  /// No description provided for @comfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortable;

  /// No description provided for @stretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get stretch;

  /// No description provided for @aboveAThird.
  ///
  /// In en, this message translates to:
  /// **'Above a third'**
  String get aboveAThird;

  /// No description provided for @draftNotStampedOrRegisteredForReferenceOnly.
  ///
  /// In en, this message translates to:
  /// **'Draft – not stamped or registered, for reference only'**
  String get draftNotStampedOrRegisteredForReferenceOnly;

  /// No description provided for @an11MonthLeaveAndLicenceHOMIZIDoes.
  ///
  /// In en, this message translates to:
  /// **'An 11-month leave and licence. HOMIZI does not stamp it or register it.'**
  String get an11MonthLeaveAndLicenceHOMIZIDoes;

  /// No description provided for @licensorOwner.
  ///
  /// In en, this message translates to:
  /// **'Licensor (owner)'**
  String get licensorOwner;

  /// No description provided for @licenseeTenant.
  ///
  /// In en, this message translates to:
  /// **'Licensee (tenant)'**
  String get licenseeTenant;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @generateDraftPDF.
  ///
  /// In en, this message translates to:
  /// **'Generate draft PDF'**
  String get generateDraftPDF;

  /// No description provided for @savedDrafts.
  ///
  /// In en, this message translates to:
  /// **'Saved drafts'**
  String get savedDrafts;

  /// No description provided for @noDraftsYet.
  ///
  /// In en, this message translates to:
  /// **'No drafts yet.'**
  String get noDraftsYet;

  /// No description provided for @draftSavedThePDFShareSheetDidNot.
  ///
  /// In en, this message translates to:
  /// **'Draft saved. The PDF share sheet did not open.'**
  String get draftSavedThePDFShareSheetDidNot;

  /// No description provided for @draftSavedThePDFIsMarkedAsNot.
  ///
  /// In en, this message translates to:
  /// **'Draft saved. The PDF is marked as not stamped or registered.'**
  String get draftSavedThePDFIsMarkedAsNot;

  /// No description provided for @enterTheStartDateAsYYYYMMDD.
  ///
  /// In en, this message translates to:
  /// **'Enter the start date as YYYY-MM-DD.'**
  String get enterTheStartDateAsYYYYMMDD;

  /// No description provided for @enterTheLicensorNameBetween2And80.
  ///
  /// In en, this message translates to:
  /// **'Enter the licensor name, between 2 and 80 characters.'**
  String get enterTheLicensorNameBetween2And80;

  /// No description provided for @enterTheLicenseeNameBetween2And80.
  ///
  /// In en, this message translates to:
  /// **'Enter the licensee name, between 2 and 80 characters.'**
  String get enterTheLicenseeNameBetween2And80;

  /// No description provided for @enterTheCity.
  ///
  /// In en, this message translates to:
  /// **'Enter the city.'**
  String get enterTheCity;

  /// No description provided for @enterTheDepositInWholeRupeesOr0.
  ///
  /// In en, this message translates to:
  /// **'Enter the deposit in whole rupees, or 0.'**
  String get enterTheDepositInWholeRupeesOr0;

  /// No description provided for @enterTheMaintenanceInWholeRupeesOr0.
  ///
  /// In en, this message translates to:
  /// **'Enter the maintenance in whole rupees, or 0.'**
  String get enterTheMaintenanceInWholeRupeesOr0;

  /// No description provided for @roomByRoomLinkAMatchIfThe.
  ///
  /// In en, this message translates to:
  /// **'Room by room. Link a match if the other person should read this. They cannot edit it.'**
  String get roomByRoomLinkAMatchIfThe;

  /// No description provided for @checklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist title'**
  String get checklistTitle;

  /// No description provided for @koramangalaMoveIn.
  ///
  /// In en, this message translates to:
  /// **'Koramangala move-in'**
  String get koramangalaMoveIn;

  /// No description provided for @shareWithAMatch.
  ///
  /// In en, this message translates to:
  /// **'Share with a match'**
  String get shareWithAMatch;

  /// No description provided for @onlyMe.
  ///
  /// In en, this message translates to:
  /// **'Only me'**
  String get onlyMe;

  /// No description provided for @createChecklist.
  ///
  /// In en, this message translates to:
  /// **'Create checklist'**
  String get createChecklist;

  /// No description provided for @checklistSavedOnYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Checklist saved on your account.'**
  String get checklistSavedOnYourAccount;

  /// No description provided for @sharedWithYouReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Shared with you, read only'**
  String get sharedWithYouReadOnly;

  /// No description provided for @sharedFromAMatchYouCanReadThis.
  ///
  /// In en, this message translates to:
  /// **'Shared from a match. You can read this checklist.'**
  String get sharedFromAMatchYouCanReadThis;

  /// No description provided for @photoSaved.
  ///
  /// In en, this message translates to:
  /// **'Photo saved'**
  String get photoSaved;

  /// No description provided for @room.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get room;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @sofa.
  ///
  /// In en, this message translates to:
  /// **'Sofa'**
  String get sofa;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @fair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get fair;

  /// No description provided for @worn.
  ///
  /// In en, this message translates to:
  /// **'Worn'**
  String get worn;

  /// No description provided for @damaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get damaged;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @noStainsOnTheSeat.
  ///
  /// In en, this message translates to:
  /// **'No stains on the seat'**
  String get noStainsOnTheSeat;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @itemAdded.
  ///
  /// In en, this message translates to:
  /// **'Item added.'**
  String get itemAdded;

  /// No description provided for @photoSavedInYourFolder.
  ///
  /// In en, this message translates to:
  /// **'Photo saved in your folder.'**
  String get photoSavedInYourFolder;

  /// No description provided for @giveTheChecklistATitleOf3To.
  ///
  /// In en, this message translates to:
  /// **'Give the checklist a title of 3 to 80 characters.'**
  String get giveTheChecklistATitleOf3To;

  /// No description provided for @chooseARoomAndACondition.
  ///
  /// In en, this message translates to:
  /// **'Choose a room and a condition.'**
  String get chooseARoomAndACondition;

  /// No description provided for @nameTheItemIn80CharactersOrFewer.
  ///
  /// In en, this message translates to:
  /// **'Name the item in 80 characters or fewer.'**
  String get nameTheItemIn80CharactersOrFewer;

  /// No description provided for @keepTheNoteTo400Characters.
  ///
  /// In en, this message translates to:
  /// **'Keep the note to 400 characters.'**
  String get keepTheNoteTo400Characters;

  /// No description provided for @useAPhotoUnder5MB.
  ///
  /// In en, this message translates to:
  /// **'Use a photo under 5 MB.'**
  String get useAPhotoUnder5MB;

  /// No description provided for @thatItemIsNotOnThisChecklist.
  ///
  /// In en, this message translates to:
  /// **'That item is not on this checklist.'**
  String get thatItemIsNotOnThisChecklist;

  /// No description provided for @thatChecklistIsNotOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'That checklist is not on this device.'**
  String get thatChecklistIsNotOnThisDevice;

  /// No description provided for @thisChecklistIsSharedWithYouAsRead.
  ///
  /// In en, this message translates to:
  /// **'This checklist is shared with you as read only.'**
  String get thisChecklistIsSharedWithYouAsRead;

  /// No description provided for @recordADepositYouAlreadyPaidTheReminder.
  ///
  /// In en, this message translates to:
  /// **'Record a deposit you already paid. The reminder stays inside HOMIZI.'**
  String get recordADepositYouAlreadyPaidTheReminder;

  /// No description provided for @koramangala5thBlock.
  ///
  /// In en, this message translates to:
  /// **'Koramangala 5th Block'**
  String get koramangala5thBlock;

  /// No description provided for @depositPaid.
  ///
  /// In en, this message translates to:
  /// **'Deposit paid'**
  String get depositPaid;

  /// No description provided for @refundDueDate.
  ///
  /// In en, this message translates to:
  /// **'Refund due date'**
  String get refundDueDate;

  /// No description provided for @saveDeposit.
  ///
  /// In en, this message translates to:
  /// **'Save deposit'**
  String get saveDeposit;

  /// No description provided for @depositSavedHOMIZIDidNotMoveThisMoney.
  ///
  /// In en, this message translates to:
  /// **'Deposit saved. HOMIZI did not move this money.'**
  String get depositSavedHOMIZIDidNotMoveThisMoney;

  /// No description provided for @enterTheRefundDateAsYYYYMMDD.
  ///
  /// In en, this message translates to:
  /// **'Enter the refund date as YYYY-MM-DD, or leave it blank.'**
  String get enterTheRefundDateAsYYYYMMDD;

  /// No description provided for @enterTheDepositInWholeRupees.
  ///
  /// In en, this message translates to:
  /// **'Enter the deposit in whole rupees.'**
  String get enterTheDepositInWholeRupees;

  /// No description provided for @deduction.
  ///
  /// In en, this message translates to:
  /// **'Deduction'**
  String get deduction;

  /// No description provided for @painting.
  ///
  /// In en, this message translates to:
  /// **'Painting'**
  String get painting;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @addDeduction.
  ///
  /// In en, this message translates to:
  /// **'Add deduction'**
  String get addDeduction;

  /// No description provided for @remindMeInTheApp.
  ///
  /// In en, this message translates to:
  /// **'Remind me in the app'**
  String get remindMeInTheApp;

  /// No description provided for @reminderAddedToNotificationsNoPhoneAlertWas.
  ///
  /// In en, this message translates to:
  /// **'Reminder added to notifications. No phone alert was sent.'**
  String get reminderAddedToNotificationsNoPhoneAlertWas;

  /// No description provided for @systemNotificationsAreOffSoNoReminderWas.
  ///
  /// In en, this message translates to:
  /// **'System notifications are off, so no reminder was added.'**
  String get systemNotificationsAreOffSoNoReminderWas;

  /// No description provided for @deductionsAreHigherThanTheDepositTheRefund.
  ///
  /// In en, this message translates to:
  /// **'Deductions are higher than the deposit. The refund shown is zero.'**
  String get deductionsAreHigherThanTheDepositTheRefund;

  /// No description provided for @enterADeductionInWholeRupees.
  ///
  /// In en, this message translates to:
  /// **'Enter a deduction in whole rupees.'**
  String get enterADeductionInWholeRupees;

  /// No description provided for @enterADeductionLabelAndAWholeRupee.
  ///
  /// In en, this message translates to:
  /// **'Enter a deduction label and a whole-rupee amount.'**
  String get enterADeductionLabelAndAWholeRupee;

  /// No description provided for @addARefundDueDateBeforeSettingA.
  ///
  /// In en, this message translates to:
  /// **'Add a refund due date before setting a reminder.'**
  String get addARefundDueDateBeforeSettingA;

  /// No description provided for @thatDepositRecordIsNotOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'That deposit record is not on this device.'**
  String get thatDepositRecordIsNotOnThisDevice;

  /// No description provided for @nameTheHomeIn3To80Characters.
  ///
  /// In en, this message translates to:
  /// **'Name the home in 3 to 80 characters.'**
  String get nameTheHomeIn3To80Characters;

  /// No description provided for @signInBeforeOpeningYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in before opening your profile.'**
  String get signInBeforeOpeningYourProfile;

  /// No description provided for @profileActivityCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Profile activity could not be loaded.'**
  String get profileActivityCouldNotBeLoaded;

  /// No description provided for @signInBeforeUsingTools.
  ///
  /// In en, this message translates to:
  /// **'Sign in before using tools.'**
  String get signInBeforeUsingTools;

  /// No description provided for @theToolRequestFailedContactDetailsStayOff.
  ///
  /// In en, this message translates to:
  /// **'The tool request failed. Contact details stay off this screen.'**
  String get theToolRequestFailedContactDetailsStayOff;

  /// No description provided for @photoUploadWasRefusedTheInventoryPhotosPolicies.
  ///
  /// In en, this message translates to:
  /// **'Photo upload was refused. The inventory-photos policies are not installed on this project yet.'**
  String get photoUploadWasRefusedTheInventoryPhotosPolicies;

  /// No description provided for @theInventoryPhotosBucketIsMissingOnThis.
  ///
  /// In en, this message translates to:
  /// **'The inventory-photos bucket is missing on this project.'**
  String get theInventoryPhotosBucketIsMissingOnThis;

  /// No description provided for @supportForThisFoundationBuildIsTheProject2.
  ///
  /// In en, this message translates to:
  /// **'Support for this foundation build is the project owner. In-app notifications are for matches, messages, visits, and deposit reminders. They are not a support inbox.'**
  String get supportForThisFoundationBuildIsTheProject2;

  /// No description provided for @doNotShareAnOTPAndDoNot.
  ///
  /// In en, this message translates to:
  /// **'Do not share an OTP, and do not move money before you have met or verified the home through a channel you trust.'**
  String get doNotShareAnOTPAndDoNot;

  /// No description provided for @meetInAPublicPlaceFirstAVisit.
  ///
  /// In en, this message translates to:
  /// **'Meet in a public place first. A visit time in HOMIZI is not a street address.'**
  String get meetInAPublicPlaceFirstAVisit;

  /// No description provided for @keepTheConversationInTheMatchChatThe.
  ///
  /// In en, this message translates to:
  /// **'Keep the conversation in the match chat. The chat refuses a phone number or an email address.'**
  String get keepTheConversationInTheMatchChatThe;

  /// No description provided for @aDepositTrackerOnlyRemindsYouInsideThe.
  ///
  /// In en, this message translates to:
  /// **'A deposit tracker only reminds you inside the app. It does not transfer money.'**
  String get aDepositTrackerOnlyRemindsYouInsideThe;

  /// No description provided for @aMatchAMessageAVisitAListing.
  ///
  /// In en, this message translates to:
  /// **'A match, a message, a visit, a listing like, or a deposit reminder. The row stores ids only. It never includes a phone number, an email address, or a street address. Marking one read updates that timestamp and nothing else.'**
  String get aMatchAMessageAVisitAListing;

  /// No description provided for @paymentsAreNotSupportedThereIsNoCheckout.
  ///
  /// In en, this message translates to:
  /// **'Payments are not supported. There is no checkout, and the client cannot mark a plan as paid. HOMIZI does not collect rent, a deposit, or a fee.'**
  String get paymentsAreNotSupportedThereIsNoCheckout;

  /// No description provided for @doesARentReceiptMoveMoney.
  ///
  /// In en, this message translates to:
  /// **'Does a rent receipt move money?'**
  String get doesARentReceiptMoveMoney;

  /// No description provided for @noTheReceiptToolWritesDownAPayment.
  ///
  /// In en, this message translates to:
  /// **'No. The receipt tool writes down a payment you already made outside HOMIZI and saves it on your account so you can download the PDF again.'**
  String get noTheReceiptToolWritesDownAPayment;

  /// No description provided for @isTheRentAgreementRegistered.
  ///
  /// In en, this message translates to:
  /// **'Is the rent agreement registered?'**
  String get isTheRentAgreementRegistered;

  /// No description provided for @noTheAgreementToolFillsAn11Month.
  ///
  /// In en, this message translates to:
  /// **'No. The agreement tool fills an 11-month leave-and-licence draft. The PDF says it is not stamped or registered. HOMIZI does not e-stamp or deliver a signed copy.'**
  String get noTheAgreementToolFillsAn11Month;

  /// No description provided for @howDoesTheRentSplitWork.
  ///
  /// In en, this message translates to:
  /// **'How does the rent split work?'**
  String get howDoesTheRentSplitWork;

  /// No description provided for @enterTheRentDepositMaintenanceAndUtilitiesThen.
  ///
  /// In en, this message translates to:
  /// **'Enter the rent, deposit, maintenance, and utilities, then a weight for each room. A larger room can take a higher weight. The shares add back to the amounts you entered. An optional income shows whether the household housing cost is comfortable, a stretch, or above a third of take-home.'**
  String get enterTheRentDepositMaintenanceAndUtilitiesThen;

  /// No description provided for @whoCanSeeAMoveInChecklist.
  ///
  /// In en, this message translates to:
  /// **'Who can see a move-in checklist?'**
  String get whoCanSeeAMoveInChecklist;

  /// No description provided for @youCanIfYouLinkAMatchThe.
  ///
  /// In en, this message translates to:
  /// **'You can. If you link a match, the other person on that match can read the rooms, notes, and photos. They cannot edit them.'**
  String get youCanIfYouLinkAMatchThe;

  /// No description provided for @leaveBlankIfYouDoNotHaveIt.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if you do not have it'**
  String get leaveBlankIfYouDoNotHaveIt;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
