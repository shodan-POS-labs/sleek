# Sleek POS — Testing Workflow

> **Seeded Accounts**
>
> | Shop | Type | Email | Password | Admin PIN | Cashier PIN |
> |---|---|---|---|---|---|
> | MediCare Pharmacy | Pharmacy | somapalagalagedara@gmail.com | Test@1234 | 123456 | 654321 |
> | Spice Garden Restaurant | Restaurant | dingiribanda125@gmail.com | Test@1234 | 123456 | 654321 |
> | FreshMart Grocery | Retail | pabasaraf79@gmail.com | Test@1234 | 123456 | 654321 |
>
> Each shop also has a **cashier** account (nimal.pharmacy@test.com / sunil.restaurant@test.com / kamal.retail@test.com).

---

## 0. Prerequisites — Seed the Database

1. Place your Firebase service account key as `seeder/serviceAccountKey.json`
   (Firebase Console → Project Settings → Service accounts → Generate new private key).
2. In a terminal:
   ```bash
   cd seeder
   npm install
   npm run seed
   ```
3. Wait for completion (~1–2 min). You'll see a log confirming all 3 shops were created.
4. Open the app and proceed to testing with the seeded accounts.

> **Tip:** If any Firebase Auth user already exists, the seeder reuses it automatically.

---

## 1. Authentication Flow

### 1.1 Email Login
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Open app → tap **Login with Email** | Email/password form appears |
| 2 | Enter `somapalagalagedara@gmail.com` / `Test@1234` → tap Login | Redirects to dashboard showing **MediCare Pharmacy** |
| 3 | Log out and repeat for `dingiribanda125@gmail.com` | Dashboard shows **Spice Garden Restaurant** |
| 4 | Repeat for `pabasaraf79@gmail.com` | Dashboard shows **FreshMart Grocery** |

### 1.2 PIN Login
| # | Step | Expected Result |
|---|------|----------------|
| 1 | After email login, log out | PIN login screen appears (since session exists) |
| 2 | Enter admin PIN `123456` | Logs in successfully to same shop |
| 3 | Enter wrong PIN `000000` | Shows error "Invalid PIN" |

### 1.3 Cashier Login
| # | Step | Expected Result |
|---|------|----------------|
| 1 | On PIN screen, enter cashier PIN `654321` | Logs in as cashier — Settings should not show "Management" section |

### 1.4 Biometric (if device supports)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Profile → Toggle "Enable Biometric Login" | Biometric prompt appears on next PIN screen |

---

## 2. Dashboard

| # | Step | Expected Result |
|---|------|----------------|
| 1 | Login as Pharmacy admin | Dashboard cards show: Today's Sales, Products, Low Stock, Credit Customers |
| 2 | Verify "Today's Sales" card | Shows sum of sales created today (may be Rs. 0 if no sales today from seed) |
| 3 | Verify "Products" count | Shows **16** (seeded pharmacy products) |
| 4 | Verify "Low Stock" | Shows count of products with stock ≤ 10 (Insulin Pen Needle = 3, Diaper Cream = 8) |
| 5 | Verify "Recent Sales" list | Shows the 5 most recent sales with invoice numbers |
| 6 | Pull down to refresh | Data refreshes |
| 7 | Repeat for Restaurant | Cards adapt — no "Low Stock" since restaurant has no stock management |
| 8 | Repeat for Retail | Cards show retail-specific labels |

---

## 3. Products / Menu Items / Services

### 3.1 View Products
| # | Step | Expected Result |
|---|------|----------------|
| 1 | **Pharmacy:** Navigate to Products tab | Shows 16 medicines grouped by category |
| 2 | **Restaurant:** Navigate to Products tab | Shows 16 menu items; header says "Menu Items" |
| 3 | **Retail:** Navigate to Products tab | Shows 16 grocery products |
| 4 | Use search bar | Filters products by name/barcode |

### 3.2 Add Product (Pharmacy-specific)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Tap ➕ "Add Medicine" | Bottom sheet opens with pharmacy fields |
| 2 | Fill: Name = "Test Medicine", Category = "Antibiotics", Price = 100, Stock = 50 | Basic fields work |
| 3 | Set **Batch Number** = "B-TEST-001" | Batch field visible (pharmacy feature) |
| 4 | Tap **Set Expiry Date** → pick a date | Date picker opens; button updates to show "Expires: dd/mm/yyyy" |
| 5 | Set **Barcode** = "1234567890123" | Barcode field visible (pharmacy feature) |
| 6 | Set **Wholesale Price** = 70 | Wholesale field visible (pharmacy feature) |
| 7 | Tap Save | Product appears in the list |

