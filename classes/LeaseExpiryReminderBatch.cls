/**
 * Batchable job that scans lease agreements and emails the linked tenant
 * when the agreement is exactly 30 days or 1 day from expiry. Designed to
 * be run once per day from LeaseExpiryReminderSchedulable.
 *
 * Bulk-safe: emails are accumulated in-memory and dispatched in a single
 * Messaging.sendEmail call per chunk.
 */
public with sharing class LeaseExpiryReminderBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
    private Integer emailsSent = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        Date d30 = today.addDays(30);
        Date d1 = today.addDays(1);
        return Database.getQueryLocator([
            SELECT Id, Name, End_Date__c, Status__c, Monthly_Rent__c,
                   Tenant__c, Tenant__r.Name, Tenant__r.Email__c,
                   Property__c, Property__r.Name
            FROM Lease_Agreement__c
            WHERE Status__c = 'Active'
              AND End_Date__c IN (:d30, :d1)
              AND Tenant__c != NULL
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Lease_Agreement__c> scope) {
        Date today = Date.today();
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        for (Lease_Agreement__c lease : scope) {
            if (lease.Tenant__r == null || String.isBlank(lease.Tenant__r.Email__c)) continue;
            Integer daysToExpiry = today.daysBetween(lease.End_Date__c);
            String subject;
            String body;
            if (daysToExpiry == 30) {
                subject = 'Your lease ' + lease.Name + ' expires in 30 days';
                body = 'Hello ' + lease.Tenant__r.Name + ',\n\n'
                    + 'This is a friendly reminder that your lease agreement ' + lease.Name
                    + ' for property ' + (lease.Property__r == null ? '' : lease.Property__r.Name)
                    + ' will expire on ' + lease.End_Date__c + ' (30 days from today).\n\n'
                    + 'Please contact us to discuss renewal or move-out arrangements.\n\n'
                    + 'Best regards,\nProperty Management';
            } else if (daysToExpiry == 1) {
                subject = 'Your lease ' + lease.Name + ' expires tomorrow';
                body = 'Hello ' + lease.Tenant__r.Name + ',\n\n'
                    + 'This is a final reminder that your lease agreement ' + lease.Name
                    + ' for property ' + (lease.Property__r == null ? '' : lease.Property__r.Name)
                    + ' will expire tomorrow (' + lease.End_Date__c + ').\n\n'
                    + 'Please ensure all formalities are completed.\n\n'
                    + 'Best regards,\nProperty Management';
            } else {
                continue;
            }
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ lease.Tenant__r.Email__c });
            email.setSubject(subject);
            email.setPlainTextBody(body);
            email.setSaveAsActivity(false);
            messages.add(email);
        }
        if (!messages.isEmpty()) {
            Messaging.sendEmail(messages, false);
            emailsSent += messages.size();
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'LeaseExpiryReminderBatch finished. Emails sent: ' + emailsSent);
    }
}