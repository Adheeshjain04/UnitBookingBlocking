# Salesforce Unit Booking Process

## 1. **OpportunityBookingTrigger**
**Purpose:** Controls the initial unit booking process and ensures booking integrity.

### Key Functions:
- Blocks unit for 30 minutes when an opportunity stage changes to 'Booked'
- Validates unit availability before allowing booking
- Sets the blocking expiry time to 30 minutes from booking time
- Initiates the timeout scheduling process
---

## 2. **OpportunityPaymentTrigger**
**Purpose:** Handles payment status changes and updates related records.

### Key Functions:
- Monitors when `Payment_Done__c` becomes true
- Updates unit status to 'Sold' when payment is received within the 30-minute window
- Changes opportunity stage to 'Closed Won' upon successful payment
- Closes other opportunities as 'Closed Lost'
- Maintains consistency between unit and opportunity records
---

## 3. **UnitTimeoutSchedulable**
**Purpose:** Manages the automated timeout process for unpaid bookings.

### Key Functions:
- Executes exactly 30 minutes after initial booking
- Checks if payment was completed:
  - **If payment completed:** Updates unit to 'Sold' and opportunity to 'Closed Won' and other Opportunities to 'Closed Lost'.
  - **If no payment:** Updates unit to 'Available' if there is no opportunity with Future Scheduled Job else Maintains the Blocked Status and update the respective opportunity to 'Closed Lost'
- Cleans up booking data by clearing blocked status and expiry time
---

## 4. **BookingTimeoutManager**
**Purpose:** Manages scheduling of timeout jobs.

### Key Functions:
- Creates and schedules timeout jobs for new bookings
- Processes units in batches of 50 to reduce scheduled jobs
- Generates unique job names for tracking
- Ensures proper scheduling of timeout checks
- Manages job execution timing
---