### 3.3 Add Menu Item (Restaurant-specific)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Tap ➕ "Add Menu Item" | Bottom sheet with restaurant fields |
| 2 | Fill: Name = "Test Pasta", Category = "Specials", Price = 500 | Fields work |
| 3 | Add **Modifier**: "Extra Cheese" @ Rs. 100 | Modifier section visible |
| 4 | Add **Variant**: "Large" @ Rs. 700 | Variant section visible |
| 5 | Save | Item appears in list |

### 3.4 Add Product (Retail-specific)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Tap ➕ "Add Product" | Bottom sheet with retail fields |
| 2 | Fill fields, set **Unit Type** = "kg" | Unit type dropdown visible |
| 3 | Set **Barcode** and **Wholesale Price** | Both fields available |
| 4 | Save | Product appears |

### 3.5 Edit & Delete Product
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Tap any product → edit icon | Edit sheet opens pre-filled |
| 2 | Change price → Save | Price updates in list |
| 3 | Tap delete icon on any product | Confirmation dialog → product removed |

---

## 4. Categories Management

| # | Step | Expected Result |
|---|------|----------------|
| 1 | On Products screen, tap category filter | Shows 8 seeded categories |
| 2 | Settings → (or via product screen categories) add a new category | New category appears |
| 3 | Delete a category | Category removed from filter |

---

## 5. Sales Flow

### 5.1 New Sale (Pharmacy / Retail)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Navigate to Sales tab → "New Sale" | Sales screen opens with product search |
| 2 | Search and select "Paracetamol 500mg" | Item added to cart with qty 1 |
| 3 | Increase quantity to 3 | Cart total updates (15 × 3 = Rs. 45) |
| 4 | Add another product | Multiple items in cart |
| 5 | Apply a **discount** (e.g., Rs. 10) | Total decreases by 10 |
| 6 | Select **Payment: Cash** → Confirm | Sale saved, invoice number generated |
| 7 | Verify stock decreased | Product stock reduced by qty sold |

### 5.2 New Order (Restaurant)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Login as Restaurant → Sales → "New Order" | Order screen opens |
| 2 | Select "Chicken Fried Rice" | Item added to cart |
| 3 | Select **variant** "Large" (Rs. 850) | Price changes to large variant |
| 4 | Add **modifier** "Extra Egg" (+Rs. 80) | Modifier added, total updates |
| 5 | Set **Table Number** = "T3" | Table number field visible |
| 6 | Set **Order Type** = "Dine-in" | Order type selector visible |
| 7 | Confirm order | Sale saved with restaurant fields |

### 5.3 Credit Sale
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Start a new sale → select items | Cart has items |
| 2 | Select **Payment: Credit** | Customer picker appears |
| 3 | Select "Ruwan Bandara" | Customer linked |
| 4 | Confirm sale | Customer balance increases by sale amount |
| 5 | Navigate to Customers → verify Ruwan's balance | Balance updated |

### 5.4 Recent Sales
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Dashboard → Recent Sales section | Shows latest 5 sales with totals |
| 2 | Tap a sale | Sale details shown |

---

## 6. Customer Management

| # | Step | Expected Result |
|---|------|----------------|
| 1 | Navigate to Customers tab | Shows 8 seeded customers per shop |
| 2 | Search "Ruwan" | Filters to Ruwan Bandara |
| 3 | Verify first 3 customers have credit balances | Non-zero balances displayed (Rs. 500, 850, 1200) |
| 4 | Tap ➕ to add new customer | Form: name, phone |
| 5 | Fill and save | New customer appears in list |
| 6 | Check Dashboard "Credit Customers" card | Shows count matching Firestore |

---

## 7. Reports

### 7.1 View Reports
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Navigate to Reports tab | Shows summary cards + charts |
| 2 | Toggle **Daily / Monthly** | Data and charts switch between periods |
| 3 | Verify Revenue card | Matches sum of sales in selected period |
| 4 | Verify Orders count | Matches number of sale docs |
| 5 | Check **Payment Breakdown** chart | Pie chart showing Cash vs Credit distribution |
| 6 | Check **Daily Sales Trend** chart | Bar chart with daily totals |
| 7 | Check **Top Items** list | Shows best-selling products |

### 7.2 Business-Specific Report Modules
| # | Step | Expected Result |
|---|------|----------------|
| 1 | **Pharmacy:** Check "Expiring Soon" section | Lists products with expiryDate ≤ 30 days |
| 2 | **Restaurant:** Check "Order Types" breakdown | Dine-in / Takeaway / Delivery counts |
| 3 | **Repair Shop:** Check "Job Status" section | Pending / In-progress / Done counts |

### 7.3 PDF Export
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Tap ↓ (download) icon in Reports header | Month picker bottom sheet appears |
| 2 | Select a month (e.g., current month) | Month highlighted |
| 3 | Tap **Download PDF** | PDF generated with summary, payment breakdown, daily breakdown, top items, transactions |
| 4 | File opens automatically | PDF viewer shows branded report |

