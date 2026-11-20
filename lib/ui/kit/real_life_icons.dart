import 'package:flutter/material.dart';

/// Recognisable Material icons for everyday home choices.
///
/// The glyphs ship with Flutter (`uses-material-design`). Nothing is loaded
/// from the network. Other screens can share [byName] without copying the set.
abstract final class RealLifeIcons {
  static const house = Icons.home_outlined;
  static const pg = Icons.night_shelter_outlined;
  static const masterRoom = Icons.king_bed;
  static const privateRoom = Icons.bed_outlined;
  static const sharedRoom = Icons.groups_outlined;
  static const wallet = Icons.account_balance_wallet_outlined;
  static const metro = Icons.subway_outlined;
  static const bus = Icons.directions_bus_outlined;
  static const office = Icons.apartment;
  static const hospital = Icons.local_hospital_outlined;
  static const school = Icons.school_outlined;
  static const pets = Icons.pets;
  static const veg = Icons.eco_outlined;
  static const nonVeg = Icons.restaurant_outlined;
  static const smoking = Icons.smoking_rooms;
  static const noSmoking = Icons.smoke_free;
  static const parking = Icons.local_parking;
  static const lift = Icons.elevator_outlined;
  static const gym = Icons.fitness_center;
  static const wifi = Icons.wifi;
  static const ac = Icons.ac_unit;
  static const powerBackup = Icons.battery_charging_full;
  static const security = Icons.security;
  static const laundry = Icons.local_laundry_service;
  static const fridge = Icons.kitchen;
  static const cook = Icons.restaurant_menu;
  static const cleaning = Icons.cleaning_services;
  static const more = Icons.more_horiz;
  static const man = Icons.man;
  static const woman = Icons.woman;
  static const inclusive = Icons.diversity_3_outlined;
  static const walk = Icons.directions_walk;
  static const bike = Icons.pedal_bike;
  static const car = Icons.directions_car_outlined;
  static const calendar = Icons.calendar_month_outlined;
  static const soon = Icons.bolt;
  static const flexible = Icons.schedule;
  static const event = Icons.event;
  static const today = Icons.today;
  static const fortnight = Icons.date_range;
  static const work = Icons.work_outline;
  static const couple = Icons.favorite_border;
  static const family = Icons.family_restroom;
  static const furnished = Icons.chair_outlined;
  static const unfurnished = Icons.meeting_room_outlined;
  static const guests = Icons.group_outlined;
  static const drink = Icons.local_bar;
  static const noDrink = Icons.not_interested;
  static const locality = Icons.location_city_outlined;
  static const bathroom = Icons.bathtub_outlined;
  static const sharedBath = Icons.wc;
  static const tune = Icons.tune;
  static const shield = Icons.shield_outlined;
  static const person = Icons.person_outline;
  static const badge = Icons.badge_outlined;
  static const briefcase = Icons.business_center_outlined;
  static const pin = Icons.location_on_outlined;
  static const freelancer = Icons.laptop_mac_outlined;
  static const phone = Icons.smartphone_outlined;
  static const mail = Icons.mail_outline;
  static const chat = Icons.chat_bubble_outline;
  static const document = Icons.description_outlined;
  static const language = Icons.translate;
  static const summary = Icons.fact_check_outlined;
  static const lifestyle = Icons.favorite_outline;

  static const Map<String, IconData> byName = <String, IconData>{
    'house': house,
    'pg': pg,
    'masterRoom': masterRoom,
    'privateRoom': privateRoom,
    'sharedRoom': sharedRoom,
    'wallet': wallet,
    'metro': metro,
    'bus': bus,
    'office': office,
    'hospital': hospital,
    'school': school,
    'pets': pets,
    'veg': veg,
    'nonVeg': nonVeg,
    'smoking': smoking,
    'noSmoking': noSmoking,
    'parking': parking,
    'lift': lift,
    'gym': gym,
    'wifi': wifi,
    'ac': ac,
    'powerBackup': powerBackup,
    'security': security,
    'laundry': laundry,
    'fridge': fridge,
    'cook': cook,
    'cleaning': cleaning,
    'man': man,
    'woman': woman,
    'inclusive': inclusive,
    'walk': walk,
    'bike': bike,
    'car': car,
    'calendar': calendar,
    'work': work,
    'couple': couple,
    'family': family,
    'furnished': furnished,
    'bathroom': bathroom,
    'locality': locality,
    'petsAllowed': pets,
    'person': person,
    'badge': badge,
    'briefcase': briefcase,
    'pin': pin,
    'freelancer': freelancer,
    'phone': phone,
    'mail': mail,
  };

  static IconData? named(String name) => byName[name];
}
