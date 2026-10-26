# VakilSetu — Firebase Mock Data & Setup Guide

This guide contains the exact collections, document IDs, field names, **exact Firestore data types (matching Firebase Console dropdowns)**, and sample values to populate in your **Firebase Cloud Firestore** database.

---

## ⚡ Option 1: Automatic Seeding (Zero Manual Work)

You do **not** need to manually type everything if you don't want to!
When you launch the VakilSetu app:
1. [`FirestoreCourtRepository`](lib/features/court_channels/data/firestore_court_repository.dart) checks if the `courts` collection is empty.
2. If empty, it **automatically creates and populates all 6 Delhi courts and verified announcements** directly into your Firebase Firestore with correct types.

---

## 🛠️ Option 2: Manual Setup in Firebase Console

Open [Firebase Console](https://console.firebase.google.com/) > Select **vakilsetu-3fda2** > **Firestore Database**.

When adding fields in Firebase Console, select the **Type** from the dropdown as specified in the tables below.

---

### Collection 1: `courts`

Click **Start collection** > Collection ID: `courts`

#### Document 1: `delhi_high_court`
- **Document ID**: `delhi_high_court`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `delhi_high_court` | Unique identifier |
| `channelId` | `string` | `delhi_high_court` | Channel ID |
| `name` | `string` | `Delhi High Court` | Display title |
| `city` | `string` | `New Delhi` | Location |
| `imageKey` | `string` | `assets/images/courts/delhi_high_court_list.png` | Local asset / image URL |
| `order` | `number` | `1` | Integer for display sorting |
| `isVerified` | `boolean` | `true` | Verification badge flag |
| `membersCount` | `number` | `240` | Total joined advocates |
| `createdAt` | `timestamp` | *(Select current date/time)* | Document creation time |

---

#### Document 2: `saket_district_court`
- **Document ID**: `saket_district_court`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `saket_district_court` | Unique identifier |
| `channelId` | `string` | `saket_district_court` | Channel ID |
| `name` | `string` | `Saket District Court` | Display title |
| `city` | `string` | `South Delhi` | Location |
| `imageKey` | `string` | `assets/images/courts/saket_district_court_list.png` | Asset key |
| `order` | `number` | `2` | Sort order |
| `isVerified` | `boolean` | `true` | Verified |
| `membersCount` | `number` | `185` | Member count |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

#### Document 3: `tis_hazari_courts`
- **Document ID**: `tis_hazari_courts`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `tis_hazari_courts` | Unique identifier |
| `channelId` | `string` | `tis_hazari_courts` | Channel ID |
| `name` | `string` | `Tis Hazari Courts` | Display title |
| `city` | `string` | `Central Delhi` | Location |
| `imageKey` | `string` | `assets/images/courts/tis_hazari_courts.png` | Asset key |
| `order` | `number` | `3` | Sort order |
| `isVerified` | `boolean` | `true` | Verified |
| `membersCount` | `number` | `310` | Member count |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

#### Document 4: `patiala_house_courts`
- **Document ID**: `patiala_house_courts`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `patiala_house_courts` | Unique identifier |
| `channelId` | `string` | `patiala_house_courts` | Channel ID |
| `name` | `string` | `Patiala House Courts` | Display title |
| `city` | `string` | `New Delhi` | Location |
| `imageKey` | `string` | `assets/images/courts/patiala_house_courts.png` | Asset key |
| `order` | `number` | `4` | Sort order |
| `isVerified` | `boolean` | `true` | Verified |
| `membersCount` | `number` | `145` | Member count |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

#### Document 5: `karkardooma_courts`
- **Document ID**: `karkardooma_courts`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `karkardooma_courts` | Unique identifier |
| `channelId` | `string` | `karkardooma_courts` | Channel ID |
| `name` | `string` | `Karkardooma Courts` | Display title |
| `city` | `string` | `East Delhi` | Location |
| `imageKey` | `string` | `assets/images/courts/delhi_high_court.png` | Asset key |
| `order` | `number` | `5` | Sort order |
| `isVerified` | `boolean` | `true` | Verified |
| `membersCount` | `number` | `98` | Member count |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

#### Document 6: `rohini_district_court`
- **Document ID**: `rohini_district_court`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `rohini_district_court` | Unique identifier |
| `channelId` | `string` | `rohini_district_court` | Channel ID |
| `name` | `string` | `Rohini District Court` | Display title |
| `city` | `string` | `North West Delhi` | Location |
| `imageKey` | `string` | `assets/images/courts/saket_district_court.png` | Asset key |
| `order` | `number` | `6` | Sort order |
| `isVerified` | `boolean` | `true` | Verified |
| `membersCount` | `number` | `120` | Member count |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

### Subcollection: `courts/{courtId}/announcements`

Inside a court document (for example click into `courts/delhi_high_court`), click **Start collection** > Collection ID: `announcements`.

#### Announcement 1 (Delhi High Court)
- **Document ID**: *(Click "Auto-ID")*
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `title` | `string` | `Daily Cause List - Court No. 1` | Notice headline |
| `body` | `string` | `Urgent admission matters listed before Chief Justice Bench. Hybrid hearings begin at 10:30 AM in Court Room 1.` | Content |
| `attachmentKey` | `string` | `Cause_list.pdf` | Attachment filename |
| `revision` | `number` | `1` | Revision number |
| `authorName` | `string` | `High Court Registry` | Publisher title |
| `createdAt` | `timestamp` | *(Select current date/time)* | Post timestamp |

---

#### Announcement 2 (Delhi High Court)
- **Document ID**: *(Click "Auto-ID")*
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `title` | `string` | `Roster of Sitting Judges - Winter Session` | Notice headline |
| `body` | `string` | `The revised roster for sitting Division Benches and Single Benches has been notified. Check cause list for courtroom allocations.` | Content |
| `attachmentKey` | `string` | `Roster_Sitting_Judges.pdf` | Attachment filename |
| `revision` | `number` | `1` | Revision number |
| `authorName` | `string` | `High Court Registry` | Publisher title |
| `createdAt` | `timestamp` | *(Select current date/time)* | Post timestamp |

---

#### Announcement 3 (Saket District Court)
- **Path**: `courts/saket_district_court/announcements`
- **Document ID**: *(Click "Auto-ID")*
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `title` | `string` | `Court Room Reallocation Notice` | Notice headline |
| `body` | `string` | `Court No. 304 presided by ADJ-02 is temporarily shifted to 4th Floor Room 412 due to electrical maintenance.` | Content |
| `attachmentKey` | `string` | `Relocation_Notice.pdf` | Optional attachment |
| `revision` | `number` | `1` | Revision number |
| `authorName` | `string` | `District Judge Secretariat` | Publisher title |
| `createdAt` | `timestamp` | *(Select current date/time)* | Post timestamp |

---

### Collection 2: `advocates` (Directory)

Click **Start collection** > Collection ID: `advocates`.

#### Document 1: `adv_meera`
- **Document ID**: `adv_meera`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `adv_meera` | Identifier |
| `fullName` | `string` | `Meera Sharma` | Name |
| `initials` | `string` | `MS` | Avatar initials |
| `enrollmentNumber` | `string` | `D/1842/2016` | Bar council number |
| `primaryCourt` | `string` | `Delhi High Court` | Court name |
| `primaryCourtId` | `string` | `delhi_high_court` | Matches court doc ID |
| `practiceAreas` | `string` | `Civil litigation · Arbitration` | Specialization |
| `experienceYears` | `number` | `8` | Number of years |
| `isVerified` | `boolean` | `true` | Verified badge |
| `email` | `string` | `meera.sharma@vakilsetu.in` | Email address |
| `bio` | `string` | `Specializing in commercial disputes and arbitration before Delhi High Court.` | Biography |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

#### Document 2: `adv_kabir`
- **Document ID**: `adv_kabir`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `adv_kabir` | Identifier |
| `fullName` | `string` | `Kabir Malhotra` | Name |
| `initials` | `string` | `KM` | Avatar initials |
| `enrollmentNumber` | `string` | `D/0921/2018` | Bar council number |
| `primaryCourt` | `string` | `Saket District Court` | Court name |
| `primaryCourtId` | `string` | `saket_district_court` | Matches court doc ID |
| `practiceAreas` | `string` | `Civil litigation · Family law` | Specialization |
| `experienceYears` | `number` | `6` | Number of years |
| `isVerified` | `boolean` | `true` | Verified badge |
| `email` | `string` | `kabir.malhotra@vakilsetu.in` | Email address |
| `bio` | `string` | `Matrimonial and civil disputes advocate at Saket and Patiala House Courts.` | Biography |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

#### Document 3: `adv_naina`
- **Document ID**: `adv_naina`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `adv_naina` | Identifier |
| `fullName` | `string` | `Naina Bansal` | Name |
| `initials` | `string` | `NB` | Avatar initials |
| `enrollmentNumber` | `string` | `D/2247/2019` | Bar council number |
| `primaryCourt` | `string` | `Tis Hazari Courts` | Court name |
| `primaryCourtId` | `string` | `tis_hazari_courts` | Matches court doc ID |
| `practiceAreas` | `string` | `Corporate law · Contracts` | Specialization |
| `experienceYears` | `number` | `5` | Number of years |
| `isVerified` | `boolean` | `true` | Verified badge |
| `email` | `string` | `naina.bansal@vakilsetu.in` | Email address |
| `bio` | `string` | `Corporate contracts, startup advisory and legal drafting.` | Biography |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

#### Document 4: `adv_rohit`
- **Document ID**: `adv_rohit`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `adv_rohit` | Identifier |
| `fullName` | `string` | `Rohit Verma` | Name |
| `initials` | `string` | `RV` | Avatar initials |
| `enrollmentNumber` | `string` | `D/1056/2015` | Bar council number |
| `primaryCourt` | `string` | `Patiala House Courts` | Court name |
| `primaryCourtId` | `string` | `patiala_house_courts` | Matches court doc ID |
| `practiceAreas` | `string` | `Criminal law · Appeals` | Specialization |
| `experienceYears` | `number` | `9` | Number of years |
| `isVerified` | `boolean` | `true` | Verified badge |
| `email` | `string` | `rohit.verma@vakilsetu.in` | Email address |
| `bio` | `string` | `Trial defense, bail applications, and criminal appellate matters.` | Biography |
| `createdAt` | `timestamp` | *(Select current date/time)* | Creation time |

---

### Collection 3: `users` (User Profile & Joined Courts)

Click **Start collection** > Collection ID: `users`.

#### Document: `test_advocate_1` (or your Firebase Auth UID)
- **Document ID**: `test_advocate_1`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `fullName` | `string` | `Arjun Kumar` | User display name |
| `enrollmentNumber` | `string` | `D/3421/2017` | Bar registration |
| `primaryCourtId` | `string` | `delhi_high_court` | User's main court |
| `joinedCourtIds` | `array` | `["delhi_high_court", "saket_district_court"]` | **Array of strings** (each item is `string`) |
| `isVerified` | `boolean` | `true` | Verified status |
| `updatedAt` | `timestamp` | *(Select current date/time)* | Last update timestamp |

> **Tip for `joinedCourtIds` in Firebase Console**:
> 1. Set type to `array`.
> 2. For item 0, select type `string`, enter value `delhi_high_court`.
> 3. Click **Add item**, select type `string`, enter value `saket_district_court`.

---

### Collection 3: `conversations` (Real-Time Chats & Groups)

Click **Start collection** > Collection ID: `conversations`

#### Document 1: Direct Conversation with Adv. Meera Sharma
- **Document ID**: `11111111-2222-3333-4444-555555555551`
- **Fields Table**:

| Field Name | Type (in Console) | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `11111111-2222-3333-4444-555555555551` | UUID / Document ID |
| `kind` | `string` | `direct` | `direct` or `privateGroup` |
| `title` | `string` | `Meera Sharma` | Display title |
| `memberIds` | `array` | `["current_user", "adv_meera"]` | Array of participant UIDs |
| `membershipEpoch` | `number` | `1` | Integer epoch |
| `lastMessagePreview` | `string` | `Let me know once you go through the clause 14 provisions.` | Preview string |
| `unreadCount` | `number` | `1` | Unread badge count |
| `createdAt` | `timestamp` | *(Select date/time)* | Created time |
| `lastMessageAt` | `timestamp` | *(Select date/time)* | Last message time |

##### Subcollection: `messages` inside `conversations/11111111-2222-3333-4444-555555555551/messages`
Click **Start collection** > Collection ID: `messages`

- **Document ID**: `msg_meera_1`
- **Fields**:

| Field Name | Type | Value |
| :--- | :--- | :--- |
| `id` | `string` | `msg_meera_1` |
| `conversationId` | `string` | `11111111-2222-3333-4444-555555555551` |
| `body` | `string` | `Hello Counsel, have you reviewed the commercial arbitration draft for Delhi High Court?` |
| `senderAccountId` | `string` | `adv_meera` |
| `senderName` | `string` | `Meera Sharma` |
| `recipientCount` | `number` | `1` |
| `deliveredCount` | `number` | `1` |
| `readCount` | `number` | `1` |
| `createdAt` | `timestamp` | *(Select date/time)* |

---

#### Document 2: Direct Conversation with Adv. Kabir Malhotra
- **Document ID**: `11111111-2222-3333-4444-555555555552`
- **Fields Table**:

| Field Name | Type | Value |
| :--- | :--- | :--- |
| `id` | `string` | `11111111-2222-3333-4444-555555555552` |
| `kind` | `string` | `direct` |
| `title` | `string` | `Kabir Malhotra` |
| `memberIds` | `array` | `["current_user", "adv_kabir"]` |
| `lastMessagePreview` | `string` | `Saket Court bench hearing is scheduled for tomorrow 10:30 AM.` |
| `unreadCount` | `number` | `0` |
| `createdAt` | `timestamp` | *(Select date/time)* |
| `lastMessageAt` | `timestamp` | *(Select date/time)* |

---

#### Document 3: Private Group "Delhi High Court Bar Association"
- **Document ID**: `11111111-2222-3333-4444-555555555553`
- **Fields Table**:

| Field Name | Type | Value |
| :--- | :--- | :--- |
| `id` | `string` | `11111111-2222-3333-4444-555555555553` |
| `kind` | `string` | `privateGroup` |
| `title` | `string` | `Delhi High Court Bar Association` |
| `memberIds` | `array` | `["current_user", "adv_meera", "adv_kabir", "adv_rohit"]` |
| `lastMessagePreview` | `string` | `Notice: The bar association meeting on digital filings is at 4 PM in library hall.` |
| `unreadCount` | `number` | `2` |
| `createdAt` | `timestamp` | *(Select date/time)* |
| `lastMessageAt` | `timestamp` | *(Select date/time)* |

---

### Collection 4: `attachments` (Shared Case Files & Evidence)
Click **Start collection** > Collection ID: `attachments`

| Field Name | Type | Value | Notes |
| :--- | :--- | :--- | :--- |
| `id` | `string` | `att_wp_1042_2026` | Unique ID |
| `conversationId` | `string` | `11111111-2222-3333-4444-555555555553` | Linked conversation |
| `conversationTitle`| `string` | `Delhi High Court Bar Association` | Channel or contact name |
| `filename` | `string` | `Petition_Draft_WP_1042_2026.pdf` | File name |
| `contentType` | `string` | `application/pdf` | MIME type |
| `byteSize` | `number` | `24580` | Size in bytes |
| `dataBase64` | `string` | *(Base64 encoded string)* | File content |
| `uploaderId` | `string` | `user_123` | ID of uploader |
| `createdAt` | `timestamp` | *(Select date/time)* | Upload time |

---

## 🧪 Testing in the App

1. **Test Real-Time Chat & Messaging**:
   - Tap the **Chats** tab.
   - You will see your real-time conversations connected directly to Firebase Cloud Firestore.
   - Tap on **Meera Sharma** or **Kabir Malhotra** or the **Delhi High Court Bar Association** group.
   - Type a message and tap **Send**.
   - The message is written to Firestore subcollection `conversations/{id}/messages` and the parent conversation's `lastMessagePreview` and `lastMessageAt` update immediately.
   - **Edit & Delete**: Long-press or tap a sent message to edit or delete it. The update reflects in Firestore in real time.
2. **Start Chat with Any Advocate**:
   - Go to the **Advocates** tab.
   - Tap the **"Message"** button on any advocate profile (e.g. Meera Sharma, Kabir Malhotra, Naina Bansal, etc.).
   - VakilSetu immediately checks Firestore for an existing direct conversation or automatically creates a new 1-on-1 direct conversation document in Firestore, opening the chat window ready for conversation.
3. **Test Private Groups**:
   - Go to the **Groups** tab.
   - View all your private bar and case groups loaded from Firestore.
   - Tap **"Create Group"** (or floating button), give it a title, select advocates, and tap Create.
   - The group conversation document is instantly created in Firestore.
4. **View Real-Time Courts**:
   - Open the **Court Rooms** tab.
   - The courts from Firestore load with their photos, locations, and member badges.
5. **Test Real-Time Announcements**:
   - Tap on **Delhi High Court**.
   - Tap the **"Post Notice"** button at the top right.
   - Enter a title and details, then tap **"Publish to Firestore"**.
   - Watch it appear on screen instantly via Firestore snapshot streams!
6. **Test Joined Subscriptions**:
   - Tap **"Join"** / **"Joined"** on any court card.
   - In Firebase Console, observe the `joinedCourtIds` array in `users` and `membersCount` in `courts` updating in real time.
7. **Test Firebase Email/Password Login & Register**:
   - On the **Login** screen, enter any email (e.g., `advocate@vakilsetu.in`) and a password (minimum 6 characters).
   - Tap **"Sign In / Register with Email"**.
   - If the user doesn't exist yet in Firebase Auth, it automatically creates the account in Firebase Authentication and syncs the user into Cloud Firestore!
   - You can also tap **"Continue as Guest / Explore Demo"** to jump in instantly without credentials.
8. **Test Advocate Profile & Log Out**:
   - Tap your initials avatar (`AK`) in the top right header to open your Profile.
   - Edit personal details or tap **"Log Out"** at the bottom to sign out from Firebase.
