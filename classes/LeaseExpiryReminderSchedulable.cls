/**
 * Daily scheduler that fires LeaseExpiryReminderBatch.
 *
 * Schedule via Setup (Apex Jobs > Schedule Apex) or by running
 *   System.schedule('Lease Expiry Reminder', '0 0 8 * * ? *', new LeaseExpiryReminderSchedulable());
 */
public with sharing class LeaseExpiryReminderSchedulable implements Schedulable {
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new LeaseExpiryReminderBatch(), 50);
    }
}