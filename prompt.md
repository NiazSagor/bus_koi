# Build MVP: Community-Driven Local Bus Tracker for Dhaka

## 1. Product Overview

Build a minimal mobile app for local bus commuters in Dhaka, Bangladesh.

The core idea is **community-driven, temporary bus tracking**.

The app does NOT have a predefined bus database.

A commuter who is waiting for a local bus can create or join a temporary community for that bus. Other commuters looking for the same bus join the same community instead of creating duplicate requests.

If someone is currently riding that bus and opens the app, they can see that people are waiting for the bus and voluntarily share their current location.

The people waiting for the bus are then notified and can see the latest passenger-reported location on a map.

### Core concept

> Demand comes from people waiting for a bus.
> Supply comes from people currently riding that bus.

The app should make it extremely easy for these two groups to connect.

---

# 2. Important Product Constraint

DO NOT build this as a conventional public transit app.

Do NOT assume we have:

* A predefined bus database
* Official bus routes
* Bus stops
* Bus schedules
* Bus operator APIs
* GPS hardware installed on buses
* Driver accounts
* Official transit data

The bus information is created dynamically by users.

For example:

A user searches/types:

> Bahon

If no active Bahon community exists:

> Create Bahon community

If one already exists:

> Join existing Bahon community

Multiple users searching for "Bahon" should join the same active community rather than creating duplicate communities.

---

# 3. Target Users

There are two primary roles.

## A. Waiting Passenger

Someone who wants to know where a specific bus currently is.

Example:

> "I'm at Farmgate waiting for Bahon."

They:

1. Search for the bus.
2. Join the temporary community.
3. Become part of the demand count.
4. Wait for someone on the bus to share their location.
5. Receive an alert when a location is reported.
6. View the latest location on a map.

## B. Passenger / Location Supplier

Someone who is currently riding that bus.

Example:

> "I'm currently on Bahon."

They:

1. Open the Bahon community.
2. See that people are waiting for the bus.
3. See the current demand.
4. Tap "I'm on this bus".
5. Give location permission.
6. Share their approximate/current location.
7. The people waiting receive the location update.

A person can transition between these roles.

For example:

Waiting for Bahon → boards Bahon → becomes a location supplier.

---

# 4. MVP Goals

The MVP should prove one thing:

> Can a group of commuters waiting for the same bus successfully attract another commuter who is riding that bus and receive a useful location update?

Keep everything else simple.

The MVP must include:

* English/Bengali language support
* Dynamic bus/community creation
* Community joining
* Demand count
* Active member presence
* Passenger location sharing
* Real-time location updates
* Map display
* Notifications/in-app alerts
* Temporary community lifecycle
* Basic privacy protection
* No permanent bus database
* No authentication complexity unless technically required

Do NOT build advanced features unless necessary for the MVP.

---

# 5. Recommended Technology

Build the mobile application using:

* Flutter
* Dart
* Android + iOS
* Supabase
* PostgreSQL
* Supabase Realtime
* Supabase Edge Functions where needed
* Google Maps or another suitable map provider
* Flutter localization / ARB-based localization
* Provider for state management
* MVVM architecture
* Feature-based project structure

The architecture should keep the UI independent from Supabase implementation details.

The backend is the source of truth.

The mobile application is primarily a renderer/controller for backend state.

---

# 6. Project Structure

Use a clean feature-based structure similar to:

lib/

```
core/
    constants/
    theme/
    localization/
    routing/
    services/
    utils/

features/
    home/
        data/
        domain/
        presentation/

    community/
        data/
        domain/
        presentation/

    map/
        data/
        domain/
        presentation/

    settings/
        data/
        domain/
        presentation/

shared/
    widgets/
    models/

main.dart
```

Use MVVM.

Avoid overengineering the domain layer for the MVP, but keep clear separation between:

* UI
* ViewModel
* Repository
* Supabase/API implementation

---

# 7. Main User Flow

## Step 1 — Home

The user opens the app.

Display:

> Where is your bus?

