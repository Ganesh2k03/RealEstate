trigger PropertyTenantTrigger on Property_Tenant__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        PropertyTenantTriggerHandler.handleAfterInsert(Trigger.new);
    }
}