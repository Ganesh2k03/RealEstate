trigger PropertyTrigger on Property__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        PropertyTriggerHandler.handleAfterInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        PropertyTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}