Search field:

> Search bus name...

Example suggestions may be based only on currently active communities.

Do NOT show a permanent list of all buses.

If active communities exist:

Bahon
Hanif
Shikor

These are simply currently active communities.

---

# 8. Create / Join Community

When the user searches:

> Bahon

The backend should normalize the input and determine whether an active community already exists.

If an active community exists:

Show:

> Bahon

> 12 people are waiting

Button:

> Join Community

If no active community exists:

Show:

> No active community found.

Button:

> Start a Community

After creation, the user automatically joins it.

---

# 9. Community Screen

This is the most important screen.

It should visually resemble a simple Google Maps-style screen.

Top:

> Bahon

Then map.

Below/overlay:

> 🟢 12 people are waiting

If a passenger is currently sharing:

> 📍 Passenger location updated 35 seconds ago

Primary actions:

> Notify me

and:

> I'm on this bus

The interface should make the distinction between demand and supply obvious.

---

# 10. Demand Model

Do NOT treat every search as demand.

A user becomes active demand only after joining the community.

For example:

100 people search Bahon.

Only 8 actually join.

Demand = 8.

If someone leaves the community, their active demand should eventually disappear.

However, do NOT immediately delete their demand when they briefly close the map.

Use an active presence/heartbeat system.

For example:

* User joins community.
* Client sends heartbeat periodically.
* Backend tracks last_seen.
* If heartbeat becomes stale, user becomes inactive.
* Active demand count decreases.

Use a reasonable timeout such as 2–5 minutes for the MVP.

Make the timeout configurable from one central constant.

---

# 11. Temporary Community Lifecycle

Communities are temporary.

Lifecycle:

ACTIVE → DORMANT → DELETED

Example:

Bahon

15 active users

↓

8 active users

↓

0 active users

↓

DORMANT

↓

If nobody returns within configured TTL

↓

DELETE

A dormant community should not immediately disappear.

This prevents accidental destruction when users temporarily close the app.

For the MVP, use a configurable TTL such as:

30 minutes / 1 hour

Do not hard-code this throughout the application.

---

# 12. Data Deletion

When a community is permanently deleted:

Delete:

* Community record
* Active membership records
* Location reports
* Temporary presence data
* Temporary notification subscriptions

The goal is that inactive communities do not become a permanent historical bus database.

However, structure the code so retention policies can be changed later.

---

# 13. Location Supplier Flow

When a user taps:

> I'm on this bus

Show a confirmation:

> Are you currently riding Bahon?

Buttons:

> Yes, share my location

> Cancel

Then request location permission.

After permission is granted:

Start location sharing.

Display:

> You're helping 12 people find Bahon.

This messaging is important.

The supplier should understand that they are helping other commuters.

---

# 14. Location Sharing

Do not continuously upload GPS at an unnecessarily high frequency.

For MVP, use a reasonable interval/distance threshold.

Example:

* Send location every 15–30 seconds OR
* Send when location changes by a meaningful distance.

Make these values configurable.

Each location report should contain approximately:

* community_id
* supplier_id
* latitude
* longitude
* accuracy
* timestamp

Do not expose the supplier's personal identity.

The map should show something like:

> Passenger reported location

rather than:

> Niaz is here

---

# 15. Important Location Privacy Rule

Do NOT store precise historical movement unnecessarily.

The product only needs the latest useful location.

For MVP, prefer:

community

→ latest passenger location

rather than:

community

→ complete passenger movement history

When a new location arrives, the previous location can be replaced.

This keeps the system simpler and safer.

---

# 16. Location Accuracy

Never claim:

> The bus is exactly here.

The location comes from a passenger's phone.

Display language such as:

> Passenger reported this location

or:

> Last reported 40 seconds ago

The map marker should represent a **reported bus location**, not an officially verified bus position.

If GPS accuracy is poor, consider showing an accuracy radius.

---

# 17. Supplier Demand View

When a supplier opens a community, show the demand prominently.

Example:

> 🚌 Bahon

> 14 people are waiting for this bus.