### 7.4 Excel Export
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Tap ↓ icon → select month → **Download Excel** | .xlsx file generated |
| 2 | Open the file | 5 sheets: Summary, Daily Breakdown, Top Items, Transactions, Line Items |

---

## 8. Notifications

### 8.1 Notification Bell
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Login as Pharmacy → check bell icon (top-right of dashboard) | Badge shows unread count (4-5 unread seeded) |
| 2 | Tap bell icon | Bottom sheet opens with notification list |
| 3 | Tap a notification | Marked as read, badge count decreases |
| 4 | Tap "Mark all read" | All badges cleared |

### 8.2 Notification Types (Pharmacy)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Check notification list | Should see: Daily Summary, Low Stock, Expiring Medicine, Expired Stock, New Product Reminder |

### 8.3 Notification Types (Restaurant)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Login as Restaurant → check notifications | Should see: Daily Summary, Daily Menu Reminder |

### 8.4 Notification Types (Retail)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Login as Retail → check notifications | Should see: Daily Summary, Low Stock, Restock Reminder |

### 8.5 Notification Settings
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Notifications | Toggle switches for each notification type |
| 2 | Disable "Low Stock Alerts" → Save | Preference saved |
| 3 | Return to dashboard (triggers notification check) | No new low-stock notification generated today |
| 4 | Re-enable and save | Preference restored |

### 8.6 Seed Dummy Notifications (Dev)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | **Long-press** the bell icon on dashboard | 7 dummy notifications added instantly |
| 2 | Tap bell to verify | New test notifications visible |

---

## 9. Settings

### 9.1 Profile Settings
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Profile Settings | Dialog shows name, email, role, shop name |
| 2 | Edit shop name → Save | Shop name updates everywhere |

### 9.2 Receipt Settings
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Receipt Settings | Dialog shows shop name, phone, address, footer |
| 2 | Edit footer text → Save | Receipt footer updated |

### 9.3 Printer Settings
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Printer Settings | Bluetooth printer list (or empty if none paired) |
| 2 | If printer available, connect and test print | Receipt prints to thermal printer |

### 9.4 Privacy Policy
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Privacy Policy | Dialog with privacy text displayed |

### 9.5 Help & Support
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Help & Support | Support info and contact displayed |

### 9.6 Add Cashier (Admin only)
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Management → Add Cashier | Form: name, email, password, PIN |
| 2 | Fill in cashier details → Submit | Cashier created, can login with their email/PIN |
| 3 | Login as cashier | Reduced permissions (no Management section visible) |

### 9.7 Cloud Sync
| # | Step | Expected Result |
|---|------|----------------|
| 1 | Settings → Cloud Backup & Sync | Shows "Cloud Sync is Active (Auto)" |

---

## 10. Cross-Business Validation

Run through all 3 accounts and verify the UI adapts:

| Feature | Pharmacy | Restaurant | Retail |
|---------|----------|-----------|--------|
| Product label | "Medicine" | "Menu Item" | "Product" |
| Add button | "Add Medicine" | "Add Menu Item" | "Add Product" |
| Sales title | "New Sale" | "New Order" | "New Sale" |
| Barcode field | ✅ | ❌ | ✅ |
| Stock management | ✅ | ❌ | ✅ |
| Modifiers/Variants | ❌ | ✅ | ❌ |
| Table/Order type | ❌ | ✅ | ❌ |
| Expiry/Batch | ✅ | ❌ | ❌ |
| Wholesale price | ✅ | ❌ | ✅ |
| Unit type (kg/liter) | ❌ | ❌ | ✅ |
| Job status | ❌ | ❌ | ❌ |
| Low stock alerts | ✅ | ❌ | ✅ |
| Expiry alerts | ✅ | ❌ | ❌ |
| Menu reminders | ❌ | ✅ | ❌ |

---

## 11. Edge Cases & Error Handling

| # | Test | Expected |
|---|------|----------|
| 1 | Login with wrong email | Firebase error displayed |
| 2 | Login with wrong password | Firebase error displayed |
| 3 | Add product with empty name | Validation error |
| 4 | Add product with negative price | Validation error |
| 5 | Try to sell more than available stock | Stock goes negative or error shown |
| 6 | Search for non-existent product | Empty state shown |
| 7 | Export PDF for month with no sales | PDF still generated (empty tables) |
| 8 | Rapid-tap Save on product | No duplicate creation |

---

## Quick Smoke Test (5 minutes)

For a rapid sanity check on a single business type:

1. ✅ Login with email → Dashboard loads with data
2. ✅ Products tab shows seeded items
3. ✅ Create a new sale with 2 items → completes successfully
4. ✅ Check customer balance updates on credit sale
5. ✅ Reports show the new sale in today view
6. ✅ Notification bell shows unread count
7. ✅ Settings dialogs open without errors
8. ✅ Logout and re-login with PIN works