> Your location could help them.

Button:

> Share my location

This is the main incentive mechanism.

The app should NOT force passengers to share.

Sharing must always be voluntary.

---

# 18. Multiple Suppliers

There may be multiple people riding the same bus.

Example:

> Bahon

> 17 people waiting

> 3 passengers sharing location

The system should allow multiple suppliers.

The map can display the latest valid report.

For MVP, select the freshest valid location as the primary location.

If multiple recent locations exist and they are close together, the UI may display:

> 3 passenger reports

Do not attempt complicated bus identity verification in the MVP.

---

# 19. Supplier Expiration

A supplier may stop sharing.

For example:

Someone gets off the bus.

Therefore location sharing should automatically expire.

Possible MVP rule:

If no new location has been received for X minutes:

> Location sharing ended

The user can start sharing again.

The app should not assume someone remains on the bus forever.

---

# 20. Notifications

Waiting users should receive an alert when a fresh passenger location becomes available.

Example English:

> 🚌 Bahon location updated

> A passenger just reported the bus location.

Bengali:

> 🚌 বাহনের অবস্থান আপডেট হয়েছে

> একজন যাত্রী বাসটির অবস্থান শেয়ার করেছেন।

For MVP, notification can also be an in-app alert if push notification setup would slow development.

However, design the architecture so push notifications can be added cleanly.

---

# 21. English + Bengali

The entire app must support both:

* English
* বাংলা

Do NOT mix languages randomly.

All user-facing strings must come from localization resources.

Example:

English:

> Where is your bus?

Bengali:

> আপনার বাস কোথায়?

English:

> 12 people are waiting

Bengali:

> ১২ জন অপেক্ষা করছেন

English:

> I'm on this bus

Bengali:

> আমি এই বাসে আছি

English:

> Share my location

Bengali:

> আমার অবস্থান শেয়ার করুন

English:

> Notify me

Bengali:

> আমাকে জানাবেন

English:

> Last reported 2 minutes ago

Bengali:

> সর্বশেষ ২ মিনিট আগে জানানো হয়েছে

Use proper Bengali typography and natural Bangladeshi wording.

Avoid literal machine translations.

Provide a language switch in Settings.

Default language can follow the device language, with English as fallback.

---

# 22. Bengali Bus Names

Users may type the same bus using different scripts.

For example:

Bahon

বাহন

Bahon Bus

বাহন বাস

The system should normalize search input enough to reduce obvious duplicates.

However, do NOT build a complicated NLP system for MVP.

Create a simple normalization layer that can later be improved.

Potential normalized fields:

display_name
normalized_name

Example:

display_name = "Bahon"

normalized_name = "bahon"

The community's original display name can be preserved.

---

# 23. No Permanent Bus Database

This is a critical requirement.

Do NOT create a seeded database such as:

buses:

1. Bahon
2. Hanif
3. Shikor
4. BRTC

The database should initially contain only active user-created communities.

If nobody is using:

> Bahon

there does not need to be a permanent Bahon record.

A community is created when demand appears.

---

# 24. Suggested Database Schema

Use PostgreSQL/Supabase.

## communities

id
display_name
normalized_name
status
created_at
last_active_at
expires_at

status:

ACTIVE
DORMANT

## community_members

id
community_id
anonymous_user_id
role
joined_at
last_seen_at
is_active

role can be:

WAITING
SUPPLIER

A user can switch roles.

## location_reports

id
community_id
supplier_id
latitude
longitude
accuracy
reported_at
expires_at

For MVP, only retain the latest useful location per supplier/community if possible.

## notification_subscriptions

id
community_id
anonymous_user_id
created_at
last_seen_at

Only create additional tables when genuinely required.

---

# 25. Anonymous User Identity

Authentication should be as frictionless as possible.

For MVP, prefer anonymous authentication or an installation-level anonymous ID.

A user should be able to:

* open app
* search bus
* join community
* receive updates

without creating a complicated account.

However, design the system so real authentication can be added later.

Do not expose anonymous IDs to other users.

---

# 26. Map UI

The community screen should prioritize the map.

Approximate layout:

---

Bahon                         🔔

---

```
            MAP

          📍
    Passenger report
```

---

🟢 12 people are waiting

Last reported 38 seconds ago

[ 🔔 Notify me ]

[ 🚌 I'm on this bus ]

---

Keep it minimal.

Do not add unnecessary route lines because the app does not know the official route.

Do not invent bus stops.

Do not draw fake routes.

---

# 27. User Presence

A user should be considered active when:

* They joined the community
* Their last heartbeat is within the configured timeout
* They have not explicitly left

If they leave the community:

* Remove them from active demand
* Stop notifications
* Stop location sharing if they are a supplier

If they simply background the app:

* Allow a grace period
* Then mark them inactive

---

# 28. Leaving the Community

Provide:

> Leave Community

After leaving:

* User is no longer counted as demand
* User stops receiving community notifications
* If supplier, location sharing stops
* User can rejoin later

Do not delete the community immediately.

The community lifecycle is controlled by backend activity.

---

# 29. Empty Community Behavior

If there are no active users:

The community eventually becomes dormant.

Do not show stale communities indefinitely.

If dormant beyond TTL:

Delete it.

This ensures the app does not slowly become a permanent database of thousands of dead bus names.

---

# 30. Error States

Handle:

### No Internet

> You're offline. Reconnect to see live updates.

### Location permission denied

> Location access is needed to share your location with other commuters.

### GPS unavailable

> We couldn't get an accurate location.

### Community expired

> This community is no longer active.

Button:

> Start again

### No active community

> Nobody is currently looking for this bus.

Button:

> Start Community

### No location supplier

> No passenger has shared a location yet.

This should NOT look like an error.

It's simply:

> Waiting for someone on the bus.

---

# 31. Core Product Metrics

Do not build a complex analytics system yet.

But structure the code so these metrics could eventually be measured:

1. Communities created
2. Communities with multiple users
3. Average active users per community
4. Number of supplier appearances
5. Number of successful location reports
6. Time from community creation → first supplier
7. Percentage of communities receiving a location report
8. Average community lifetime

The most important MVP metric is:

> **How often does demand successfully attract supply?**

---

# 32. Anti-Abuse Considerations

Do not overbuild this in MVP.

But prepare basic safeguards.

Potential abuse:

* Fake location reports
* Someone pretending to be on a bus
* Spam community creation
* Excessive location updates

Basic protections:

* Rate-limit community creation
* Rate-limit location updates
* Ignore obviously invalid GPS data
* Expire stale supplier reports
* Do not expose user identity
* Do not allow arbitrary users to permanently track another person

Do not attempt sophisticated fraud detection yet.

---

# 33. Important UX Principle

The app should never feel like:

> "Please contribute data to our database."

Instead:

For waiting passenger:

> **People like you are waiting for this bus.**

For passenger:

> **14 people are waiting. You can help them.**

This human-to-human interaction is the core of the product.

---

# 34. MVP Screens

Build only these screens:

### 1. Home

* Search bus
* Active communities
* Language switch

### 2. Search Results

* Matching active communities
* Number of active people waiting
* Join/start option

### 3. Community / Map

* Map
* Current demand
* Latest reported location
* Supplier status
* Join/leave
* Notify me
* I'm on this bus

### 4. Supplier Mode

* Current sharing state
* Number of people waiting
* Start/stop location sharing
* Location status

### 5. Settings

* Language
* Basic privacy information
* About

No profile system in MVP.

---

# 35. Visual Design

Use a clean, modern mobile UI.

The app should feel:

* Fast
* Lightweight
* Trustworthy
* Local
* Community-driven

Avoid:

* Excessive gradients
* Gamification
* Social media profiles
* Leaderboards
* Complex dashboards
* Too many buttons
* Excessive animations

The map and current demand should dominate the experience.

---

# 36. Backend Realtime Architecture

Use Supabase Realtime for:

* Community membership changes
* Demand count changes
* Supplier status changes
* New location reports

The client should react to backend changes instead of repeatedly polling.

Example:

User A:

> Join Bahon

Backend:

> active_members = 1

User B:

> Join Bahon

Realtime:

> active_members = 2

Supplier:

> Start sharing

Realtime:

> latest_location updated

Waiting users:

> Map marker moves

---

# 37. Security

Use Supabase Row Level Security.

Users should only be able to:

* Read active communities
* Join active communities
* Update their own membership
* Submit their own location
* Read location information associated with communities they belong to

Never allow arbitrary users to modify another user's location.

Do not expose unnecessary user information.

---

# 38. Development Order

Implement in this order:

## Phase 1

Create Flutter project.

Set up:

* Architecture
* Theme
* Localization
* Routing
* Supabase connection

## Phase 2

Implement:

* Anonymous identity
* Community creation
* Community search
* Join/leave

## Phase 3

Implement:

* Active member presence
* Heartbeat
* Demand count

## Phase 4

Implement:

* Map
* Location permission
* Supplier mode
* Location reporting

## Phase 5

Implement:

* Supabase Realtime
* Live location updates
* Supplier expiration

## Phase 6

Implement:

* Notifications/in-app alerts
* Community expiration

## Phase 7

Polish:

* Bengali translations
* Empty states
* Error handling
* Loading states
* Permission flows

---

# 39. Testing Scenarios

The MVP must be testable with multiple phones/emulators.

### Scenario A

Phone A:

> Search Bahon

Create community.

Phone B:

> Search Bahon

Join community.

Expected:

> 2 people waiting

### Scenario B

Phone C:

Join Bahon.

Tap:

> I'm on this bus

Share location.

Expected:

Phones A and B receive the location.

### Scenario C

Phone C stops sharing.

Expected:

Location eventually becomes stale/expired.

### Scenario D

Phone A leaves.

Expected:

Demand decreases.

### Scenario E

Everyone leaves.

Expected:

Community becomes dormant.

After TTL:

Community is deleted.

### Scenario F

Someone searches Bahon after deletion.

Expected:

A new temporary Bahon community can be created.

---

# 40. Do Not Build These Features

Explicitly avoid these in MVP:

* Official bus routes
* Bus schedules
* Driver accounts
* Bus company accounts
* Permanent bus database
* Ticket booking
* Fare calculation
* Payments
* Chat
* User profiles
* Followers
* Social feed
* Ratings
* Gamification
* Advertising
* AI chatbot
* Route prediction
* ETA prediction
* Machine learning
* Historical bus analytics
* Complex moderation system

The MVP is about one thing:

> **Waiting passengers finding a passenger who is currently on their bus.**

---

# 41. Definition of Done

The MVP is complete when this scenario works end-to-end:

1. User A opens the app.

2. User A types "Bahon".

3. User A creates a temporary Bahon community.

4. User B searches "Bahon".

5. User B joins the same community.

6. App displays:

   > 2 people are waiting.

7. User C searches "Bahon".

8. User C joins and selects:

   > I'm on this bus.

9. User C grants location permission.

10. User C starts sharing location.

11. User A and B see the passenger-reported location on the map.

12. A/B receive an update.

13. User C's location automatically becomes stale when sharing stops.

14. A/B can leave.

15. When nobody remains, the community eventually becomes dormant.

16. After the configured TTL, the backend deletes the temporary community and its temporary location data.

17. A new user can later create a completely new Bahon community.

This end-to-end flow is the primary success criterion.

---

# 42. Product Philosophy

Remember throughout development:

This is NOT:

> "Let's build a database of Dhaka buses."

It is:

> **"Let's connect people who are waiting for a bus with people who are already on that bus."**

The temporary community is the product.

The bus name is only the identifier that connects the two groups.

Demand creates visibility.

Visibility attracts supply.

Supply creates useful real-time information.

When demand disappears, the community disappears.

Keep the implementation minimal and validate this loop before adding anything else.
